---
title: macOS architecture
slug: macos-architecture
---

> **TL;DR:** XNU is a Mach microkernel grafted onto a BSD personality; userland boots through `launchd`, and access control is enforced by a layered stack — Gatekeeper, code signing, the sandbox, TCC, and SIP.

## What it is
macOS runs on the **XNU** kernel: a Mach core providing tasks/threads, virtual memory, and IPC (ports, messages), wrapped by a BSD layer that exposes POSIX syscalls, VFS, sockets, and process model. On top sits a Darwin userland with **launchd** as PID 1, dyld as the dynamic linker, and a suite of Apple frameworks (CoreFoundation, Foundation, AppKit). Security is layered and overlapping — each control owns a slice of the threat model rather than one global policy.

## Preconditions / where it applies
- Anything you target on macOS — privesc, persistence, sandbox escape, kernel exploitation — sits inside this picture.
- Apple Silicon (arm64e) adds PAC and hardware page-protection that change exploit primitives versus Intel x86_64 builds.
- iOS, iPadOS, watchOS, tvOS share XNU and dyld but enforce stricter signing/sandbox policies — see [[ios-vs-macos-divergence]].

## Technique
Mental model when triaging a target:

1. **Kernel surface** — Mach traps (`mach_msg`, port rights), BSD syscalls, IOKit user clients. See [[iokit-attack-surface]] and [[mach-and-xpc]].
2. **Userland boot** — `launchd` reads plists under `/System/Library/LaunchDaemons`, `/Library/LaunchDaemons`, `~/Library/LaunchAgents`. Persistence and privesc often live here.
3. **Process identity** — every binary carries a code signature and entitlements; the kernel checks them at `exec` and at IPC connect time. See [[entitlements-and-codesigning]].
4. **Sandbox** — Sandbox.kext consults a compiled `sb` profile per process; default app sandbox blocks most filesystem and Mach service access. See [[macos-sandbox-escape]].
5. **TCC** — a userspace daemon (`tccd`) gates access to Documents, Camera, Microphone, Full Disk, Accessibility, etc. See [[macos-tcc]].
6. **SIP** — kernel-enforced restriction on root: protected paths, protected processes, restricted dyld behaviour. See [[sip]].
7. **Gatekeeper / notarisation** — first-launch checks on quarantined files. See [[gatekeeper-and-notarisation]].

Useful triage commands:

```bash
csrutil status                                  # SIP state
codesign -dv --entitlements - /path/to/binary   # signature + entitlements
launchctl list                                  # user/agent jobs
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db .schema
spctl --status                                  # Gatekeeper
```

Knowing which layer is closest to your goal saves you chasing the wrong primitive — TCC bypasses do nothing about SIP, sandbox escapes do not by themselves bypass entitlements.

## Detection and defence
- EDR hooks `EndpointSecurity` events (`ES_EVENT_TYPE_NOTIFY_EXEC`, `_OPEN`, `_MMAP`, `_IOKIT_OPEN`) — these are the supported telemetry surface, not kauth.
- Defenders look for unsigned/ad-hoc-signed binaries, entitlement anomalies, and launchd plist drops in user/global LaunchAgents/Daemons.
- Hardening: enable FileVault, keep SIP enabled, restrict admin accounts, deploy MDM with allow-list policies for kexts/system extensions.

## References
- [Apple Platform Security Guide](https://support.apple.com/guide/security/welcome/web) — official architecture and security model.
- [HackTricks — macOS basics](https://book.hacktricks.wiki/en/macos-hardening/macos-security-and-privilege-escalation/index.html) — practical offensive overview.
- [Patrick Wardle — The Art of Mac Malware](https://taomm.org/) — supporting material on Mach-O, persistence, and defences.
