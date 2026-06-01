---
title: Process injection techniques
slug: process-injection-techniques
---

> **TL;DR:** Get your code into another process — CreateRemoteThread is the textbook version; APC, thread hijacking, section mapping, early-bird, and MockingJay are the evasion-shaped variants.

## What it is
Process injection moves attacker code into another process's address space and executes it there. Reasons: hide in a trusted host, gain that host's token, evade memory scans by living in `explorer.exe`. The choice between techniques is dictated by what API sequence the EDR has hooked.

## Preconditions / where it applies
- Handle to the target process with sufficient rights (`PROCESS_VM_OPERATION`, `PROCESS_VM_WRITE`, `PROCESS_CREATE_THREAD`, etc.)
- Often same-integrity or higher (lower-integrity into higher-integrity is blocked without explicit privileges)
- A target process you want to inhabit (notepad, explorer, msedge, lsass)

## Technique

**Classic CreateRemoteThread.**

```c
HANDLE h = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
LPVOID m = VirtualAllocEx(h, NULL, len, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
WriteProcessMemory(h, m, shellcode, len, NULL);
CreateRemoteThread(h, NULL, 0, m, NULL, 0, NULL);
```

Five hooked APIs. Detected everywhere. Useful only as a baseline.

**Improvements:**
- *VirtualAllocEx(RW) → WriteProcessMemory → VirtualProtectEx(RX)* — never have RWX
- *Section mapping*: `NtCreateSection` + `NtMapViewOfSection` in both processes shares a section, no `WriteProcessMemory` call
- *QueueUserAPC / NtQueueApcThread*: queue an APC on an existing alertable thread instead of CreateRemoteThread
- *Early-bird APC*: `CreateProcess` with `CREATE_SUSPENDED`, queue APC, then `ResumeThread` — APC fires before main thread, before EDR DLL fully initialised in the child
- *Thread hijacking*: `SuspendThread` an existing thread, modify RIP/EIP to point at your shellcode, `ResumeThread`
- *Process Hollowing*: `CreateProcess` suspended, `NtUnmapViewOfSection` of the original image, write your PE, `SetThreadContext`, resume

**Modern variants:**
- *Process Doppelgänging*: TxF transactions to write payload then commit — image-load callbacks see the original file
- *Process Herpaderping*: open file, write payload, create section from file, modify file back to legitimate before image-load callback fires
- *Process Ghosting*: mark file for deletion before mapping; section persists, file is gone
- *MockingJay*: find a target DLL with an RWX section *already* (msys-2.0.dll classically) — write shellcode there, no allocation needed, no protection change
- *Module stomping*: `LoadLibrary` a benign DLL, overwrite its `.text` with shellcode, execute — beats unbacked-memory scanners that only flag non-image regions
- *Phantom DLL Hollowing*: map a real DLL as a section, overwrite the section copy-on-write before execution

**Token + DLL load tricks.**
- `SetThreadContext` + ROP gadgets to call `LoadLibrary` indirectly
- Inject via `RtlCreateUserThread` (older, less-hooked than `CreateRemoteThread`)
- `NtCreateThreadEx` direct syscall avoids userland hooks entirely

## Detection and defence
- ETW-TI kernel events for `VirtualAllocEx`, `WriteProcessMemory`, `SetThreadContext`, `QueueUserAPC` to remote processes
- Memory scanners (Moneta, PE-sieve, HollowsHunter) flag unbacked executable regions and stomped modules
- Kernel callbacks on thread creation: `PsSetCreateThreadNotifyRoutine` — fires even with direct syscalls
- LSASS is now PPL by default on modern Windows — most injection into lsass requires a vulnerable signed driver or specific bypasses
- Defenders should baseline child-process spawn patterns and treat any RWX allocation in a remote process as high signal

## References
- [ired.team — Process Injection](https://www.ired.team/offensive-security/code-injection-process-injection) — code samples for most techniques
- [Elastic Security Labs](https://www.elastic.co/security-labs) — detection-focused process injection series
- [Forrest Orr — DLL Hollowing](https://www.forrest-orr.net/post/malicious-memory-artifacts-part-i-dll-hollowing) — research on unbacked-memory evasion
- [[syscall-direct-and-indirect]] [[edr-hooks-and-unhooking]] [[parent-pid-spoofing]]
