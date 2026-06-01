---
title: dyld shared cache extraction
slug: dyld-shared-cache-extraction
---

> **TL;DR:** iOS/macOS pre-link most system frameworks into one giant blob — `dyld_shared_cache_arm64e` — and individual `.dylib` files don't exist on disk; extract the cache with `dsc_extractor`/`ipsw` to get loadable Mach-Os you can disassemble, ROP-gadget, or diff across OS versions.

## What it is
The dyld shared cache (DSC) is Apple's solution to the launch-time cost of linking dozens of system frameworks. At OS build time, dyld pre-resolves all internal symbols across every `/usr/lib/*` and `/System/Library/Frameworks/*/X` Mach-O, fixes them up at a chosen base, and concatenates them into a single file (`/System/Library/dyld/dyld_shared_cache_<arch>` on macOS; on iOS the cache is inside the kernelcache region of the boot image). At runtime every process maps the cache at a randomised slide.

Consequence for reversers: those frameworks are not on disk as standalone `.dylib`s. You must *extract* them before standard tools work.

## Preconditions / where it applies
- macOS or iOS reverse engineering on system frameworks (Security, CoreFoundation, libsystem_kernel, etc.).
- An IPSW (iOS firmware bundle) or a macOS install with read access to `/System/Library/dyld/`.

## Technique
**1. Find the cache.**
- **macOS 13+:** `/System/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e` (and `_x86_64` on Intel). On older macOS: `/System/Library/dyld/`.
- **iOS:** inside the IPSW. Use `ipsw extract --dyld FW.ipsw` to extract the cache directly from the firmware bundle (which is itself a zip containing the system image).

**2. Inspect.**
```bash
# Apple's own tool (ships with Xcode)
dyld_shared_cache_util -info dyld_shared_cache_arm64e

# blacktop/ipsw — modern, scriptable
ipsw dyld info dyld_shared_cache_arm64e
ipsw dyld imports dyld_shared_cache_arm64e Foundation
ipsw dyld symaddr --image CoreFoundation dyld_shared_cache_arm64e "CFRelease"
```

**3. Extract individual dylibs.**
```bash
# Apple tool
dyld_shared_cache_util -extract out/ dyld_shared_cache_arm64e

# ipsw
ipsw dyld extract dyld_shared_cache_arm64e --output out/

# Older alternative: jtool2 --extract <Lib>
```
You get standalone Mach-O files under `out/System/Library/Frameworks/...` ready for Hopper / IDA / Ghidra.

**4. Loading the *whole* cache.** IDA Pro and Ghidra both have dyld-shared-cache loaders that index every framework in one project — much faster for cross-framework xref-hunting than extracting and reloading individually.
- IDA: `File → Open dyld_shared_cache_arm64e`, select frameworks of interest.
- Ghidra: install the `dyld_shared_cache` extension from the Ghidra `Extensions` menu.

**5. ROP-gadget sourcing.** The DSC is the largest single body of executable code in the system. For exploit dev on Apple Silicon, after one infoleak you typically use cache-resident gadgets:
```bash
ipsw dyld disass dyld_shared_cache_arm64e --image CoreFoundation --vaddr 0x...
ROPgadget --binary extracted/libsystem_c.dylib > gadgets.txt
```
Note: PAC-signed indirect branches in modern code break naive `ROPgadget` output — filter for raw `blr` / `br` instructions or use `pacman`-aware tooling.

**6. Diffing across OS versions.** Pull both versions of the cache, extract the framework you care about, and BinDiff / Diaphora. Apple patch-Tuesday CVEs are routinely reproduced by diffing successive IPSWs.
```bash
ipsw extract --dyld iOS_17.5.ipsw -o 17.5/
ipsw extract --dyld iOS_17.6.ipsw -o 17.6/
ipsw dyld extract 17.5/.../dyld_shared_cache_arm64e --image Security -o 17.5-sec/
ipsw dyld extract 17.6/.../dyld_shared_cache_arm64e --image Security -o 17.6-sec/
bindiff 17.5-sec/Security 17.6-sec/Security
```

**7. Kernelcache extraction (related).** The kernel itself is in `kernelcache.<device>` inside the IPSW — different format but same `ipsw kernel extract` / `joker -K` workflow.

## Detection and defence
- Not really applicable on the offensive side — the DSC is read-only and publicly distributed in IPSWs.
- For platform engineers: Apple has been steadily improving cache hardening (PAC discriminators, function-call diversity) to make leaked-pointer-to-gadget exploit chains harder.

## References
- [blacktop/ipsw](https://github.com/blacktop/ipsw) — modern Swiss-army tool for IPSWs / DSCs
- [Apple — dyld source](https://github.com/apple-oss-distributions/dyld) — canonical cache format
- *macOS and iOS Internals, Volume I* — Jonathan Levin; DSC chapter
- [Mandiant — DSC reversing techniques](https://www.mandiant.com/resources/blog) — practical workflow posts
