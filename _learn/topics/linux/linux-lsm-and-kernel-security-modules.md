---
title: Linux LSM and kernel security modules
slug: linux-lsm-and-kernel-security-modules
aliases: [linux-lsm, selinux-apparmor-deep, kernel-security-modules]
---

> **TL;DR:** Linux Security Modules (LSM) is the kernel framework that lets policies hook into syscall and object-access decisions to enforce Mandatory Access Control on top of the DAC model. SELinux, AppArmor, Smack, TOMOYO, Yama, Lockdown, and the newer BPF LSM are the major implementations. Operators usually meet LSM the first time something breaks ("permission denied" with `root`), and attackers meet it when a container escape lands in a context that still blocks `mount` or `ptrace`. Read alongside [[capabilities-privesc]], [[namespaces-and-cgroups]], [[container-runtime-escapes-modern]], and [[kernel-exploits-linux]].

## Why it matters

Traditional Unix permissions (DAC) answer "does this UID own this inode?". That model collapses the moment a process runs as `root` or is granted a broad capability. LSM is the kernel's second opinion: even if DAC says yes, a loaded security module can still say no based on labels, paths, or policy state.

Three reasons it matters for both attack and defense:

- **Containment of root.** A compromised web server or a container that escaped its namespace is often still confined by SELinux `httpd_t` or by an AppArmor `docker-default` profile. Many CVEs are "code execution as root" that fail to convert into "host root" because LSM blocked the next step.
- **Detection surface.** SELinux AVC denials and AppArmor `DENIED` events are extremely high-signal log entries. They show up in `auditd` and feed [[siem-detection-use-case-catalog]] use cases for "policy violations on hardened workloads".
- **Compliance leverage.** PCI, FedRAMP, and most government baselines treat enforcing SELinux/AppArmor as a control. See [[pci-dss-4-implementation]] and the hardening notes referenced by [[secure-sdlc-rollout-playbook]].

## Architecture: the LSM framework

### Hooks, not policies

LSM itself is not a policy. It is a set of ~200 hook points scattered through the kernel — `security_inode_permission`, `security_bprm_check`, `security_socket_connect`, `security_file_open`, etc. Each hook is called after the standard DAC check passes and before the kernel performs the action. A registered module returns 0 (allow) or `-EACCES` / `-EPERM` (deny).

This is why LSM does not weaken existing security. If DAC says no, the hook is never reached. LSM only further restricts.

### Stacking

For years LSM only allowed one "major" module at a time (SELinux *or* AppArmor). Modern kernels (5.x+) support stacking: minor modules like Yama, Lockdown, and BPF LSM run alongside a major module. Boot parameter `lsm=` (or legacy `security=`) controls load order.

```bash
cat /sys/kernel/security/lsm
# Example: capability,yama,apparmor,bpf
```

### Where it sits in a syscall

A simplified `open("/etc/shadow", O_RDONLY)` from a confined process:

1. VFS resolves the path.
2. DAC check (`inode_permission`) — owner/group/mode.
3. LSM hook `security_inode_permission` — SELinux compares subject context (`httpd_t`) and object context (`shadow_t`) against policy.
4. LSM hook `security_file_open`.
5. If all return 0, the file descriptor is returned.

The same syscall may pass through 5–10 hooks. This is also why LSM-bypass kernel bugs are valuable: skipping the hook (e.g., via a kernel info leak that lets you patch the hook list, or a vulnerable path that does direct VFS access) gives you root regardless of policy.

## Classes / patterns / process

### Label-based: SELinux and Smack

SELinux assigns a **security context** of the form `user:role:type:level` to every process, file, socket, and IPC object. The kernel decides access by checking *type enforcement* (TE) rules between the subject type and the object type, plus optional MLS levels.

- Strengths: extremely expressive, can model multi-tenant separation, ships with type-enforced reference policies for hundreds of services on RHEL/Fedora.
- Weaknesses: policy authoring is hard; most operators only ever toggle booleans and run `audit2allow` on denials.

Common operator commands:

