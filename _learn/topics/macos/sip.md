---
title: System Integrity Protection (SIP)
slug: sip
---

> **TL;DR:** SIP ("rootless") is a kernel-enforced cap on what even root can do: protected filesystem paths cannot be written, protected processes cannot be debugged or have their entitlements queried/loaded, and dyld ignores `DYLD_*` env vars for restricted binaries.

## What it is
**System Integrity Protection** is a set of kernel checks gated by a NVRAM flag (`csr-active-config`) and consulted by:
- the **file-system layer** — flagged paths/files carry `SF_RESTRICTED` and `SF_NOUNLINK` and cannot be modified;
- **AppleMobileFileIntegrity (AMFI)** — restricted binaries refuse `DYLD_INSERT_LIBRARIES`, `DYLD_LIBRARY_PATH`, `DYLD_FRAMEWORK_PATH`, and similar;
- **kext / driver loading** — only kernel extensions signed by Apple (or those explicitly allowed by the user in Recovery + MDM) are loaded;
- **`task_for_pid` restrictions** — root cannot get a task port to a SIP-protected process.

It exists because pre-SIP macOS treated root as omnipotent, which was too coarse for a single-user desktop OS facing modern malware and attackers post-LPE.

## Preconditions / where it applies
- Default on every modern macOS. State queried via `csrutil status`.
- Toggling requires Recovery Mode + Apple Silicon "Reduced Security" or Intel `csrutil disable`.
- Relevant to: kernel exploit dev (need SIP off for dev kernels — see [[macos-kernel-debugging]]), persistence (protected paths are off-limits), EDR (cannot tamper with `/System` even as root), attacker chains needing arbitrary file write under protected paths.

## Technique
What SIP blocks, concretely:

```bash
csrutil status
ls -lO /System/Library/CoreServices    # 'restricted' flag = SF_RESTRICTED
xattr -lr /Applications/Safari.app | grep com.apple.rootless
```

Restricted paths (non-exhaustive): `/System`, `/usr` (except `/usr/local`), `/bin`, `/sbin`, `/var`, parts of `/Applications` shipped with the OS. Protected processes: many Apple daemons (`launchd`, `tccd`, `cfprefsd`, `coreduetd`).

What it does *not* block:
- Writes under `/usr/local`, `/Library`, `/etc` (the symlinks), `/Users`.
- Loading code into your *own* unrestricted processes.
- Most of TCC's data — TCC has its own enforcement layered on top.

For an attacker post-root, SIP means:
- Cannot drop a kext / persist in `/System/Library/LaunchDaemons`.
- Cannot inject into protected daemons via `DYLD_INSERT_LIBRARIES` or `task_for_pid`.
- Cannot disable TCC by editing the system DB.
- Must either find a SIP bypass (see [[sip-bypasses]]) or persist in unprotected user/system locations only.

Identify restricted binaries from a target:

```bash
codesign -dv --entitlements - /usr/libexec/installd 2>&1 | grep restricted
ls -lO /usr/libexec/installd
```

Useful entitlements unlocking SIP-equivalent powers: `com.apple.rootless.install`, `com.apple.rootless.install.heritable`, `com.apple.private.responsibility.set-tcc`. Apple grants these only to specific shipped binaries — hijacking such a binary is the core of many SIP bypass chains.

## Detection and defence
- `csrutil disable` is a *huge* defender signal — alert MDM on any boot where `csr-active-config` is non-default.
- Endpoint logs: `AppleSystemPolicy.kext` records denied writes to restricted paths; `amfid` logs library-load decisions.
- Hardening: leave SIP fully enabled, disable kext loading on Apple Silicon where possible (use System Extensions / DriverKit), monitor `nvram boot-args` for `-no_compat_check`, `kcsuffix=debug`, etc.

## References
- [Apple — System Integrity Protection](https://support.apple.com/en-us/HT204899) — official overview.
- [Apple — Configuring System Integrity Protection](https://developer.apple.com/documentation/security/disabling_and_enabling_system_integrity_protection) — how it can be toggled.
- [HackTricks — macOS SIP](https://book.hacktricks.wiki/en/macos-hardening/macos-security-and-privilege-escalation/macos-security-protections/macos-sip.html) — restricted-flag mechanics and bypass classes.
