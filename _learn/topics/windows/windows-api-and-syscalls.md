---
title: Win32 / Nt / Zw
slug: windows-api-and-syscalls
---

> **TL;DR:** Windows exposes a layered API: documented Win32 (`kernel32.dll`, `advapi32.dll`) → forwarded into `kernelbase.dll` → semi-documented `Nt*`/`Zw*` stubs in `ntdll.dll` → a `syscall` instruction that traps into the kernel. EDR userland hooks live inside ntdll, so direct/indirect syscalls bypass them by going around the hook.

## What it is
Every documented call (`CreateFileW`, `VirtualAllocEx`, `OpenProcess`) eventually reaches a thin assembly stub in `ntdll.dll` that loads a System Service Number (SSN) into `eax`, executes `syscall`, and returns. The `Nt*` and `Zw*` names point to the same stubs from user mode — they only differ once inside the kernel. Userland EDR hooks rewrite the first bytes of these ntdll stubs to redirect into a telemetry shim before the real `syscall`. Knowing this layer cake is the foundation of EVERY modern evasion technique on Windows.

## Preconditions / where it applies
- Any time you write a custom loader/injector and want to avoid `kernel32!CreateRemoteThread` / `ntdll!NtCreateThreadEx` userland hooks
- Reflective DLL or position-independent shellcode that cannot rely on import resolution at link time
- Malware analysis — recognising which API layer is being called clarifies what is intentional vs hooked
- Pairs with [[pe-format]] (PEB walking, EAT parsing) and [[windows-processes-and-threads]] (thread context)

## Technique
Find the SSN — three common approaches:

1. **Static map** (Hell's Gate / Halo's Gate): walk the EAT of `ntdll.dll`, find each `Nt*` export, parse the first bytes of the stub. Unhooked stub: `4C 8B D1 B8 ?? ?? 00 00` — bytes 4-7 are the SSN. If hooked (first byte `e9` jmp), walk neighbouring exports whose SSN is known and infer by ordinal (Halo's Gate).
2. **Fresh ntdll** (Perun's Fart / refreshing): map `\KnownDlls\ntdll.dll` or read from disk into your own memory and parse SSNs from there — bypasses runtime hooks entirely. The disk-read variant is concrete and minimal: `CreateFileA("C:\\Windows\\System32\\ntdll.dll", GENERIC_READ, FILE_SHARE_READ, ...)` → `ReadFile` into heap → parse `.text`/`.rdata` to locate the export by name → copy out the 23-byte stub starting `4C 8B D1 B8 <SSN-LE> 00 00`, mark it `PAGE_EXECUTE_READWRITE` with `VirtualProtect`, then invoke via a typed function pointer. EDRs that only hook the in-memory ntdll never see the syscall because it never traverses the hooked stub.
3. **Syswhispers3** code-gen: produces per-Windows-build stubs with hardcoded SSNs at compile time.

Direct syscall — execute `syscall` from your own `.text`:

```nasm
NtAllocateVirtualMemory:
    mov  r10, rcx
    mov  eax, <SSN>
    syscall
    ret
```

This bypasses ntdll-resident hooks. Modern EDRs counter with Event Tracing for Windows (ETW Threat Intelligence) and kernel callbacks, plus they flag `syscall` instructions outside ntdll's `.text`.

Indirect syscall — keep the `syscall` instruction inside ntdll. Locate any unhooked `syscall; ret` gadget in ntdll, then `jmp` to it after loading `eax`/`r10`. Call-stack walkers now see a return into ntdll, restoring the appearance of legitimacy.

`Nt` vs `Zw` from user mode: identical. From kernel mode, `Zw` sets previous mode to Kernel (skipping argument probing) and `Nt` preserves user-mode previous mode — important when writing drivers, irrelevant in userland shellcode.

## Detection and defence
- EDRs inspect call stacks at syscall time (ETW-TI `NtTrace` / Threat-Intelligence provider) and flag user-region `syscall` instructions
- Kernel callbacks (`PsSetCreateProcessNotifyRoutineEx`, `ObRegisterCallbacks`) catch object-creation telemetry even when ntdll is bypassed
- Hardware-enforced Stack Protection (CET shadow stacks) breaks naive return-address spoofing
- Memory scanning for unbacked private RX regions catches both manual-mapped loaders and stomped modules
- Hunting: stub-byte hash of `ntdll.dll` `Nt*` exports vs the on-disk file detects ETW patching / unhooking

## References
- [Microsoft — Calling conventions / syscall ABI](https://learn.microsoft.com/en-us/cpp/build/x64-calling-convention) — register usage for `syscall`
- [j00ru — Windows X86-64 system call table](https://j00ru.vexillium.org/syscalls/nt/64/) — historical SSN reference
- [SafeBreach — Hell's Gate paper](https://github.com/am0nsec/HellsGate) — dynamic SSN resolution primer
- [ired.team — Retrieving ntdll Syscall Stubs from Disk at Run-time](https://www.ired.team/offensive-security/defense-evasion/retrieving-ntdll-syscall-stubs-at-run-time) — concrete CreateFile + ReadFile fresh-stub extraction walkthrough
