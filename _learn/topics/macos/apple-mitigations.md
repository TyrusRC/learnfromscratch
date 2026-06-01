---
title: Apple-platform mitigations
slug: apple-mitigations
---

> **TL;DR:** Apple Silicon stacks hardware mitigations — Pointer Authentication (PAC), Branch Target Identification (BTI), the page-protection layer (PPL/SPTM), and shared-cache/dyld closures — that together kill the easy ROP/JOP/code-injection patterns of the x86 era.

## What it is
A bundle of hardware- and OS-level controls Apple ships on arm64e and modern macOS/iOS:
- **PAC** signs pointers (return addresses, function pointers, C++ vtables) with a per-process key embedded in unused virtual-address bits; the CPU strips and authenticates on use.
- **BTI** requires indirect-branch targets to start with a special instruction, blocking arbitrary jumps into the middle of gadgets.
- **PPL** (Page Protection Layer) and on newer SoCs **SPTM** (Secure Page Table Monitor) wall off page-table updates and code-signing enforcement from compromised EL1 kernel code.
- **dyld closures / shared cache** pre-compute bind/rebase for system libraries, removing many writable function-pointer tables from process memory.

## Preconditions / where it applies
- Apple Silicon Macs (M1/M2/M3…), iOS, iPadOS — Intel Macs do not get PAC/BTI/PPL but do get the dyld shared-cache benefits.
- Relevant when developing kernel exploits ([[iokit-attack-surface]], [[macos-kernel-debugging]]), sandbox escapes ([[macos-sandbox-escape]]), or jailbreaks.
- Userland mitigations (PAC for return/call pointers) apply only to arm64e binaries; arm64 third-party apps still get coarse mitigations but not PAC on return addresses.

## Technique
What each mitigation forces an attacker to do:

- **PAC** — straight `pop {pc}` / `ret` gadgets fail because the popped return address has no valid signature. Workarounds: leak a signed pointer with a memory disclosure, forge with a PAC-signing oracle in the target, or pivot to a JOP-style chain that reuses existing signed pointers. PACMAN-class attacks brute-force PAC bits via speculative execution but require specific gadgets and timing.
- **BTI** — indirect jumps must land on `BTI c`/`BTI j` instructions. Cuts the gadget catalogue dramatically; combined with PAC, classic ROP is largely dead.
- **PPL / SPTM** — even with arbitrary kernel R/W, an attacker cannot map writable+executable pages, modify code signatures, or patch the kernel text. To run unsigned code post-exploit you must defeat PPL itself (historically via flaws in the PPL trampolines) or stay in data-only exploitation.
- **dyld shared cache** — `__DATA` slots for system libs are computed at build time; tampering shows up as cache-mismatch panics. Userland injection has moved toward `DYLD_INSERT_LIBRARIES` (blocked for hardened/platform binaries) and entitlement-gated attach.

Quick check on a binary:

```bash
otool -hv /usr/bin/some_tool | grep -E "PAC|cputype"
codesign -dv --entitlements - /usr/bin/some_tool 2>&1 | grep -i hardened
```

## Detection and defence
- Defenders rely on Apple's vuln-fix cadence — these mitigations move primitives, they do not eliminate bugs. Track Apple security releases and CVE notes for kernel and dyld.
- For enterprise: enforce Hardened Runtime, Library Validation, and notarisation on internal apps; do not ship binaries with `com.apple.security.cs.disable-library-validation` unless absolutely required.
- On the offensive side, exploit research now leans data-only and entitlement-abuse rather than classic code-injection. See [[sip-bypasses]] and [[tcc-bypasses]].

## References
- [Apple — Operating system integrity](https://support.apple.com/guide/security/operating-system-integrity-sec8b776536b/web) — PAC, PPL, SPTM overview.
- [Project Zero — Examining Pointer Authentication on the iPhone XS](https://googleprojectzero.blogspot.com/2019/02/examining-pointer-authentication-on.html) — canonical PAC analysis.
- [PACMAN paper (MIT)](https://pacmanattack.com/) — speculative attack against PAC.
