---
title: Cron job abuse
slug: cron-jobs
---

> **TL;DR:** Root-owned cron entries that call writable scripts, run from world-writable directories, or use unqualified binary names give attackers scheduled code execution as root.

## What it is
Cron runs scheduled commands as the user that owns the crontab — usually `root` for `/etc/crontab`, `/etc/cron.d/*`, and the `/etc/cron.{hourly,daily,weekly}/` drop-in directories. Any flaw in *what* those entries execute, *where* they execute from, or *what they trust on the way* converts into root-level code execution at the next tick.

## Preconditions / where it applies
- Local shell on a Linux host with cron / cronie / anacron installed
- Read access to `/etc/crontab` and `/etc/cron.d/` (world-readable on most distros)
- A flaw in the cron entry: writable target script, writable target directory, unqualified PATH lookup, wildcard glob, or env_keep-style leak

## Technique

**Enumeration first.** Read every cron source the system uses:
```bash
cat /etc/crontab /etc/cron.d/* 2>/dev/null
ls -la /etc/cron.{hourly,daily,weekly,monthly}/
cat /var/spool/cron/crontabs/* 2>/dev/null  # Debian
cat /var/spool/cron/*           2>/dev/null  # RHEL
systemctl list-timers --all                  # systemd timers (cron's modern replacement)
```

Pgrep-style monitoring catches transient cron tasks you didn't know existed — useful when you can't read root crontabs:
```bash
# pspy: passive process snooper, no root needed
./pspy64 -pf -i 1000
```

**Vector 1: writable script.** If a cron entry calls `/opt/backup.sh` and the file (or its directory) is writable, append a payload:
```bash
echo 'cp /bin/bash /tmp/r && chmod 4755 /tmp/r' >> /opt/backup.sh
```

**Vector 2: PATH attack.** Crontabs often start with `PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`. If an entry calls an unqualified name like `tar` and `/usr/local/bin` is writable (rare but happens in custom installs), plant a malicious `tar`. More commonly the entry sets a custom PATH that includes a writable directory.

**Vector 3: wildcard injection.** Classic `tar czf backup.tgz *` in a directory you can write to lets you smuggle `--checkpoint=1 --checkpoint-action=exec=sh shell.sh` by creating files named after those flags.

**Vector 4: race on world-writable cron dirs.** `/etc/cron.d/` set to 1777 (broken packaging) means dropping a file gives you root-cron execution.

## Detection and defence
- `find /etc/cron* -writable -ls` during host hardening; package permissions should be 644/755 root-owned
- File-integrity monitoring (auditd watch on `/etc/cron.d/`, `/etc/crontab`, `/var/spool/cron/`)
- Replace cron-script paths with absolute paths and validate input; quote globs (`tar czf backup.tgz -- *` and prefer `find ... -print0 | xargs -0`)
- Migrate to systemd timers with `ProtectSystem=strict`, `NoNewPrivileges=true`, and explicit unit hashes
- EDR rule: parent process `cron`/`CRON` spawning shells from non-system paths

## References
- [HackTricks — Cron Jobs](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html#scheduled-cron-jobs) — enumeration and exploitation
- [pspy](https://github.com/DominicBreuker/pspy) — passive cron/process visibility without root
- [GTFOBins — tar](https://gtfobins.github.io/gtfobins/tar/) — checkpoint-exec payload reference

Related: [[path-hijacking]], [[linux-privesc-vectors]], [[linux-enumeration]].