```bash
getenforce              # Enforcing | Permissive | Disabled
sestatus
ls -Z /etc/shadow       # see object label
ps -eZ | grep nginx     # see subject label
ausearch -m AVC -ts recent
audit2allow -a -M mymodule
semodule -i mymodule.pp
```

Smack (used heavily in Tizen and some embedded) is a simplified label model with the same hook integration.

### Path-based: AppArmor and TOMOYO

AppArmor matches policy against the **pathname** of the file at access time. Profiles live in `/etc/apparmor.d/` and look like:

```
profile docker-default flags=(attach_disconnected,mediate_deleted) {
  network,
  capability,
  file,
  deny @{PROC}/* w,
  deny @{PROC}/sys/[^k]** wklx,
  deny mount,
  ...
}
```

- Strengths: human-readable, easy to author, ships as the default on Ubuntu/Debian and underpins `docker-default`, `snap`, and `lxd` confinement.
- Weaknesses: path-based mediation can be evaded with bind mounts, hardlinks, or `/proc/self/root` tricks if the profile is not carefully written. Smaller policy surface than SELinux.

TOMOYO is conceptually similar but with a learning-mode workflow that records syscalls and proposes a path-based policy.

### Minor / specialised modules

- **Yama** — restricts `ptrace`. `/proc/sys/kernel/yama/ptrace_scope` of 1, 2, or 3 blocks attaching to arbitrary processes. This is what breaks `gdb -p` on hardened hosts and what hampers credential-dumping post-exploitation.
- **Lockdown** — restricts even `root` from operations that would compromise kernel integrity: loading unsigned modules, writing `/dev/mem`, kexec of unsigned kernels, certain BPF features. Modes are `none`, `integrity`, `confidentiality`. Tied to UEFI Secure Boot on most distros.
- **BPF LSM** — load eBPF programs as LSM hooks. Enables fast iteration: ship a small policy update without recompiling a reference policy. Used by Cilium Tetragon, KubeArmor, and many [[edr-rules-as-code-from-attack-patterns]] pipelines. Pairs naturally with [[detection-engineering-pyramid-of-pain]] because it lets you express behavioural rules in code.
- **IMA / EVM** — measurement and signing of file content; often considered LSM-adjacent. Useful for boot integrity and tamper detection.

### Common bypass classes

Attackers think about LSM bypass in roughly these buckets:

1. **Mislabeled object.** A file written by an unconfined administrator into a directory owned by a confined service ends up with the wrong label or no profile match. SELinux `restorecon` exists because this happens constantly. Attacker reads or writes a sensitive file the policy was supposed to protect.
2. **Profile gap on path-based policy.** AppArmor profile lists allowed paths; attacker symlinks, bind-mounts, or uses `/proc/<pid>/root/` to access the same inode through a non-matching path.
3. **Confined context that still has dangerous capability.** Container escapes (see [[container-runtime-escapes-modern]]) where the breakout lands in a host context that LSM still partially confines but allows `CAP_SYS_ADMIN` or `mount` — often enough to pivot.
4. **Kernel bug bypassing the hook.** Use-after-free or info-leak that lets the attacker patch the `security_hook_heads` list or call into a function below the hook layer. See [[kernel-exploits-linux]] and [[linux-kernel-pwn-walkthrough]].
5. **Disabling via boot.** If GRUB is unprotected and the host reboots, `selinux=0 apparmor=0 lockdown=none` on the kernel cmdline turns it off. Physical / IPMI access becomes LSM-relevant.
6. **`unconfined_t` / `unconfined` profile.** Many SELinux policies leave admin shells unconfined. Land there and policy enforcement is effectively skipped for that subject.

### Container runtimes and LSM

`runc` / `containerd` / `crun` apply both SELinux and AppArmor contexts when launching containers:

- Docker on Ubuntu loads `docker-default` AppArmor profile by default; override with `--security-opt apparmor=unconfined` (often abused in misconfigured environments).
- Podman on RHEL applies `container_t` SELinux context; objects inside get `container_file_t`. Mounting host paths without `:z` or `:Z` keeps host labels, which is why `-v /:/host` often "just works" for an attacker but a properly labeled mount blocks the read.
- Kubernetes Pod Security: `securityContext.seLinuxOptions` and `seccompProfile` + `appArmorProfile` annotations choose the profile per pod. Tie back to [[cloud-ir-k8s-audit-logs]] for auditing what was actually applied.

