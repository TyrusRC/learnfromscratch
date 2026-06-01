---
title: Namespaces and cgroups
slug: namespaces-and-cgroups
---

> **TL;DR:** Linux containers are just namespaces (isolation of kernel resource views) + cgroups (resource accounting) + capability/seccomp/LSM filters. Every namespace has a corresponding escape primitive when its assumptions break.

## What it is
A *namespace* gives a process a private view of a kernel resource (PIDs, mounts, network, IPC, UTS, user, cgroup, time). A *cgroup* enforces accounting and limits (CPU, memory, IO, pids). Together they form the container abstraction — but the kernel is still shared, so any namespace whose isolation has a hole becomes an escape vector.

## Preconditions / where it applies
- Code execution inside a namespaced environment (Docker, Podman, LXC, Kubernetes pod, unshare-based sandbox)
- You need to know which namespaces you're in and which you share with the host to reason about escapes
- Useful introspection: `ls -la /proc/self/ns`, `readlink /proc/1/ns/*`

## Technique

**The seven (eight) namespaces and their escape primitives:**

| NS | Isolates | Escape primitive |
|---|---|---|
| `mnt` | Mount table, root filesystem view | Host bind mounts visible inside; `chroot` from mounted host disk |
| `pid` | PID numbering | Sharing host PID NS (`--pid=host`) lets you signal/ptrace host processes |
| `net` | Interfaces, sockets, iptables | `--net=host` exposes host services; raw socket + `CAP_NET_ADMIN` |
| `ipc` | SysV IPC, POSIX message queues | Shared IPC = shared shared-memory with host workloads |
| `uts` | hostname, domainname | Mostly cosmetic; not a privesc by itself |
| `user` | UID/GID mapping, caps | Unprivileged userns gives full caps *inside* — many CVEs (see [[user-namespace-attacks]]) |
| `cgroup` | cgroup root | Misset rw cgroup mount + `release_agent` (v1) = classic escape |
| `time` (5.6+) | CLOCK_MONOTONIC offset | Not a security boundary |

**Compare the host vs container view:**
```bash
# from inside
ls -la /proc/self/ns
# lrwxrwxrwx 1 root root 0 mnt -> 'mnt:[4026532567]'
# lrwxrwxrwx 1 root root 0 pid -> 'pid:[4026532569]'
# ...

# inode shared with host? then you're NOT isolated for that NS
nsenter -t 1 -m -p ls /host_only_marker
```

**Cgroup essentials:**
- v1 has one hierarchy per controller, the `release_agent` file = path the kernel runs when the last task leaves a notify-on-release cgroup → classic escape primitive
- v2 unified hierarchy, no `release_agent`, escape surface much smaller
- Check which you're on: `stat -fc %T /sys/fs/cgroup/` → `cgroup2fs` means v2

**Creating namespaces by hand:**
```bash
unshare -Urmp --fork --mount-proc bash   # user+mount+pid in one shot, no caps needed
nsenter -t <pid> -a                       # join all NS of another process
```

**Why this matters for offence:** every container escape reduces to "find a namespace that *isn't* actually isolating", or "find a kernel bug reachable through a syscall the container's seccomp profile lets through". Knowing which NSes a runtime shares (Docker shares the user NS by default — root in container is root on host kernel) is the first triage step inside any container.

## Detection and defence
- Default to userns-remap (`/etc/docker/daemon.json` `"userns-remap": "default"`) so in-container UID 0 maps to a non-root host UID
- Drop CAP_SYS_ADMIN; default seccomp + AppArmor/SELinux profile
- Use cgroup v2; cgroup v1 `release_agent` escape is well-known
- Kubernetes PodSecurity `restricted` profile: no `hostPID`, `hostNetwork`, `hostIPC`, no `privileged`
- Audit `unshare()`, `setns()`, `clone(CLONE_NEW*)` from non-runtime parents

## References
- [Linux Namespaces overview](https://man7.org/linux/man-pages/man7/namespaces.7.html) — authoritative man page
- [Aqua — Container escape research](https://blog.aquasec.com/) — runtime-CVE writeups
- [HackTricks — Namespaces](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/docker-security/namespaces/index.html) — per-NS escape recipes

Related: [[container-escape-techniques]], [[user-namespace-attacks]], [[linux-capabilities]].
