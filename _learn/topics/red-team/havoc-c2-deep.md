---
title: Havoc C2 — operator's view
slug: havoc-c2-deep
aliases: [havoc-deep, havoc-framework]
---

> **TL;DR:** Havoc is an open-source modern C2 framework (C5pider, late 2022 onward) written in C/C++ and Go, designed with EDR-evasion-first ethos. Implant is "Demon" — heavy on indirect syscalls, ROP-based stack-spoofing, sleep obfuscation. Targets Windows primarily. Popular with red teams and increasingly with criminal operators. Companion to [[c2-frameworks]] and [[sliver-c2-deep]].

## Why Havoc

- **EDR-evasion built in**: indirect syscalls, sleep obfuscation (Ekko / Foliage / Zilean), stack spoofing.
- **BOF-compatible** — runs Cobalt Strike Beacon Object Files directly.
- **Custom packer support** for the implant.
- **Modern build pipeline** — easy to customise per-engagement.
- **Open source** — auditable.

Compared to Sliver: Havoc trades cross-platform breadth for Windows depth and evasion focus.

## Architecture

- **Teamserver** — written in Go; manages operator connections, implants, listeners, profile.
- **Client** — Qt-based GUI (cross-platform).
- **Demon (implant)** — C/C++ x64/x86; supports HTTP(S) and SMB transports.

## Demon features

- **In-memory execution** of PE files, .NET assemblies, BOFs.
- **Process injection** — multiple techniques (NtMapViewOfSection, Module Stomping, Thread Hijacking).
- **Lateral movement** — SMB pivot via named pipes.
- **Token impersonation** — duplicate token, run as.
- **Sleep obfuscation** — encrypt the implant in memory during sleep, decrypt for callback.
- **Indirect syscalls** — see [[syscall-direct-and-indirect]].
- **Stack spoofing** — call stack rewriting at sensitive points to evade callstack-based detection.

## Transports

- **HTTPS** — primary; supports custom listener profiles.
- **SMB** — named-pipe transport for pivoting.

Profile customisation supports header naming, sleep / jitter, URI patterns. Tune for blending with target.

## EDR evasion specifics

### Sleep obfuscation

When Demon is idle waiting for tasks, the entire implant region in memory is encrypted with a key that's swapped in only when active. Memory scans during sleep see encrypted garbage; only at task-execute moments is the implant decrypted.

Techniques offered:
- **Ekko** — built on `WaitForSingleObject` + APC.
- **Foliage** — based on `NtContinue`.
- **Zilean** — fiber-based.

Each has trade-offs in stealth vs reliability.

### Indirect syscalls

Demon calls `Nt*` APIs via syscall instructions directly, bypassing ntdll hooks. See [[syscall-direct-and-indirect]].

### Stack spoofing

When making a sensitive call (e.g., `NtAllocateVirtualMemory`), Demon rewrites the call stack to look like the call originated from a legitimate Windows DLL. EDRs using callstack analysis ([[edr-hooks-and-unhooking]]) see "explorer.exe → kernel32" instead of "demon implant → kernel32".

## OPSEC considerations

- **Default implant signatures** are detected by major EDRs. Operators rebuild with modifications.
- **Sleep obfuscation reduces but doesn't eliminate detection** — long-sleep + obfuscated patterns are themselves anomalous if you look at the *process behaviour over time*.
- **HTTPS callback timing** — short jitter is fingerprintable; long jitter slows operations.

## Threat-actor adoption

- Multiple ransomware crews have adopted Havoc since 2023.
- 0ktapus, Black Basta affiliates, and Snatch crew observed using Havoc in IR.
- The same source-code accessibility means defenders can build robust detections by studying Demon internals.

## Comparing to Sliver and Cobalt Strike

| Property | Cobalt Strike | Sliver | Havoc |
|----------|----------------|--------|-------|
| Cost | $5,500/year/seat | Free | Free |
| OPSEC default | Detectable | Mid | Strong (defaults focus on evasion) |
| Cross-platform implant | Windows-first | Yes | Windows-first |
| Source available | Closed (cracked versions exist) | Yes | Yes |
| BOF support | Native | Yes (subset) | Native |
| Sleep obfuscation | Optional (Sleepmask) | Limited | Built-in (multiple variants) |
| Maturity | High | High | Mid (active development) |

Operators often run all three at different times depending on engagement.

## Workflow to study

1. Build Havoc from source on a Linux VPS.
2. Generate a Demon implant with default options.
3. Deploy to a Windows test VM with Defender enabled.
4. Observe Defender detection — likely detects default build.
5. Tune profile: change sleep technique, enable indirect syscalls.
6. Test BOF execution.
7. Examine detection from the defender side (Sysmon, EDR logs).

## Related

- [[c2-frameworks]] — generic concepts.
- [[sliver-c2-deep]] — alternative framework.
- [[mythic-framework-deep]] — Mythic.
- [[syscall-direct-and-indirect]] — used by Demon.
- [[edr-hooks-and-unhooking]] — evasion class.
- [[module-stomping]], [[ntmapviewofsection-injection]], [[thread-hijacking]] — injection techniques Demon supports.

## References
- [Havoc project](https://github.com/HavocFramework/Havoc)
- [C5pider's blog](https://5pider.net/blog/)
- [MDSec / Outflank — Demon analysis](https://www.mdsec.co.uk/)
- See also: [[c2-frameworks]], [[sliver-c2-deep]], [[mythic-framework-deep]], [[syscall-direct-and-indirect]], [[cobalt-strike-malleable-c2-profiles]], [[donut-shellcode-generation]]
