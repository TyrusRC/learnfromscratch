---
title: Direct and indirect syscalls
slug: syscall-direct-and-indirect
---

> **TL;DR:** Direct syscall = your code's `syscall` instruction (skips ntdll hooks but breaks stack-walking checks). Indirect syscall = your code jumps to a real `syscall;ret` gadget inside ntdll so the stack looks legitimate. Indirect won.

## What it is
Windows system calls are exposed via stub functions in `ntdll.dll`: each NT API loads a Syscall Service Number (SSN) into `eax` and executes `syscall`. EDRs hook these stubs to intercept. "Direct syscalls" means writing your own `syscall` instruction in your code and calling it after loading the SSN. "Indirect syscalls" means resolving the address of the actual `syscall;ret` instructions *inside ntdll* and jumping there, so call-stack analysis still sees ntdll on top.

## Preconditions / where it applies
- You need an SSN for the function you want — and SSNs change between Windows builds
- Effective against userland-hook EDRs; less effective against kernel-callback or stack-walking EDRs that compare return address against ntdll's `.text` range

## Technique
**SSN resolution.**
- *Hell's Gate:* parse ntdll exports, read the first 4 bytes of each function — they encode `mov eax, <SSN>` when ntdll is unhooked.
- *Halo's Gate:* if the function is hooked (first bytes are a JMP), walk neighbours up and down — adjacent functions have SSN ± 1.
- *Tartarus Gate:* extends Halo's to handle multiple hooked neighbours.
- *Syscalls table from disk:* read a fresh ntdll copy from disk, parse SSNs from its `.text`.

**Direct syscall.**

```asm
; HellDescent.asm
NtAllocateVirtualMemory PROC
    mov r10, rcx
    mov eax, 18h        ; SSN — varies by Windows build
    syscall
    ret
NtAllocateVirtualMemory ENDP
```

When the kernel returns, the `RIP` you came from is inside your shellcode — easy to fingerprint via stack walk in ETW-TI.

**Indirect syscall.**

```asm
; SysWhispers3-style
NtAllocateVirtualMemory PROC
    mov r10, rcx
    mov eax, 18h
    jmp qword ptr [rip + syscall_addr]   ; jumps to syscall;ret inside ntdll
    ret
NtAllocateVirtualMemory ENDP
```

`syscall_addr` is resolved at runtime to the address of a `syscall;ret` gadget inside ntdll's `.text`. When the kernel returns, `RIP` is inside ntdll — stack walk sees legitimate caller.

Toolchains: SysWhispers2 (direct), SysWhispers3 (indirect + egg hunting + jumper to random ntdll syscall addresses for variety), Hell's Hall, FreshyCalls.

**Build-side gotchas.** In Visual Studio you need to enable the *Microsoft Macro Assembler* under Build Customizations and rename the `.asm` so it does not collide with the C++ object name, otherwise MASM silently drops the syscall stub. Decorate the prototype with `EXTERN_C` so the linker matches the unmangled symbol to the `PROC`, and remember syscall numbers are per-build: a stub hardcoded for 22H2 will return `STATUS_INVALID_SYSTEM_SERVICE` on 23H2 and surface as a noisy crash rather than a silent miss. Resolving SSNs dynamically (Hell's/Halo's gate) avoids this entirely.

**Stack spoofing.** Indirect syscall alone isn't enough if ETW-TI walks the *entire* stack. Combine with return-address spoofing (push fake frames pointing inside legitimate modules) so the whole stack passes inspection.

## Detection and defence
- Kernel ETW-TI walks the user-mode stack on syscall entry — direct syscalls fail this check
- PE-sieve / Moneta / HollowsHunter detect unbacked executable memory regions where direct syscalls live
- Kernel callbacks (`PsSetCreateProcessNotifyRoutineEx`, etc.) see effects of the syscall regardless of how you invoked it
- Defenders should monitor for syscalls originating outside ntdll's `.text` range — high-confidence signal
- Stack-walk + module range check is now the standard detection; indirect syscalls + spoofed stack are the standard answer

## References
- [@am0nsec — Hell's Gate](https://github.com/am0nsec/HellsGate) — original technique
- [klezVirus — SysWhispers3](https://github.com/klezVirus/SysWhispers3) — indirect syscalls + jumpers
- [MDSec — Resolving SSNs via the exception directory](https://www.mdsec.co.uk/2022/04/resolving-system-service-numbers-using-the-exception-directory/) — SSN resolution research
- [ired.team — Calling syscalls directly from Visual Studio](https://www.ired.team/offensive-security/defense-evasion/using-syscalls-directly-from-visual-studio-to-bypass-avs-edrs) — MASM build-customisation walkthrough and minimal `NtCreateFile` stub
- [[edr-hooks-and-unhooking]] [[amsi-bypass]] [[etw-bypass]]
