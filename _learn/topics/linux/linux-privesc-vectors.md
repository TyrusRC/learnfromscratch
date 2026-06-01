---
title: Linux privesc vectors
slug: linux-privesc-vectors
---

> **TL;DR:** A taxonomy of how unprivileged Linux users become root: misconfigured `sudo`, dangerous setuid binaries, writable cron targets, abused capabilities, kernel exploits, NFS-mount tricks, container/runtime escapes, credential reuse.

## What it is
A working taxonomy of local privilege escalation paths on Linux. Treat it as a tree to walk during enumeration — each leaf is a separate atomic technique with its own preconditions, exploitation steps, and detection profile.

## Preconditions / where it applies
- Initial code execution as a non-root user on a Linux host
- Some kind of reachable misconfiguration, vulnerable binary, or unpatched kernel
- Triage with [[linux-enumeration]] first; this map tells you which deeper note to read next

## Technique

The vectors, grouped by class:

**1. Sudo misconfiguration** — `sudo -l` is always the first command. NOPASSWD on a binary in the [[suid-sgid-binaries]] danger list, `env_keep` for `LD_PRELOAD`/`PYTHONPATH`, sudoers wildcards, or runas-user variants. See [[sudo-misconfig]] and [[ld-preload-abuse]].

**2. Setuid / setgid binaries** — custom suid binaries that exec shells, follow symlinks, trust env, or have format-string/buffer-overflow bugs; well-known ones already documented on GTFOBins. See [[suid-sgid-binaries]] and [[setuid-setgid-sticky]].

**3. Capabilities** — `getcap -r /` for unexpected `cap_setuid+ep`, `cap_dac_read_search+ep`, `cap_sys_admin+ep`, etc. See [[capabilities-privesc]] and [[linux-capabilities]].

**4. Cron / systemd timers** — writable cron scripts, world-writable cron directories, wildcard injection, PATH attacks. See [[cron-jobs]] and [[path-hijacking]].

**5. Writable system files** — `/etc/passwd` and `/etc/shadow` with bad ACLs, writable `/etc/sudoers.d/*`, writable systemd units, writable `/etc/ld.so.preload`. See [[writable-passwd-shadow]].

**6. Kernel exploits** — last resort because of crash risk; only after fingerprinting. See [[kernel-exploits-linux]].

**7. NFS no_root_squash** — write a setuid root binary from a client where you're root, execute on target. See [[nfs-no-root-squash]].

**8. Containers** — Docker socket, privileged container, mounted host paths, kernel CVE that bypasses the seccomp profile, userns abuse. See [[container-escape-techniques]] and [[user-namespace-attacks]].

**9. Service / daemon abuse** — listening root services on localhost (PostgreSQL trust, Redis without auth, Jenkins script console, exposed Docker API on tcp).

**10. Credential reuse** — passwords / SSH keys in dotfiles, history files, backup archives, world-readable config (`/var/www`, `/opt/<app>/config`), `.netrc`, `.aws/credentials`, `.kube/config`.

**Triage order in practice:**
```text
sudo -l → setuid → capabilities → cron/timers → service creds →
writable /etc → NFS → kernel exploit (last)
```

The same enumeration script (`linpeas`) catches the first eight; numbers 9–10 are where careful manual review wins.

## Detection and defence
- Layered: package-level perms audit, AuditD, AppArmor/SELinux confinement, sysctl hardening (`kernel.kptr_restrict=2`, `kernel.dmesg_restrict=1`, `kernel.unprivileged_userns_clone=0` where workload allows)
- File-integrity monitoring on `/etc`, `/usr/local/bin`, `/var/spool/cron`
- EDR rules for unusual setuid execs, capability-bearing binary execs, suid-shell spawn patterns

## References
- [HackTricks — Linux Privilege Escalation](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html) — the canonical map with deep links
- [PayloadsAllTheThings — Linux privesc](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Methodology%20and%20Resources/Linux%20-%20Privilege%20Escalation.md) — checklist with payloads
- [GTFOBins](https://gtfobins.github.io/) — binary-by-binary exploitation

Related: every other note in this category — this is the index.
