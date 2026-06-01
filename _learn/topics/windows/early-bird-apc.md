---
title: Early Bird APC Injection
slug: early-bird-apc
---

> **TL;DR:** Queue a user-mode APC pointing at shellcode against the primary thread of a freshly-created suspended process, then `ResumeThread` so execution happens before most EDR hooks load.

## What it is
An [[process-injection-techniques|injection]] variant that abuses `QueueUserAPC` against the main thread of a process spawned with `CREATE_SUSPENDED`. Because the APC fires the moment the thread starts, the payload runs inside `ntdll!LdrInitializeThunk` — earlier than most in-process userland hooks (DLL load notifications, IAT patches) installed by EDR sensors, so calls like `CreateProcess`, `VirtualAllocEx`, `WriteProcessMemory` go un-intercepted in the child.

## Preconditions / where it applies
- Local execution as the same or lower integrity level as the sacrificial process owner
- Ability to spawn a Win32 GUI/console child (`calc.exe`, `notepad.exe`)
- Windows 7+; technique survives on Windows 11 but is increasingly flagged by behavioural ML

## Technique
Create a suspended process, allocate `PAGE_EXECUTE_READWRITE` memory in it, write shellcode, queue an APC at the shellcode address against the suspended primary thread, then resume.

```c
CreateProcessA(NULL, "C:\\Windows\\System32\\calc.exe", NULL, NULL, FALSE,
               CREATE_SUSPENDED, NULL, NULL, &si, &pi);
LPVOID rmem = VirtualAllocEx(pi.hProcess, NULL, sizeof shellcode,
                             MEM_COMMIT, PAGE_EXECUTE_READWRITE);
WriteProcessMemory(pi.hProcess, rmem, shellcode, sizeof shellcode, NULL);
QueueUserAPC((PAPCFUNC)rmem, pi.hThread, 0);
ResumeThread(pi.hThread);
```

OPSEC: pair with [[parent-pid-spoofing]] so the sacrificial process inherits a benign PPID, and prefer `NtQueueApcThread` to skip Win32 wrappers. RWX allocation is the loudest signal — switch to RW → RX with `VirtualProtectEx` for a quieter footprint.

## Detection and defence
- Sysmon Event ID 8 (`CreateRemoteThread`-style cross-process activity) and EID 10 (`ProcessAccess`) with `GrantedAccess` containing `0x1F0FFF`
- ETW `Microsoft-Windows-Threat-Intelligence` surfaces `NtQueueApcThread` cross-process calls
- EDRs that hook in the kernel (PsSetCreateProcessNotifyRoutineEx, `Ob` callbacks) catch the suspended-child + RWX allocation pattern regardless of userland evasion

## References
- [ired.team — Early Bird APC Queue Code Injection](https://www.ired.team/offensive-security/code-injection-process-injection/early-bird-apc-queue-code-injection) — original walkthrough
- [MITRE ATT&CK T1055.004](https://attack.mitre.org/techniques/T1055/004/) — Asynchronous Procedure Call sub-technique
