---
title: IOKit attack surface
slug: iokit-attack-surface
---

> **TL;DR:** IOKit is XNU's C++ driver framework. Each driver exposes a `IOUserClient` subclass whose `externalMethod` dispatch table is reachable from userspace — and that dispatch table is where most macOS/iOS LPE and jailbreak bugs live.

## What it is
**IOKit** is the Mach-based driver model used by graphics, audio, networking offload, USB, and Apple-silicon coprocessors. A user app calls `IOServiceOpen` to instantiate a driver-specific `IOUserClient`, then invokes typed methods via `IOConnectCallMethod`. Each method takes scalar inputs, optional structure input, scalar outputs, and a structure output. The kernel-side handler is C++ on top of `OSObject`/`OSDictionary`/`OSArray`, frequently dealing with shared memory mappings and async notifications via Mach ports.

## Preconditions / where it applies
- Local code execution as a user with access to the driver's `IOService` (the sandbox controls which user clients you can open via `com.apple.security.iokit-user-client-class` entitlements).
- Major historical sources of macOS LPE and iOS jailbreaks (AppleAVE, IOSurface, AGX/AppleM2, AppleMobileFileIntegrity, AppleUSB).
- Relevant after a sandbox escape to reach root or kernel; see [[macos-sandbox-escape]] and [[apple-mitigations]].

## Technique
General methodology:

1. **Enumerate reachable services** — `ioreg -l` lists the registry; `IOServiceMatching("AppleFoo")` + sandbox profile tells you what you can open.
2. **Pull the dispatch table** — disassemble the driver kext or DriverKit `.dext`, find `getTargetAndMethodForIndex` or the `IOExternalMethodDispatch` array. Each entry encodes input/output sizes; mismatches between declared sizes and actual handler assumptions are bugs.
3. **Audit typed shared memory** — many drivers `IOConnectMapMemory` a shared region; the kernel re-reads fields after validation (classic TOCTOU). On Apple Silicon, PPL/SPTM may still let you race a non-protected field.
4. **Look for object lifetime bugs** — `OSObject` reference counting in user-driven async callbacks is a long-running source of UAFs (e.g. CVE-2020-9907 AVEVideoEncoder, CVE-2021-30883 IOMobileFrameBuffer "FORCEDENTRY adjacent").
5. **Trigger** — build a small harness with `IOConnectCallStructMethod`, fuzz scalars/structs guided by handler size checks. `kmem`-style read/write primitives often fall out of a single confused dispatcher.

Minimal client skeleton:

```c
io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault,
    IOServiceMatching("AppleSomething"));
io_connect_t conn;
IOServiceOpen(svc, mach_task_self(), 0 /* type */, &conn);
uint64_t in_scalars[2] = { 0x41, 0x42 };
size_t out_count = 4;
uint64_t out_scalars[4] = {0};
IOConnectCallMethod(conn, /*selector*/ 7,
    in_scalars, 2, NULL, 0,
    out_scalars, &out_count, NULL, NULL);
```

Modern Apple moves drivers to **DriverKit** (`.dext` running in userspace), which shrinks the kernel attack surface but introduces new XPC-style attack surface in the system extension itself.

## Detection and defence
- Hardware mitigations (PAC, BTI, PPL/SPTM — see [[apple-mitigations]]) raise the bar significantly post-exploit. Bug-classes still exist; primitives are weaker.
- For defenders: kext load events show up via EndpointSecurity (`ES_EVENT_TYPE_NOTIFY_KEXTLOAD`). Restrict third-party kexts via MDM; prefer DriverKit.
- For developers: validate every userspace-supplied size *before* touching shared memory, use `OSSafeReleaseNULL` consistently, and adopt `IOUserClient::externalMethod` patterns that pin object lifetimes.

## References
- [Apple — IOKit Fundamentals (archived)](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/IOKitFundamentals/Introduction/Introduction.html) — base model.
- [Project Zero — IOKit research posts](https://googleprojectzero.blogspot.com/search/label/iOS) — many writeups on AppleAVE, IOSurface, etc.
- [HackTricks — macOS IOKit](https://book.hacktricks.wiki/en/macos-hardening/macos-security-and-privilege-escalation/mac-os-architecture/macos-iokit.html) — offensive primer.
