---
title: Kubernetes admission webhook abuse
slug: k8s-admission-webhook-abuse
aliases: [admission-webhook-abuse, k8s-webhook-attacks]
---

{% raw %}

> **TL;DR:** Kubernetes admission webhooks intercept API requests *before* persistence — for validation, mutation, or policy. Attacks on them: (1) compromise the webhook service to inject privileged Pods, (2) bypass via fail-open `failurePolicy: Ignore`, (3) reach the webhook directly without going through the API server, (4) confused-deputy attacks where the webhook makes privileged API calls on behalf of unprivileged users, (5) cert-based MITM if certificates aren't pinned. Companion to [[k8s-manifest-source-audit]] and [[container-runtime-escapes-modern]].

## Background

Admission webhooks fire after authentication/authorization but before persistence:

```
Client → API server → AuthN/AuthZ → Mutating webhooks → Validating webhooks → etcd
```

Two kinds:
- **ValidatingAdmissionWebhook** — yes/no decision on the request.
- **MutatingAdmissionWebhook** — can modify the request (inject sidecars, set defaults).

Examples: Istio sidecar injector, Linkerd, Kyverno, OPA Gatekeeper, vendor admission controllers.

## Attack 1 — compromise the webhook backend

The webhook is a Pod in some namespace, exposed via a Service. If the attacker has a foothold there:
- Modify the webhook code to whitelist their own malicious Pods.
- Inject `securityContext.privileged: true` into every Pod via the mutating webhook.
- Sign off on banned configurations.

Reconnaissance:
```bash
kubectl get mutatingwebhookconfigurations
kubectl get validatingwebhookconfigurations
# for each, note the service name + namespace
kubectl describe mutatingwebhookconfiguration <name>
```

The output shows which namespaces / resources are intercepted and which service handles them. Compromise of the service = control over admission decisions cluster-wide.

## Attack 2 — fail-open misconfiguration

```yaml
webhooks:
  - name: validate.example.com
    failurePolicy: Ignore     # ← if the webhook is down, requests succeed
```

If `failurePolicy: Ignore`, attacker DoS's the webhook Pod → all subsequent privileged Pods admit unchecked.

DoS methods:
- Exhaust the webhook's TLS connection pool.
- Submit huge requests that timeout the webhook (default 10s).
- Network-policy-block the webhook from the API server.

Defence: `failurePolicy: Fail` for security-critical webhooks.

## Attack 3 — bypass via namespaceSelector

```yaml
namespaceSelector:
  matchLabels:
    enforce: "yes"
```

The webhook only intercepts Pods in namespaces labelled `enforce=yes`. Attacker who can create namespaces (or remove labels) creates an unlabelled namespace, schedules malicious Pod there.

Audit: `kubectl get ns --show-labels` — every namespace should match the policy selector.

## Attack 4 — confused deputy via webhook

A mutating webhook running as a service account may have permissions the user doesn't. The webhook accepts a Pod-creation request, modifies it (perhaps adding a sidecar), and the API server persists.

Bug: the webhook adds a sidecar that mounts `hostPath: /etc`. The user's Pod-create request didn't include that hostPath, but the persisted Pod does. The user gets a privileged Pod via the webhook's own privilege.

Audit:
- What does each webhook *do* to the request?
- Does it add fields the user couldn't add themselves?
- Are those additions reviewed?

## Attack 5 — reach the webhook directly

The webhook Pod is just a Service. If the network policy allows Pod-to-Pod traffic, an attacker with a foothold in any namespace can call the webhook directly, bypassing the API server's `kubernetes.io/serviceaccount` token verification.

```bash
# Discover the webhook Service
kubectl get svc -A | grep -E 'webhook|inject|admission'
# Curl it directly
curl -X POST -H 'Content-Type: application/json' \
  https://webhook.svc:443/validate -d '{"request":{...}}'
```

The webhook may not validate that the request came from the API server (cert-based mutual TLS would). If not, attacker spoofs admission requests and gets the webhook's mutations directly.

## Attack 6 — TLS misconfiguration

Webhooks use TLS, with the API server validating the webhook's cert against a CA bundle declared in the configuration.

Bugs:
- `caBundle` empty or insecureSkipTLSVerify enabled.
- API server's CA bundle includes a CA the attacker also has signing privileges for → cert spoofing.
- Webhook server uses a wildcard cert that another Pod also serves.

Audit:
```bash
kubectl get mutatingwebhookconfiguration <name> -o yaml | grep -A2 clientConfig
```

## Attack 7 — kube-apiserver to webhook traffic exfil

The API server sends the full `AdmissionReview` to the webhook — including the full Pod spec, env vars, and labels. If the webhook is compromised (or the network path), this is a continuous stream of sensitive data including injected secrets.

## Attack 8 — Kyverno / Gatekeeper policy bypass

These tools enforce custom policies via webhooks. Bypass:
- Resources not in the webhook's selectors (CRDs, Job, Subresources sometimes excluded).
- Policy logic that misses specific edge cases (e.g., `initContainers` not checked).
- OPA Rego rules with input.spec.template.spec.containers iteration that misses pod-level containers.

Source audit Rego / Kyverno:
```bash
grep -rn 'spec.containers\|spec.initContainers\|spec.ephemeralContainers' rego/
# look for ones that only check containers, not init/ephemeral
```

## Cluster-takeover chain

1. Foothold in any Pod (some misconfig).
2. Enumerate admission webhooks.
3. Identify webhook with broad scope + critical decisions.
4. Either compromise the webhook backend (RBAC + workload identity), or
5. Exploit a configuration weakness (failurePolicy, namespaceSelector).
6. Inject a Pod that mounts host root, adds itself to cluster-admin, or installs persistence.

## Defence

- `failurePolicy: Fail` for security-critical webhooks.
- `namespaceSelector` covers all namespaces (or excludes only kube-system explicitly).
- TLS with rotating short-lived certs; CA bundle pinned.
- Webhook backend in a dedicated namespace, NetworkPolicy restricting which Pods can call it.
- Webhook backend's serviceAccount has *only* the permissions it needs.
- RBAC denying users from modifying `MutatingWebhookConfiguration` / `ValidatingWebhookConfiguration`.

## Tools

- **kube-bench** — checks `failurePolicy`, TLS.
- **Polaris** — config validation.
- **kubeaudit** — admission webhook checks.
- **Trivy K8s scan**.

## References
- [Kubernetes — Admission Controllers documentation](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [Datadog — Admission webhook abuse research](https://www.datadoghq.com/blog/)
- [Aqua / Sysdig — admission attack writeups](https://blog.aquasec.com/)
- [Kyverno / OPA Gatekeeper docs](https://kyverno.io/) · [Gatekeeper](https://open-policy-agent.github.io/gatekeeper/)
- See also: [[k8s-manifest-source-audit]], [[container-runtime-escapes-modern]], [[opa-rego-policy-bypasses]], [[cloud-iam-misconfig-patterns]]

{% endraw %}
