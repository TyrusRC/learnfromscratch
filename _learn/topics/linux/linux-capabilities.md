---
title: Linux capabilities
slug: linux-capabilities
---

> **TL;DR:** Capabilities are the kernel's split of root power into ~40 named bits; some bits — `SYS_ADMIN`, `DAC_READ_SEARCH`, `SYS_PTRACE`, `SYS_MODULE`, `BPF`, `CHECKPOINT_RESTORE` — are effectively root.

## What it is
Since kernel 2.2 Linux models privileged operations as 40+ discrete capability bits instead of "are you UID 0?". A process has four capability sets — *permitted, effective, inheritable, bounding*, plus *ambient* since 4.3 — and binaries can carry file capabilities in xattrs. Containers, systemd units, and setcap-tagged binaries all use this model to grant narrow slices of privilege.

## Preconditions / where it applies
- Any modern Linux host or container
- You need to understand the model whenever you audit a setuid replacement, a systemd unit, a container runtime config, or you've just popped a process and need to know what it can actually do

## Technique

**Read the current process's caps:**
```bash
cat /proc/self/status | grep ^Cap
# CapInh: 0000000000000000   ← inheritable
# CapPrm: 00000000a80425fb   ← permitted (the upper bound)
# CapEff: 00000000a80425fb   ← effective (what's active now)
# CapBnd: 000001ffffffffff   ← bounding (cap ceiling for execve)
# CapAmb: 0000000000000000   ← ambient (4.3+, inherited across non-setuid execs)

capsh --decode=00000000a80425fb
```

**Read a binary's file capabilities:**
```bash
getcap /usr/bin/ping
# /usr/bin/ping = cap_net_raw+ep
```

**The danger list** (roughly in order of "free root"):

| Cap | What it grants | Practical exploitation |
|---|---|---|
| `SYS_ADMIN` | mount, swap, namespace ops, BPF in some cfgs | Mount host disk; create userns; loads of escapes |
| `SYS_MODULE` | `init_module()` | Load a malicious .ko |
| `SYS_PTRACE` | attach to any process | Inject shellcode into a root process |
| `DAC_READ_SEARCH` | bypass file-read DAC | Read `/etc/shadow`, ssh keys, anything |
| `DAC_OVERRIDE` | bypass write DAC too | Overwrite `/etc/passwd`, sudoers |
| `CHOWN` / `FOWNER` | chown anything | Swap ownership of suid binaries |
| `SETUID` / `SETGID` | switch to any UID/GID | Direct root in an interpreter |
| `BPF` (5.8+) | load BPF programs | Bypass syscall filters; kernel R/W in some kernels |
| `CHECKPOINT_RESTORE` (5.9+) | `/proc/self/exe` rewrite, ptrace-like ops | Useful for escapes |
| `NET_ADMIN` | iptables, raw sockets | Pivot, sniff, ARP-spoof |
| `SYS_RAWIO` | `/dev/mem`, `iopl()` | Direct memory read/write |

**Setting caps deliberately:**
```bash
sudo setcap cap_net_bind_service=+ep /usr/local/bin/myapp
sudo setcap -r /usr/local/bin/myapp     # remove
```

Capability inheritance is the foot-gun: `cap_setuid+ei` on a binary won't fire unless the calling process *also* has the cap in its inheritable+ambient set. Most attacker recipes target `+ep` because it makes the cap effective unconditionally on exec.

## Detection and defence
- Build-time audit: `getcap -r / 2>/dev/null` and pin known-good cap sets
- Container runtime: drop ALL, add back only what's needed; default Docker profile already drops the most dangerous bits but leaves `SETUID/SETGID/CHOWN/NET_RAW`
- systemd hardening: `CapabilityBoundingSet=`, `AmbientCapabilities=`, `NoNewPrivileges=true`
- LSM (SELinux/AppArmor) cap rules; auditd on `cap_capable` denials

## References
- [capabilities(7) man page](https://man7.org/linux/man-pages/man7/capabilities.7.html) — authoritative reference
- [HackTricks — Linux Capabilities](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/linux-capabilities.html) — danger list with exploits
- [Container Security: capabilities](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) — Kubernetes/Linux interplay

Related: [[capabilities-privesc]], [[user-namespace-attacks]], [[container-escape-techniques]].
