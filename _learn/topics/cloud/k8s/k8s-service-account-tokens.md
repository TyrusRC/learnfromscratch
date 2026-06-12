---
title: Kubernetes service account tokens
slug: k8s-service-account-tokens
---

> **TL;DR:** Pods auto-mount a JWT for the namespace's default service account at `/var/run/secrets/kubernetes.io/serviceaccount/token`; that token's RBAC plus any over-broad role binding is the most common cluster-wide pivot from an RCE inside a pod.

## What it is
Every pod runs as a Kubernetes ServiceAccount (SA); by default it's the `default` SA in the pod's namespace. The kubelet mounts a JWT for that SA at a fixed path along with the API server CA cert. The token authenticates to `kubernetes.default.svc.cluster.local` (`KUBERNETES_SERVICE_HOST`). Bearer JWT + CA + DNS = you can `curl` the API server from inside any pod. Whatever RBAC the SA holds is now yours. Pre-1.24 clusters stored these as long-lived Secrets; 1.24+ uses BoundServiceAccountTokenVolume (projected, audience-bound, ~1h rotated tokens).

## Preconditions / where it applies
- Code execution inside a pod (RCE in app, exec into pod via [[k8s-rbac-abuse]], etc.).
- `automountServiceAccountToken` not explicitly set to `false` on the pod or SA.
- API server reachable from the pod (default).

## Technique
**Grab the token and probe:**

```sh
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
APISERVER=https://kubernetes.default.svc

# what can I do?
curl -sk --cacert $CACERT -H "Authorization: Bearer $TOKEN" \
  $APISERVER/apis/authorization.k8s.io/v1/selfsubjectrulesreviews \
  -X POST -H 'Content-Type: application/json' \
  -d '{"kind":"SelfSubjectRulesReview","apiVersion":"authorization.k8s.io/v1","spec":{"namespace":"default"}}'
```

Or with a `kubectl` binary dropped into the pod:

```sh
kubectl --token=$TOKEN --certificate-authority=$CACERT --server=$APISERVER \
  auth can-i --list
```

**Common high-value SA permissions:**
- `pods/exec` → exec into any pod, steal *its* SA token; iterate to higher-priv namespaces.
- `secrets get` cluster-wide → read every Secret (often includes other SA tokens, cloud creds, kubeconfigs).
- `pods create` + `nodes` → schedule a privileged pod (see [[k8s-privileged-pod]]) or a hostPath pod (see [[k8s-host-mount-escape]]).
- `clusterroles bind` / `roles bind` → grant yourself cluster-admin.
- `serviceaccounts/token` create → mint a token for any SA in any namespace (cluster-admin SA = game over).

**Long-lived token via Secret (legacy / explicit):**

```yaml
apiVersion: v1
kind: Secret
metadata: {name: x, namespace: ns, annotations: {kubernetes.io/service-account.name: target-sa}}
type: kubernetes.io/service-account-token
```

If you have `secrets create` you can request a non-expiring token for any SA in that namespace — survives pod restart, defeats projected-token rotation.

**Cross-namespace pivot:** SAs hold permissions cluster-wide via ClusterRoleBinding; check `RoleBinding`/`ClusterRoleBinding` referencing your SA in *other* namespaces too.

**Audience-bound tokens:** modern projected tokens carry `aud` claims. Re-request with a different audience via `serviceaccounts/token` if you can.

Chain into [[k8s-rbac-abuse]] for the privilege analysis lens.

## Detection and defence
- Set `automountServiceAccountToken: false` on the SA or pod when not needed.
- Use dedicated SAs per workload — never share `default` across multiple apps.
- Migrate to bound projected tokens (1.24+) with short TTL and audience binding.
- Audit `ClusterRoleBinding`/`RoleBinding` regularly; alert on bindings to `system:masters` or to wildcard verbs.
- Audit log: alert on `selfsubjectrulesreviews` (recon) and on API access from pod IPs to sensitive verbs.
- Don't store cloud creds in Secrets — use Workload Identity (IRSA on AWS, GKE Workload Identity, Azure Workload Identity) so SA tokens federate without exposing static creds.

## References
- [Kubernetes — ServiceAccount tokens](https://kubernetes.io/docs/concepts/security/service-accounts/) — token mechanics
- [Kubernetes — BoundServiceAccountTokenVolume](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/) — projected tokens
- [HackTricks — k8s SA abuse](https://book.hacktricks.wiki/en/pentesting-network/pentesting-kubernetes/abusing-roles-clusterroles-in-kubernetes/index.html) — RBAC abuse catalog

See also: [[eks-pod-identity-abuse]], [[k8s-rbac-abuse]], [[k8s-privileged-pod]], [[gcp-workload-identity-federation-abuse]], [[gke-workload-identity-abuse]], [[kubelet-exposed-api-attacks]], [[k8s-image-registry-poisoning]]
