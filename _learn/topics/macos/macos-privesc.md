---
title: macOS privesc
slug: macos-privesc
---

> **TL;DR:** Path-to-root on macOS rarely needs a kernel bug — it usually rides AuthorizationServices misuse, vulnerable `SMJobBless` privileged helpers, world-writable `launchd` paths, racy installer scripts, or sudo-like LOLBINs.

## What it is
A taxonomy of local privilege escalation paths on macOS userland, separate from kernel exploitation. The common theme: a root-running component (a daemon, a helper tool, an installer, an Apple LOLBIN) accepts attacker-controlled input — a path, an XPC method, an entitlement-gated request — without sufficient validation, and you ride it from your user context to root.

## Preconditions / where it applies
- You have user-shell code execution (post-phish, post-RCE).
- Target is fully patched but runs third-party software with privileged helpers, or admins have made local config mistakes.
- Relevant before any SIP/TCC bypass — being root is often the prerequisite for those. See [[sip]] and [[macos-tcc]].

## Technique
The main families, with the bug to look for:

1. **AuthorizationServices**
   - Tools like `AuthorizationExecuteWithPrivileges` (deprecated but still used) hand a file path to root; if the path is attacker-controlled before the prompt, you swap binaries between prompt and exec (TOCTOU). CVE-2008-0038 onwards.

2. **Privileged helpers via `SMJobBless`**
   - An app installs a helper to `/Library/PrivilegedHelperTools/com.vendor.helper`. The helper checks the client's Designated Requirement; if that requirement is weak (`anchor apple generic`), any signed app passes.
   - Audit: `codesign -d --requirements - /Library/PrivilegedHelperTools/*`.

3. **launchd misconfig**
   - Plists in `/Library/LaunchDaemons/` referencing a binary you can overwrite, or with `WorkingDirectory`/`StandardOutPath` writable. Replace the target, restart the daemon (or wait for boot), gain root.
   - `find /Library/LaunchDaemons /Library/LaunchAgents -name '*.plist' -exec plutil -p {} \;` and inspect every `Program*` value.

4. **Vulnerable installer scripts**
   - `.pkg` postinstall scripts run as root; if they `cp` or `chown` paths under `/tmp` or `/Users/Shared`, race them with a symlink to gain arbitrary file write. Also: pre-existing installer staging in `/var/folders/` reused across runs.

5. **Sudo-equivalent LOLBINs**
   - Tools running as root that perform actions on user-supplied input. Examples: `at`, `cron` (with admin), older `mount_*` quirks, `kmutil`, vendor MDM agents. The macOS equivalent of GTFOBins is a moving list — always check `codesign -dv` and `ls -l@e` on suspicious setuid bits (`find / -perm -4000 2>/dev/null`).

6. **Dock / Login-item hijacking**
   - User-context primitives (escalate to admin, then to root via the above). Persistence and privesc overlap heavily here.

Quick recon block:

```bash
ls -la@e /Library/PrivilegedHelperTools/
ls -la /Library/LaunchDaemons /Library/LaunchAgents
codesign -d --entitlements - /Library/PrivilegedHelperTools/* 2>/dev/null
find / -perm -4000 -type f 2>/dev/null
sudo -nl 2>/dev/null
sw_vers; uname -a
```

For chains needing the kernel — see [[iokit-attack-surface]] and [[macos-kernel-debugging]].

## Detection and defence
- EndpointSecurity events on `ES_EVENT_TYPE_NOTIFY_EXEC` from `/Library/PrivilegedHelperTools/` with unexpected client identity.
- Restrict who can write `/Library/LaunchDaemons/` (root-only). Audit MDM-deployed helpers for weak Designated Requirements.
- Disable legacy `AuthorizationExecuteWithPrivileges` in your own apps; use `SMAppService` (macOS 13+) for new helper installs.
- Monitor `system.log` and unified-log subsystems for `smd`, `authd`, `installd`.

## References
- [Wojciech Reguła — Learn XPC exploitation](https://wojciechregula.blog/post/learn-xpc-exploitation-part-1-broken-cryptography/) — privileged helper bugs.
- [HackTricks — macOS local privilege escalation](https://book.hacktricks.wiki/en/macos-hardening/macos-security-and-privilege-escalation/index.html) — comprehensive checklist.
- [Csaba Fitzl — macOS privilege escalation writeups](https://theevilbit.github.io/) — repeated case studies.
