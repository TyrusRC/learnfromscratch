---
title: Hells Gate / Halos Gate / Tartarus Gate / Phantom - comparison
slug: hells-halos-tartarus-gates-comparison
aliases: [hells-gate-comparison, gates-syscall-resolvers]
---

> **TL;DR:** The "Gate" family - Hells Gate, Halos Gate, Tartarus Gate, FreshyCalls / SysWhispers, and Phantom - are techniques for resolving Windows native syscall numbers (SSNs) at runtime or compile time so a payload can issue `syscall` directly without going through the EDR-hooked `ntdll!Nt*` stubs. They differ in how robust they are against EDR variations: Hells Gate assumes a clean `ntdll`, Halos Gate handles inline hooks by walking neighbours, Tartarus Gate handles split functions where the prologue is hooked but the body is intact, and Phantom uses sorted-by-SSN tables. This note compares them and links to [[syscall-direct-and-indirect]], [[edr-hooks-and-unhooking]], [[amsi-memory-patching-deep]], [[etw-tampering-deep]], and [[edr-bypass-at-exploitation-time]].

## Why it matters

Modern EDR sits primarily in userland via inline hooks in `ntdll.dll` - the vendor rewrites the first bytes of `NtOpenProcess`, `NtAllocateVirtualMemory`, `NtProtectVirtualMemory`, `NtCreateThreadEx`, and friends to jump to their telemetry code before the real `syscall` instruction executes. The classical bypass is "go direct": construct the syscall number in `eax`, put the call gate in `r10` and `rcx`, issue `syscall`, return. The problem is *where do you get the syscall number from?*

Hard-coding SSNs is fragile because Microsoft renumbers them on every Windows build. The Gate family solves this by reading the syscall number out of `ntdll` at run time (or generating stubs at compile time that do so). Each variant addresses a specific EDR counter-measure.

If you only know one of these techniques, you will be defeated by the first EDR that varies its hooking strategy. The honest practitioner's job is to know which Gate to reach for under which hook regime, and to understand that the existence of a Gate-style stub itself is a strong static signature for modern AVs.

## Classes / patterns / process

### The shared problem

Every `ntdll!Nt*` stub on a clean Windows install looks roughly like:

```
4C 8B D1            mov r10, rcx
B8 18 00 00 00      mov eax, 0x18    ; <-- syscall number
F6 04 25 ...        test byte ptr [...], 1
75 03               jne short hook
0F 05               syscall
C3                  ret
```

The number after `mov eax,` is the SSN. The Gate techniques all want to read that constant.

### Hells Gate

- Author: am0nsec / SmellyVx, public ~2020.
- Walks the export table of `ntdll`, finds the address of each `Nt*` function, and reads bytes 4-7 to extract the `mov eax, imm32` constant.
- Assumes the function prologue is unmodified.
- **Breaks immediately** when EDR has hooked `ntdll` because byte 0 is no longer `4C` (`mov r10, rcx`); it's `E9` (`jmp <hook>`) or `49 BB` (`mov r11, ...`) or whatever the vendor uses.
- Detection signature: walking `ntdll` exports filtered by `"Nt"` prefix and reading the `mov eax` constant.

### Halos Gate

- Author: Sektor7 / RTO and Reenz0h, public ~2021, named because "if Hell is hooked, look at Heaven (halos) - the neighbours".
- When the target function is hooked (byte 0 is not `0x4C`), walk up and down in 32-byte increments to neighbouring `Nt*` stubs. Their SSNs increase / decrease monotonically with address in most builds, so once you find an unhooked neighbour you can derive the target SSN by adding / subtracting the index distance.
- Robust against the common "hook every Nt function" pattern *as long as not every stub is hooked* (EDRs typically hook 20-60, not all ~470).
- Detection: walking export table and probing many neighbours; the access pattern itself is noisy.

### Tartarus Gate

- Author: trickster0, public ~2021, builds on Halos.
- Handles the case where the EDR places a hook in the middle of the stub (after `mov eax`) rather than at byte 0 - a "split" hook. In that case Hells-style extraction still works for the SSN (the `mov eax` is intact) but the syscall instruction is gone, so you must still issue your own `syscall` afterwards. Tartarus simply tries Hells first, then falls back to Halos if the prologue is mangled.
- Practically the most robust of the three for *runtime* extraction.

### FreshyCalls and SysWhispers (1/2/3)

