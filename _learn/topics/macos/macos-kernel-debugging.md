---
title: macOS kernel debugging
slug: macos-kernel-debugging
---

> **TL;DR:** Run a development kernel (DEVELOPMENT or KASAN) on the target, attach LLDB from a second host over the **KDP** (Kernel Debug Protocol) transport, and use the matching kernel-debug-kit symbols. On Apple Silicon you typically debug via USB/Thunderbolt with a second Mac and `kdpserver`.

## What it is
The supported workflow for live kernel debugging on macOS uses two machines:
- **Target**: boots a non-RELEASE kernel (DEVELOPMENT, DEBUG, or KASAN), with `boot-args` enabling KDP and (on Intel) a debug-stub.
- **Host**: runs LLDB with the Apple-shipped `lldbmacros` Python helpers from the **Kernel Debug Kit (KDK)** matching the target's build.
Connection transports:
- **KDP over Ethernet** (classic, Intel) — `debug=0x144 kdp_match_name=en0`.
- **KDP over serial / IP** for Apple Silicon — typically `kmutil` / `kdpserver` over a USB-C debug cable using DCSD or the Apple Silicon debug probe.

## Preconditions / where it applies
- You have physical access to the target Mac and can disable SIP / set `nvram boot-args` (requires SIP off for most kernel-debug flags).
- A matching KDK is installed on the host — version skew silently breaks symbol resolution.
- Relevant for kernel exploit dev, kext reverse engineering, and analysing crash dumps from `panic.ips`. See [[iokit-attack-surface]] and [[apple-mitigations]].

## Technique
Setup outline (Intel target shown — Apple Silicon differs in transport but not in tooling):

1. **Install matching KDK** on host (download from Apple Developer site under "More Downloads").
2. **On target**: install the same KDK so the dev kernel is available, then:
   ```bash
   sudo cp /Library/Developer/KDKs/KDK_*.kdk/System/Library/Kernels/kernel.development \
       /System/Library/Kernels/
   sudo kmutil install --volume-root / --update-all
   sudo nvram boot-args="debug=0x141 -v kcsuffix=development pmuflags=1"
   sudo reboot
   ```
3. **On host**, after the target panics or you trigger an NMI (power+Cmd+Ctrl+Option+Shift+. or `dtrace -w -n "BEGIN { breakpoint(); }"`):
   ```bash
   lldb
   (lldb) kdp-remote 192.168.1.42
   (lldb) showalltasks       # macro from lldbmacros
   (lldb) showallthreads
   (lldb) showbinaryinfo <addr>
   ```
4. **Symbols and macros**: LLDB auto-loads `lldbmacros` from the KDK. `showallclasses`, `zprint`, `showmcache`, `showioservicetree` are essential for IOKit and zone analysis.
5. **Core dumps**: panics produce `/cores/*.core` (if `kern.coredump` is on) plus `panic.ips`. Open in LLDB with `lldb -c <core> /Library/Developer/KDKs/.../kernel.development`.

For early-boot or PPL-related panics on Apple Silicon, use Apple's **DCSD/Astris** cable + a second host running Xcode's `kdpserver`; this is the only way to break into pre-userland code.

## Detection and defence
- N/A as an attack — this is researcher tradecraft. But the *state* required (SIP off, dev kernel, debug `boot-args`) is itself a red flag if seen on a production endpoint: defenders alert on `csrutil disable`, non-standard `boot-args`, or `kernel.development` in `/System/Library/Kernels/`.
- For exploit-mitigation research, prefer KASAN kernels — they surface heap bugs immediately. See [[apple-mitigations]] for what is enforced even with debug kernels.

## References
- [Apple — Debugging the kernel with LLDB](https://developer.apple.com/documentation/kernel/debugging_the_kernel_with_lldb) — official setup.
- [Apple Developer Downloads — Kernel Debug Kits](https://developer.apple.com/download/all/?q=Kernel%20Debug%20Kit) — version-matched kernels and symbols.
- [Patrick Wardle / Objective-See — kernel debugging notes](https://objective-see.org/) — practical writeups across versions.
