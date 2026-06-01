---
title: SIP bypasses
slug: sip-bypasses
---

> **TL;DR:** SIP bypasses tend to abuse an Apple binary that holds a `com.apple.rootless.*` entitlement: hijack its inputs (symlink/installer races), inject into it via lax library validation, or trick it into writing where you want — and the kernel allows the write because the *process* is entitled.

## What it is
The kernel's SIP check is essentially: "does the calling process hold an entitlement that exempts it for this path?" There is a small set of Apple-shipped binaries with sweeping entitlements (`com.apple.rootless.install`, `com.apple.rootless.install.heritable`, `com.apple.private.installer.*`). Hijacking one of those — by influencing its input, its loaded libraries, or its child process — is the canonical SIP bypass pattern.

## Preconditions / where it applies
- Already running as root (most paths). A few sandbox-to-SIP-bypass paths exist but are rarer.
- Target binary's entitlements and code-signing posture create the opening.
- Relevant when you need to write `/System/Library/LaunchDaemons/`, modify protected TCC DB, or load an unsigned kext-equivalent. See [[sip]] and [[entitlements-and-codesigning]].

## Technique
Recurring bypass classes with public CVE examples:

1. **Privileged-installer symlink races ("Shrootless"-style)**
   - CVE-2021-30892 ("Shrootless"): `system_installd` processed PKG postinstalls with `com.apple.rootless.install.heritable`, and any child process inherited the entitlement. By crafting a PKG that ran a payload via a writable `zshenv`, the payload inherited SIP exemption and could write `/System`.
   - General pattern: find a SIP-entitled process that execs an attacker-controlled binary, intermediate file, or honours an env var.

2. **Heritable-entitlement child exec**
   - Like above, the `.heritable` flag means children of the entitled binary keep the bypass. Any path where the entitled binary calls `system(3)`, `posix_spawn`, or loads a script you can influence is candidate.

3. **Library-validation gaps**
   - Some shipped Apple binaries did not enforce strict library validation; injecting a dylib via `DYLD_INSERT_LIBRARIES` was possible against them (CVE-2015-3760 and family, before Apple tightened). Less common today but periodically rediscovered in third-party Apple-signed components.

4. **Flag clearing via specific entitlements**
   - `com.apple.rootless.install` lets a process change file flags. If an attacker can run code inside an entitled helper, they can clear `SF_RESTRICTED` from a file and then rewrite it from any context.

5. **TCC-DB write through entitled proxy**
   - Some Apple binaries with `com.apple.private.tcc.manager.*` entitlements can mutate the SIP-protected TCC.db. Misuse pattern: argument injection into the entitled binary.

Practical hunt:

```bash
# Find SIP-rootless-entitled binaries shipped with the OS
sudo find /System /usr/libexec -type f -perm -u+x -exec sh -c \
  'codesign -d --entitlements - "$1" 2>/dev/null | grep -q com.apple.rootless && echo "$1"' _ {} \;
```

Then read what each does with arguments, env, and child processes — look for `system`, `popen`, `xpc_connection_create_mach_service` to lower-trust services, and writable paths it touches before dropping privileges.

## Detection and defence
- Apple patches each bypass per-CVE; keep current. The class is not closed.
- Defenders watch for `system_installd` running unexpected child processes, unusual PKG installs at odd times, and any file with `SF_RESTRICTED` flipped off (`ls -lO` shows `restricted`).
- Hardening: avoid third-party PKGs from unknown publishers, restrict installer execution via MDM, and audit any binary with `com.apple.rootless.install*` entitlements added by vendors.

## References
- [Microsoft — Shrootless (CVE-2021-30892)](https://www.microsoft.com/en-us/security/blog/2021/10/28/microsoft-finds-new-macos-vulnerability-shrootless-could-bypass-system-integrity-protection/) — canonical heritable-entitlement bypass.
- [Microsoft — Migraine (CVE-2023-32369)](https://www.microsoft.com/en-us/security/blog/2023/05/30/new-macos-vulnerability-migraine-could-bypass-system-integrity-protection/) — migration-helper bypass.
- [HackTricks — macOS SIP bypasses](https://book.hacktricks.wiki/en/macos-hardening/macos-security-and-privilege-escalation/macos-security-protections/macos-sip.html) — categorised class list.