- Compile-time syscall stub generators (jlospinoso, klezVirus, etc).
- A Python script reads SSNs for a chosen Windows build and emits a `.asm` / `.c` pair with a stub per syscall containing the literal `mov eax, <ssn>` and a `syscall ret`.
- SysWhispers3 additionally supports:
  - Random function names per build (defeat static AV strings).
  - "Egg-hunter" style where the syscall instruction is fetched from a random `ntdll` byte (indirect syscalls, breaks naive return-address checks that flag `syscall` returning into a non-`ntdll` page).
  - Jumper / jumper-randomized modes that jmp into a real `ntdll` `syscall` gadget for the return address.
- Tradeoff: SSNs are baked in. Wrong build = invalid syscall = `STATUS_INVALID_SYSTEM_SERVICE` (0xC000001C) on the spot.

### Phantom / Phantom-DLL-Hollowing / Phnt-style sorted gates

- Newer technique (TamperedChef, RedTeamSecOps, ~2023-2024). Rather than walking exports, sort `Nt*` addresses ascending; the index in the sorted table corresponds to SSN ordering. You can derive SSNs without reading any `mov eax` constant at all, because Microsoft assigns SSNs in load-order. This defeats *both* prologue hooks and `mov eax` overwrites.
- Variants: "Hex" / "HexGate" uses a hash of the function name to obscure which syscall is being targeted in static analysis.
- Caveat: a couple of `Zw` aliases and rearrangements between builds can throw indices off by one; production implementations special-case the known oddities.

### Indirect syscalls

- All Gate variants benefit from making the `syscall` instruction itself *not* live in the attacker's executable page. Instead, you `jmp` to a `syscall; ret` gadget inside `ntdll`, so the return address on the stack points into `ntdll` and userland stack walks taken by the EDR look normal. See [[syscall-direct-and-indirect]] for the call-site detail.
- An indirect-syscall Gate effectively decouples three concerns: (a) discovering the SSN, (b) loading the SSN into `eax`, and (c) the actual `syscall` instruction. The first two happen in your code; the third happens at a known `ntdll` address. Most modern EDR bypass payloads combine Tartarus or Phantom for (a/b) with an indirect dispatcher for (c).

### Hex variant and name-hash hardening

- The "Hex" variant of Hells Gate replaces ASCII export-name comparisons with a per-build hash (djb2, ROR13, fnv1a). The defender's static scanner cannot grep for `NtAllocateVirtualMemory` in your binary because the string is never present. Combined with stripped imports it can knock a payload out of generic AV detection while still triggering behavioural EDR.
- A common practitioner mistake is using the same hash constant as a public PoC - vendors signature the hash constant just as readily as the string. Generate a per-build random seed.

### Cross-build fragility

- Hells / Halos / Tartarus all resolve at runtime, so they survive Windows version bumps without rebuilds. SysWhispers-style compile-time stubs do not - shipping a payload built against 22H2 SSNs to a 24H2 target gives `STATUS_INVALID_SYSTEM_SERVICE`. SysWhispers3 partially mitigates with multi-build tables and a runtime lookup against `NtCurrentPeb()->OSBuildNumber`, but the table must contain every target build at build time.

## Defensive baseline

- **Kernel callbacks** (`PsSetCreateProcessNotifyRoutineEx`, `PsSetCreateThreadNotifyRoutine`, `ObRegisterCallbacks`, `CmRegisterCallbackEx`) fire regardless of how the syscall was issued - userland Gate tricks do not bypass them. This is the EDR's real moat.
- **ETW-TI (Threat-Intelligence) provider** (`Microsoft-Windows-Threat-Intelligence`, secure-kernel sourced) emits events for the syscall-of-interest such as `NtProtectVirtualMemory` on RX pages, regardless of how the call entered. See [[etw-tampering-deep]] - userland ETW tampering does not stop ETW-TI.
- **Stack walking on syscall entry**: some EDRs validate that the return-after-syscall address is inside `ntdll` (via the kernel-mode return-address). Indirect-syscall variants try to satisfy this; naive direct-syscall payloads do not.
- **Static signatures**: the Gate code itself is highly signaturable - the export-walking loop, the `mov eax` byte probe, and SysWhispers' stub layout are well covered by AV signatures. Practitioners typically obfuscate via name hashing, string encryption, and inlining.
- **Microsoft Defender hardware-stack-protection / CET / Shadow Stack** can catch some Gate variants that abuse ROP-like control flow, particularly indirect-syscall jumpers that pivot through `ntdll` gadgets.
- **VBS / HVCI** does not directly stop Gate techniques, but it raises the cost of any kernel-mode follow-on stage that the userland Gate is bootstrapping. A direct syscall to `NtCreateThreadEx` still works; loading an unsigned driver afterwards does not.
- **Defender's "ASR" rules**, particularly "Block process creations originating from PSExec and WMI commands" and "Block credential stealing from LSASS", fire on the *intent* (the parameters to `NtOpenProcess` against `lsass.exe`) regardless of syscall path - a Gate alone does not get you LSASS.
- **Anti-cheat-grade memory scanning** (Vanguard, BattlEye, EAC) and increasingly some EDRs periodically rescan `.text` pages of running processes for known stub patterns. The countermeasure on the offensive side is to allocate the syscall stubs in a freshly-mapped private page and free them after each call - but that itself is a strong signal.

