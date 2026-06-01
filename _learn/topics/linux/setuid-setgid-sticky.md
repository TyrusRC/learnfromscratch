---
title: setuid / setgid / sticky
slug: setuid-setgid-sticky
---

> **TL;DR:** Three special permission bits — setuid (run as file owner), setgid (run as file group / inherit group on dirs), sticky (only owner can delete in dir) — and the kernel rules that make them safe (or not) to design around.

## What it is
On Linux, every file has three "special" mode bits beyond the rwx triplets. They change the kernel's behaviour at `execve()` time (setuid/setgid) and at `unlink()` time (sticky). Misunderstanding when they apply, on what, and which kernel sanitisations kick in is the root cause of a long line of privesc bugs.

## Preconditions / where it applies
- You're designing or auditing a privileged Unix binary, a shared directory like `/tmp`, or a setgid-shared workgroup directory
- You're triaging a setuid binary you just discovered with `find / -perm -4000 -type f`

## Technique

**The three bits, octal-prefix `4`/`2`/`1`:**

| Bit | On file | On dir |
|---|---|---|
| setuid (4xxx) | `execve()` sets `euid = file owner` | (no effect on Linux) |
| setgid (2xxx) | `execve()` sets `egid = file group` | new files inherit dir's group |
| sticky (1xxx) | (no effect on regular files) | only file owner (or root) can unlink |

Display with `ls -l`:
- `rws` / `rwS` — setuid set; capital `S` means execute bit absent
- group `rws` / `rwS` — setgid
- `rwt` / `rwT` — sticky on dir (`/tmp` is `drwxrwxrwt`)

**Kernel sanitisations for setuid/setgid execve (`AT_SECURE`):**
1. `LD_PRELOAD`, `LD_LIBRARY_PATH`, `LD_AUDIT` stripped (unless allowed via `/etc/ld.so.conf` trusted dirs)
2. stdin/stdout/stderr (fd 0,1,2) opened to `/dev/null` if missing
3. Some glibc functions check `__libc_enable_secure` and disable risky behaviour
4. Core dumps disabled by default (`suid_dumpable=0`)

**Safe setuid binary design checklist:**
- Use absolute paths in any `system()`/`exec*()` call
- Reset `PATH`, `IFS`, locale env (`LANG`, `LC_*`) at process start
- Drop privileges with `setresuid(uid,uid,uid)` as soon as the privileged op is done
- Don't `fopen()` user-supplied paths; use `openat()` with `O_NOFOLLOW`
- Don't trust env for any config; require explicit args
- Static-link if feasible to dodge library-path attacks

**Common bug patterns in custom setuid binaries:**

```c
// 1) PATH attack
system("ls /var/log");           // BAD: unqualified
execl("/bin/ls", "ls", "/var/log", NULL);  // OK

// 2) Symlink follow as root
fopen(user_supplied, "r");       // BAD if not O_NOFOLLOW
openat(dirfd, name, O_RDONLY|O_NOFOLLOW);

// 3) Format string
printf(user_input);              // BAD
puts(user_input);                // OK

// 4) Race on temp file
mktemp("/tmp/foo.XXXX");         // BAD, predictable
mkstemp(template);               // OK
```

**Sticky bit on `/tmp`:** the kernel still allows you to *read* files owned by others if the perms permit; sticky only stops `unlink()`/`rename()`. Hardlinks to suid binaries combined with a writable sticky dir used to be a privesc surface (CVE-2010-3856 class); `fs.protected_hardlinks` mitigates.

## Detection and defence
- `sysctl fs.protected_hardlinks=1 fs.protected_symlinks=1 fs.protected_fifos=2 fs.protected_regular=2` (defaults on modern distros)
- `nosuid` mount option on user-writable filesystems (`/tmp`, `/home`, removable media)
- Periodic diff of `find / -perm -4000 -o -perm -2000` against a baseline
- Use file capabilities or a privileged helper over IPC instead of setuid where possible

## References
- [chmod(1) and execve(2)](https://man7.org/linux/man-pages/man2/execve.2.html) — `AT_SECURE` semantics
- [Secure Programming HOWTO — setuid](https://dwheeler.com/secure-programs/) — David A. Wheeler's classic
- [HackTricks — SUID/SGID](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html#suid) — exploitation context

Related: [[suid-sgid-binaries]], [[capabilities-privesc]], [[path-hijacking]].
