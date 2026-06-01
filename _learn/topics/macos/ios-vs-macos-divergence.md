---
title: iOS vs macOS divergence
slug: ios-vs-macos-divergence
---

> **TL;DR:** macOS and iOS share XNU, dyld, and most frameworks, but iOS enforces mandatory code signing, has no user-removable Gatekeeper, runs every app in a tighter sandbox profile, and exposes a smaller (different) IOKit surface. Kernel bugs port; userland exploitation strategies often do not.

## What it is
Both platforms compile from the same Darwin tree. What differs is enforcement and surface:
- **Signing**: iOS rejects any non-Apple-signed code at exec; macOS only rejects unsigned/quarantined code on Apple Silicon and via Gatekeeper for downloaded binaries.
- **Sandbox**: iOS apps run under a hard container profile from day one; macOS apps may opt out of the App Sandbox entirely.
- **Hardware**: iOS has always been arm64(e) with PAC/PPL/SPTM; macOS spans Intel x86_64 and Apple Silicon arm64e.
- **IOKit**: drivers and user-client classes differ — `AppleAVE`, `IOMobileFrameBuffer` are iOS-flavoured; `AppleGraphicsControl`, `IOAudioFamily` are macOS-flavoured.
- **TCC / Privacy**: iOS prompts via SpringBoard with permanent-style policy; macOS uses `tccd` with a per-user SQLite store. See [[macos-tcc]].

## Preconditions / where it applies
- Choosing which platform to research a given bug class on.
- Porting a public macOS exploit to iOS (or vice-versa).
- Building tooling that should run on both (e.g. EndpointSecurity exists on macOS only; iOS uses different telemetry).

## Technique
Decision rules when triaging a target:

1. **Pure kernel bug** (XNU heap, mach trap, BSD syscall): often portable in core logic, but mitigations differ — Apple Silicon iOS has PPL/SPTM and stricter KTRR than even macOS. PoC primitive may need rebuilding.
2. **dyld / dynamic loader bug**: usually portable; same code on both.
3. **IOKit driver bug**: only portable if the driver exists on both. Many do not (camera ISP, AGX variants differ).
4. **Userspace daemon (`launchd`, `cfprefsd`, `tccd`)**: code is shared; reachability differs because the iOS sandbox blocks Mach lookups that macOS allows.
5. **WebKit / JavaScriptCore**: nearly identical surface; Safari iOS and Safari macOS share the same exploit story modulo JIT hardening.
6. **Filesystem / APFS**: shared; mount semantics differ (iOS read-only system volume is sealed harder).

Practical mapping for a researcher:

```
shared:   XNU traps, BSD syscalls, dyld, libsystem, WebKit/JSC, APFS, Sandbox.kext
diverges: signing enforcement, App Sandbox profile, IOKit drivers, system extensions,
          TCC UI, persistence mechanisms, EndpointSecurity availability
```

iOS jailbreaks now lean on **kfd** / **dirtyJSC** / coprocessor bugs because they survive PPL; on macOS, the same primitives matter for kernel R/W but you may not even need them for an LPE that abuses entitlements alone — see [[macos-privesc]].

## Detection and defence
- For iOS fleet defence: rely on MDM + Lockdown Mode + Rapid Security Responses; there is no on-device EDR equivalent to EndpointSecurity.
- For macOS: deploy EndpointSecurity-based EDR, enforce notarisation, restrict admin rights, monitor TCC and SIP changes.
- For researchers: when a CVE is "macOS only" or "iOS only", check whether the root-cause file is shared in xnu/dyld — many "macOS only" advisories were quietly applicable to iOS too.

## References
- [Apple Platform Security Guide](https://support.apple.com/guide/security/welcome/web) — official differences across platforms.
- [Project Zero — In the wild iOS analyses](https://googleprojectzero.blogspot.com/) — repeated cross-platform discussions.
- [Apple Open Source — XNU](https://github.com/apple-oss-distributions/xnu) — confirms shared kernel code.