## Workflow to study

1. Lab: Windows 11 24H2 VM + WinDbg + a known-clean `ntdll`. Use `!chkimg ntdll` after attaching to confirm.
2. Read 10 `Nt*` exports' first 32 bytes; observe the clean prologue and `mov eax, <ssn>`.
3. Install an EDR-style hook by hand: `VirtualProtect` `NtOpenProcess` to RWX, write a 5-byte `jmp` at the start. Re-extract SSN with Hells Gate - watch it return garbage.
4. Implement Halos Gate: walk +/- 32 bytes; show recovery.
5. Implement the same payload with SysWhispers3 generated stubs and confirm the binary string `mov eax, 0x26` is present in your `.text`.
6. Try Phantom: sort the export RVAs, derive SSN by index; compare against the ground-truth from a clean run.
7. Submit each payload to a controlled detonation lab (your own ELAM-less VM) with a representative EDR trial and compare alerts. Re-run with indirect syscalls.
8. Cross-reference: see [[edr-hooks-and-unhooking]] for the unhook-then-call alternative, and [[amsi-memory-patching-deep]] / [[etw-tampering-deep]] for the in-process patching counterparts.

## Honest tradeoffs

- A Gate is a *technique*, not a payload. By the time you have direct syscalls to `NtAllocateVirtualMemory` / `NtProtectVirtualMemory` / `NtCreateThreadEx`, you still need to solve loader emulation, sleep masking, callback evasion, and parent-process spoofing. See [[process-injection-techniques]] and [[parent-pid-spoofing]] for the rest of the chain.
- A Gate by itself does not stop kernel-side telemetry. If your goal is LSASS access, the ETW-TI provider will alert regardless of how the syscall entered. The Gate buys you userland silence and nothing else.
- Modern EDR detection has shifted toward in-kernel callbacks and ETW-TI precisely because vendors recognised that userland hooks are a porous boundary. Treat any Gate result on a current EDR build as a hint that the vendor decided the userland fight wasn't worth it - not necessarily that you are stealthy.

## Comparison table (quick reference)

| Technique | When SSN resolved | Survives prologue hook | Survives split hook | Static signature |
| --- | --- | --- | --- | --- |
| Hard-coded | Compile | n/a | n/a | very low |
| Hells Gate | Runtime | No | Partly | medium |
| Halos Gate | Runtime | Yes | Partly | medium |
| Tartarus Gate | Runtime | Yes | Yes | medium-high |
| FreshyCalls / SysWhispers | Compile | n/a | n/a | high (well known) |
| Phantom (sorted) | Runtime | Yes | Yes | low-medium |

## Related

- [[syscall-direct-and-indirect]]
- [[edr-hooks-and-unhooking]]
- [[edr-bypass-at-exploitation-time]]
- [[amsi-memory-patching-deep]]
- [[etw-tampering-deep]]
- [[process-injection-techniques]]
- [[osep-roadmap]]

## References

- https://www.sektor7.net/blog (Reenz0h / Halos Gate writeups)
- https://github.com/am0nsec/HellsGate
- https://github.com/trickster0/TartarusGate
- https://github.com/klezVirus/SysWhispers3
- https://outflank.nl/blog/2019/06/19/red-team-tactics-combining-direct-system-calls-and-srdi-to-bypass-av-edr/
- https://www.crowdstrike.com/blog/tech-center/hooking-and-unhooking/
