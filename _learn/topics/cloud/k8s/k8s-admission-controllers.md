---
title: Admission-controller abuse
slug: k8s-admission-controllers
---

> **TL;DR:** Admission webhooks gate every kube-API write — kill the webhook pod, deploy with the webhook offline, or exploit TOCTOU between admission and runtime, and policies that "block privileged pods" silently let one through.

## What it is
Kubernetes runs validating and mutating admission webhooks during every API request that creates or updates a resource. Policy engines like Gatekeeper, Kyverno, and OPA implement security controls there — "no privileged: true," "no hostPath," "image must come from trusted registry." Failures: (1) `failurePolicy: Ignore` skips the check when the webhook is unreachable, (2) the webhook itself runs as a pod whose deletion or eviction creates a window, (3) admission validates the spec at creation but later updates / sidecar injection / runtime exec aren't re-evaluated.

## Preconditions / where it applies
- RBAC sufficient to create pods or workloads in some namespace (`pods/create`, `deployments/create`).
- Reachable kube-apiserver.
- For webhook-kill: `pods/delete` or `pods/eviction` on the webhook's namespace, or a node where the webhook pod runs that you can drain.

## Technique
**Pattern 1 — `failurePolicy: Ignore` race:**
Many admins set `failurePolicy: Ignore` to keep the cluster usable during webhook outages. Check:

```bash
kubectl get validatingwebhookconfigurations -o json \
  | jq '.items[] | {name:.metadata.name, fp:.webhooks[].failurePolicy}'
```

Any webhook with `Ignore` can be bypassed by making the webhook endpoint unreachable. Delete its service, scale its deployment to 0, or drain its node:

```bash
kubectl -n kyverno scale deploy/kyverno-admission-controller --replicas=0
# now create the policy-violating pod
kubectl apply -f privileged-pod.yaml
kubectl -n kyverno scale deploy/kyverno-admission-controller --replicas=1   # restore
```

**Pattern 2 — Out-of-band field updates:**
Admission validates the *whole* spec on create. Some policies don't re-fire on `patch` of specific subresources. Example: create a benign pod, then `kubectl patch pod x --subresource=ephemeralcontainers` to inject a privileged debug container.

**Pattern 3 — Mutating-webhook ordering:**
Mutating webhooks run before validating. A mutating webhook that injects sidecars (Istio, Linkerd) may add a container that the validating policy doesn't re-scan. Force the mutator to inject a container with the spec you want.

**Pattern 4 — Webhook RBAC misconfig:**
The webhook's TLS cert is stored in a Secret; the webhook service account often has overly broad read access to it. Compromise the webhook pod itself → forge admission responses → silent permanent bypass.

**Pattern 5 — `namespaceSelector` skip:**
Policy excludes `kube-system` (common, to avoid breaking control-plane). Get pod-create in `kube-system` (often granted to operators) and you're outside policy entirely.

Quick recon:

```bash
kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations -o yaml \
  | grep -E 'failurePolicy|namespaceSelector|name:'
```

Chain with [[k8s-rbac-abuse]] for the create permissions and [[k8s-privileged-pod.md]] for what to deploy once the gate's open.

## Detection and defence
- Set `failurePolicy: Fail` for security-critical webhooks; accept the availability cost.
- Run admission webhooks as a high-availability Deployment with PodDisruptionBudget; restrict who can scale/delete them.
- Use Kyverno / Gatekeeper with `validationFailureAction: enforce` and audit logs.
- Audit `ValidatingWebhookConfiguration` and `MutatingWebhookConfiguration` changes via Kubernetes audit logs (`responseStatus.code: 200` + `verb: update`).
- Block `pods/ephemeralcontainers` and other late-update subresources via separate policies.
- Don't trust namespace selectors that exclude system namespaces — apply baseline security to all namespaces.

## References
- [Kubernetes — Admission webhooks](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/) — official model
- [Kyverno — Policy reports](https://kyverno.io/docs/policy-reports/) — enforcement modes
- [Aqua — Admission controller bypass research](https://www.aquasec.com/blog/) — TOCTOU and webhook-kill patterns

See also: [[policy-as-code-opa-kyverno-defender]], [[helm-chart-security-audit]], [[gitops-security-argo-flux]], [[k8s-image-registry-poisoning]], [[kubelet-exposed-api-attacks]]
