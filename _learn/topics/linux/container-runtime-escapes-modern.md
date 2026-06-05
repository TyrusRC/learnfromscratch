---
title: Container runtime escapes — modern
slug: container-runtime-escapes-modern
aliases: [runc-escapes, containerd-escapes, modern-container-escape]
---

{% raw %}

> **TL;DR:** Container escapes in 2024-26 cluster around (1) runc CVEs (Leaky Vessels CVE-2024-21626 file-descriptor confusion; earlier CVE-2019-5736 binary overwrite), (2) symlink races at container init (CVE-2024-23651/2/3), (3) procfs file overwrites, (4) misconfigured Pod security (host namespaces, privileged), (5) kernel CVEs (Dirty Pipe), (6) eBPF bypasses. Companion to [[container-escape-techniques]] and [[k8s-manifest-source-audit]].

## What's new since the classic 2019 era

The classic landscape was "Docker socket mounted → done". Modern runtimes (runc, crun, gVisor, kata) closed the easy escapes. New bugs find narrower windows.

## CVE-2024-21626 — Leaky Vessels (runc fd confusion)

`runc` accidentally leaked file descriptors during container start. Through carefully chosen `WORKDIR` paths (`/proc/self/fd/N`), a container could land its working directory in the host's mount namespace, then access host filesystem via that fd.

Effect: container reads/writes host files including `/etc/shadow`. Patched in runc 1.1.12.

Exploit shape:
```dockerfile
FROM alpine
WORKDIR /proc/self/fd/7    # an fd to host root
```

Detection: image scanner that flags suspicious WORKDIR paths.

## CVE-2024-23651/2/3 — BuildKit symlink races

BuildKit's `mount` directives accepted symlinks created during build that pointed outside the build context. Combined with race conditions, a malicious Dockerfile could read or write to host paths during image build.

Affects multi-tenant CI/build environments more than runtime.

## CVE-2019-5736 — runc binary overwrite (classic but instructive)

A container process opens `/proc/self/exe`. Through procfs, the attacker controls the contents of the runc binary; next time the host runs runc (any container start), it runs attacker code as root on the host.

Patched in 2019 — but custom container runtimes still copy this pattern and reintroduce it.

## Procfs as the gift that keeps giving

`/proc/[pid]/` exposes many primitives. Misconfigured Pods with extra mounts:
- `/proc/sys/kernel/core_pattern` — set a core dump handler that runs on every crash. Crash any process → arbitrary code on host.
- `/proc/[pid]/cwd` — descend into another process's working directory if procfs is shared (`hostPID`).
- `/proc/sysrq-trigger` — kernel-trigger from container if mapped.

Audit:
```bash
grep -rn 'hostPID\|hostNetwork\|hostIPC' k8s-manifests/
```

## Mounted host paths

Common gateways:
- `/var/run/docker.sock` — direct access to dockerd → full host (containerd has the same shape via `/run/containerd/containerd.sock`).
- `/var/run/crio/crio.sock` — same for cri-o.
- `/var/lib/kubelet` — kubelet credentials / serviceaccount tokens.
- `/etc` — overwrite host configs.
- `/` — full host fs.

In K8s manifests these are `hostPath` volumes.

## Privileged + capability escapes

A `privileged: true` Pod can:
```bash
# Find host disk
fdisk -l
# Mount host root
mkdir /host && mount /dev/sda1 /host
# Operate on host
chroot /host bash
```

`SYS_ADMIN` capability alone is enough for many of these (mount, namespace operations).

`CAP_SYS_MODULE` lets the container load kernel modules — host code execution.

## eBPF in containers

`CAP_BPF` (split from CAP_SYS_ADMIN since 5.8) lets a container load eBPF programs. Combined with `CAP_PERFMON` and a debugfs/tracefs mount, eBPF can read kernel memory and inject probes — escape primitive.

See [[ebpf-offensive-and-defensive]].

## User-namespace escapes

A container in its own user namespace maps `root` inside to a non-root UID on the host. Most modern containers don't run this way (still root=root on the host). When user namespaces *are* used, attacks shift to:
- `CAP_SYS_ADMIN` *within* the namespace + a bug that lets you act on host objects.
- `setuid` binaries on the host that the container can reach via shared mounts.

See [[user-namespace-attacks]].

## Kernel-level escapes

Container = process + namespaces. Any kernel LPE works inside a container.

- **Dirty Pipe (CVE-2022-0847)** — works in containers; arbitrary file write including read-only-mounted files.
- **PwnKit (CVE-2021-4034)** — if `pkexec` is in the container.
- **OverlayFS issues** — modify the lower layer.

See [[dirty-pipe-cve-2022-0847]].

## Detection tools (defender side)

- **Falco** — runtime detection of anomalous container behaviour.
- **Tracee** — eBPF-based forensics.
- **Sysdig** — commercial agent.
- **gVisor / Kata** — alternative runtimes with smaller attack surface (gVisor: user-mode kernel; Kata: lightweight VM).

## Hardening (so you know what you're trying to bypass)

- Run rootless containers when possible.
- Drop all capabilities, add back minimal set.
- `readOnlyRootFilesystem: true`.
- `seccompProfile: RuntimeDefault`.
- No `hostPath` mounts.
- Pod Security Admission `restricted` namespace.
- Image signing + admission verification.

## Exploitation workflow

1. Enumerate container's capabilities, mounts, namespaces.
   ```bash
   capsh --print
   cat /proc/self/status | grep Cap
   mount | head
   cat /proc/self/ns/*
   ```
2. Identify the easiest gateway (privileged? host paths? Docker socket? known CVE?).
3. Exercise; confirm host access.
4. Move laterally — host kubelet credentials, other namespaces, cloud IMDS.

## Bug-bounty corpus

- HackerOne reports tagged `container escape` — useful for learning realistic chains.
- Cloud-provider bug bounties (AWS, GCP, Azure) — container escapes in managed services are critical.
- Public CTF: HackTheBox "Stocker", THM "Containers".

## References
- [Snyk — Leaky Vessels](https://snyk.io/blog/leaky-vessels-docker-runc-container-breakout-vulnerabilities/)
- [runc CVEs](https://github.com/opencontainers/runc/security/advisories)
- [Aqua Trivy — runtime scanning](https://aquasecurity.github.io/trivy/)
- [Falco rules](https://github.com/falcosecurity/rules)
- See also: [[container-escape-techniques]], [[k8s-manifest-source-audit]], [[user-namespace-attacks]], [[dirty-pipe-cve-2022-0847]], [[ebpf-offensive-and-defensive]]

{% endraw %}
