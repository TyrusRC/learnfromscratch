---
title: EDR hooks and unhooking
slug: edr-hooks-and-unhooking
---

> **TL;DR:** EDRs JMP-trampoline the first bytes of sensitive ntdll functions to a userland inspection routine — restore the original bytes from a fresh disk copy and the trampoline is gone, but the EDR can still see you via kernel callbacks and ETW-TI.

## What it is
Most commercial endpoint products install inline hooks on `ntdll.dll` (some also on `kernel32`, `kernelbase`, `wininet`) in every process they monitor. The hook replaces the first 5-15 bytes of a target like `NtAllocateVirtualMemory` with a `JMP` to the EDR's DLL, which inspects arguments, decides allow/deny/telemetry, then jumps back. Unhooking is rewriting those bytes back to what the DLL has on disk.

## Preconditions / where it applies
- Code execution inside a process the EDR injected its DLL into (typically all userland processes)
- Read access to your own process memory and write access via VirtualProtect
- Targets: `NtAllocateVirtualMemory`, `NtProtectVirtualMemory`, `NtWriteVirtualMemory`, `NtCreateThreadEx`, `NtMapViewOfSection`, `NtQueueApcThread`, `NtCreateUserProcess`, `LdrLoadDll`, `AmsiScanBuffer`

## Technique
**Detect the hook.** Compare bytes at function entry to a fresh disk-loaded `ntdll`. If they differ in the first 5 bytes, you're hooked.

**Unhook by overwrite.** Map `ntdll.dll` from disk as a section (or read raw), find the `.text` section offset, copy the clean bytes back into the live in-memory DLL. Tools: Perun's Fart pattern, or manually via `NtCreateSection` on the disk file then `NtMapViewOfSection`.

When reading the clean copy straight off disk, the byte offset you want is the function's export RVA — because the file is not yet relocated/mapped, the file-offset equals the RVA, so you can `ReadFile` directly to the function prologue without rebuilding section headers. A common OPSEC slip is unhooking only one or two hot syscalls (e.g. just `NtAllocateVirtualMemory`); the EDR's correlation engine then sees a *partial* hook table, which is itself a strong anomaly. Either restore the whole `.text` in one pass or leave the hooks intact and pivot to indirect syscalls.

```c
HMODULE clean = LoadLibraryEx(L"ntdll.dll", NULL, DONT_RESOLVE_DLL_REFERENCES);
// or map from \KnownDlls\ntdll.dll, which is the pre-modification copy
// then memcpy section .text from clean -> live ntdll
```

**Avoid hooking altogether.** Direct syscalls (Hell's Gate / Halo's Gate to resolve SSNs at runtime) bypass userland hooks entirely. Indirect syscalls (Tartarus Gate, SysWhispers3) jump into ntdll at a `syscall;ret` gadget so the call stack looks legitimate — defeats kernel-side stack-walk checks like ETW Threat Intelligence.

**Hardware-breakpoint hijack.** Set Dr0-Dr3 on the hook function, install a vectored exception handler that fixes up RIP past the JMP. No memory writes, no module tampering.

## Detection and defence
- Kernel callbacks (`PsSetCreateProcessNotifyRoutineEx`, `PsSetCreateThreadNotifyRoutine`, `PsSetLoadImageNotifyRoutine`, `CmRegisterCallbackEx`) — userland unhooking does nothing about these
- ETW Threat Intelligence channel emits events from the kernel for syscalls like `NtAllocateVirtualMemory` with RWX, `NtProtectVirtualMemory` RX→RWX flips
- Mature EDRs reinstall hooks after detecting tampering, or simply mark the process as suspicious and snapshot memory
- Defenders should treat hook tampering itself as a high-severity signal — almost nothing legitimate restores `.text` of ntdll
- Stack-walking on syscall entry catches direct syscalls (return address is inside your shellcode, not inside ntdll)

## References
- [@am0nsec — Hell's Gate](https://github.com/am0nsec/HellsGate) — original syscall-resolution at runtime
- [klezVirus — SysWhispers3](https://github.com/klezVirus/SysWhispers3) — indirect syscalls with stack spoofing
- [MDSec — Bypassing User-Mode Hooks](https://www.mdsec.co.uk/2020/12/bypassing-user-mode-hooks-and-direct-invocation-of-system-calls-for-red-teams/) — analysis of unhooking patterns
- [ired.team — Full DLL unhooking with C++](https://www.ired.team/offensive-security/defense-evasion/how-to-unhook-a-dll-using-c++) — walk-through of mapping clean ntdll from disk and copy-back patterns
- [[syscall-direct-and-indirect]] [[amsi-bypass]] [[etw-bypass]]