## Defensive baseline

A pragmatic LSM posture for a security team:

- **Enforcing, not permissive.** `getenforce` should print `Enforcing` (SELinux) or `aa-status` should show profiles in enforce mode. Permissive logs denials but allows the action — useful for tuning, dangerous as a permanent state.
- **Audit AVC denials into the SIEM.** Forward `/var/log/audit/audit.log` (SELinux) and `kern.log` / `audit.log` (AppArmor) into the central pipeline. Build use cases per [[siem-detection-use-case-catalog]]: alert on denials from production workloads that should never trip the policy.
- **Don't paper over with `setenforce 0`.** This is the SRE / sysadmin antipattern that turns a hardened host into a soft target. Track every `setenforce 0` and every `aa-disable` as a security event.
- **Protect the bootloader.** GRUB password + Secure Boot + Lockdown mode `integrity` or `confidentiality`. Without this the kernel cmdline can disable LSM.
- **Treat `unconfined_t` as privileged.** Only emergency admin shells should land there, and they should be monitored like `sudo`.
- **Container profiles.** Ship a non-`unconfined` AppArmor / SELinux profile for every workload; ban `--privileged` and `--security-opt apparmor=unconfined` in admission policy. Cross-reference [[appsec-maturity-checklist]].
- **Use BPF LSM for what reference policies can't express.** Behavioural rules like "no process in container `foo` may exec `/usr/bin/curl`" map cleanly to BPF LSM and are version-controlled like code.

## Workflow to study

1. Spin a Fedora and an Ubuntu VM in the lab from [[building-a-research-home-lab]].
2. On Fedora: read `sestatus`, list types with `seinfo -t`, dump policy with `sesearch --allow -s httpd_t`. Trigger a denial (`curl file:///etc/shadow` as `httpd_t`) and walk through `ausearch -m AVC` and `audit2allow -a`.
3. On Ubuntu: `aa-status`, read `/etc/apparmor.d/usr.bin.firefox`, write a tiny custom profile with `aa-genprof`, switch between `aa-complain` and `aa-enforce`.
4. Install `bpftool` and Tetragon or a small custom BPF LSM program; hook `bprm_check_security` and log every exec.
5. Read the kernel source: `security/security.c`, `include/linux/lsm_hooks.h`, and one module (`security/apparmor/lsm.c` is the most readable). Pair with [[kernel-syscall-source-review]].
6. Read a real bypass writeup (CVE-2022-2588, CVE-2023-32233) and trace which hook would have caught it and why it didn't. Feed back into [[kernel-exploits-linux]].
7. Exercise: take a Kubernetes pod, write a SecurityContextConstraint / PodSecurity policy that pins SELinux type and AppArmor profile, then try to break out. Pair with [[container-runtime-escapes-modern]].

## Related

- [[capabilities-privesc]]
- [[namespaces-and-cgroups]]
- [[kernel-exploits-linux]]
- [[container-runtime-escapes-modern]]
- [[linux-kernel-architecture]]
- [[kernel-syscall-source-review]]
- [[ld-preload-abuse]]
- [[edr-rules-as-code-from-attack-patterns]]
- [[siem-detection-use-case-catalog]]
- [[cloud-ir-k8s-audit-logs]]
- [[appsec-maturity-checklist]]

## References

- Linux kernel docs, LSM framework: https://www.kernel.org/doc/html/latest/security/lsm.html
- SELinux Project wiki and policy guide: https://github.com/SELinuxProject/selinux-notebook
- AppArmor upstream documentation: https://gitlab.com/apparmor/apparmor/-/wikis/Documentation
- BPF LSM design and usage: https://docs.kernel.org/bpf/prog_lsm.html
- Kernel Lockdown mode overview: https://man7.org/linux/man-pages/man7/kernel_lockdown.7.html
- NSA / Red Hat SELinux deployment guidance: https://www.redhat.com/en/topics/linux/what-is-selinux
