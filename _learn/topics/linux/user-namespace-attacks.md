---
title: User-namespace attacks
slug: user-namespace-attacks
---

> **TL;DR:** Unprivileged user namespaces let any local user obtain a full capability set *inside* the new namespace; that capability set unlocks code paths (mount, BPF, netfilter, nf_tables, fsconfig) that historically harbour kernel bugs reachable from non-root.

## What it is
A *user namespace* maps a UID inside the namespace to a different UID outside. The kernel lets even an unprivileged user create a userns with `CLONE_NEWUSER`, where they appear as root and gain a full capability bitmap *limited to that namespace*. The original promise was safe rootless containers; the practical reality is that this exposes a huge amount of previously root-only kernel syscall surface to local users, which has produced a steady stream of LPE CVEs.

## Preconditions / where it applies
- Linux kernel with `CONFIG_USER_NS=y` (default on most distros)
- `sysctl kernel.unprivileged_userns_clone=1` (Ubuntu/Debian default is 1; RHEL family disables by default)
- `sysctl user.max_user_namespaces > 0`
- Local code execution as any user

## Technique

**Smoke test the primitive:**
```bash
unshare -Urmp --fork --mount-proc bash
id
# uid=0(root) gid=0(root) groups=0(root)
capsh --print
# Current: =eip cap_chown,cap_dac_override,...   ← full set, inside ns only
```

That root is sandboxed — you can't do anything that requires `CAP_*` *outside* the namespace. The danger is what's reachable *inside*:

**Attack class 1 — kernel bugs reachable with the new caps.**

| CVE | Subsystem | Notes |
|---|---|---|
| CVE-2022-0185 | fsconfig() heap overflow | Reachable from userns, used in container escapes |
| CVE-2022-25636 | nf_tables OOB write | Reachable via newly available netfilter caps |
| CVE-2023-3390 | nf_tables UAF | Same vector |
| CVE-2023-32233 | nf_tables anonymous sets UAF | Same |
| CVE-2024-1086 | nf_tables double-free | LPE via userns + nftables |

Pattern: open userns, then trigger a vulnerable code path that previously required root.

```c
unshare(CLONE_NEWUSER | CLONE_NEWNET);
// now we can manipulate nf_tables, configure interfaces, etc.
```

**Attack class 2 — confused deputy via setuid binaries inside the ns.** Inside a fresh user+mount namespace, an attacker can bind-mount their own files over system paths that setuid binaries trust. Historical bug class around `/etc/nsswitch.conf`, `/etc/sudo.conf`, `/lib/x86_64-linux-gnu/libnss_*`. Modern kernels set `MS_NOSUID` on bind mounts inside userns to defeat the canonical version, but variants keep appearing.

**Attack class 3 — overlayfs bugs.** CVE-2021-3493 (Ubuntu) — overlayfs in user namespaces let unprivileged users create setuid binaries with arbitrary contents. Trivial root.

**Attack class 4 — sandbox escapes.** Chrome, Firefox, snap, flatpak, and many CI runners use userns for sandboxing. Each layer that calls `setns()` or relies on namespace transitions is a target.

**Hands-on enumeration:**
```bash
sysctl kernel.unprivileged_userns_clone user.max_user_namespaces
cat /proc/self/uid_map; cat /proc/self/gid_map
ls -la /proc/self/ns/user
```

If `unprivileged_userns_clone=0`, the easiest CVE family is dead; fall back to [[kernel-exploits-linux]] candidates that don't need userns.

## Detection and defence
- Disable for users that don't need them:
  - Debian/Ubuntu: `sysctl -w kernel.unprivileged_userns_clone=0`
  - Generic: `sysctl -w user.max_user_namespaces=0`
- AppArmor `unprivileged_userns` block in Ubuntu 23.10+
- SELinux `user_namespace_create` boolean off
- Auditd: alert on `clone(... CLONE_NEWUSER ...)` from non-runtime parents
- Patch kernel quickly — userns bugs are the dominant LPE class since 2022

## References
- [user_namespaces(7)](https://man7.org/linux/man-pages/man7/user_namespaces.7.html) — capability and mapping rules
- [Project Zero — user namespace bugs](https://googleprojectzero.blogspot.com/) — series of writeups
- [HackTricks — User namespace](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/docker-security/namespaces/user-namespace.html) — exploitation context

Related: [[namespaces-and-cgroups]], [[container-escape-techniques]], [[kernel-exploits-linux]], [[linux-capabilities]].
