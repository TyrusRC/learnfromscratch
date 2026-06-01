---
title: Thread Hijacking
slug: thread-hijacking
---

> **TL;DR:** Suspend an existing thread in a target process, point its `RIP` at injected shellcode via `SetThreadContext`, then resume — code runs under a legitimate thread with no `CreateRemoteThread` telemetry.

## What it is
A classic remote code-injection primitive that avoids `CreateRemoteThread`/`NtCreateThreadEx` (the calls every behavioural EDR watches). Instead of spawning a new thread, the attacker enumerates an existing thread, suspends it, rewrites the instruction pointer to the address of shellcode previously written via `WriteProcessMemory`, then resumes the thread. Execution looks like it originated from the victim process's own thread.

## Preconditions / where it applies
- Handle to the target process and thread with `PROCESS_VM_OPERATION | PROCESS_VM_WRITE | THREAD_SUSPEND_RESUME | THREAD_GET_CONTEXT | THREAD_SET_CONTEXT`
- Same integrity level (or SeDebugPrivilege — see [[tokens-and-privileges]])
- Target process must have at least one thread the attacker can safely hijack (avoid GUI threads of foreground apps)

## Technique
Enumerate threads with `CreateToolhelp32Snapshot` / `Thread32Next`, open one with `OpenThread`, allocate `PAGE_EXECUTE_READ` memory in the remote process, write the shellcode, then swap `Rip` and resume. Cleanly returning to original execution requires saving the stolen context or appending a small stub that restores it.

```c
hProc  = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
buf    = VirtualAllocEx(hProc, NULL, sizeof(sc), MEM_COMMIT, PAGE_EXECUTE_READWRITE);
WriteProcessMemory(hProc, buf, sc, sizeof(sc), NULL);
hThr   = OpenThread(THREAD_ALL_ACCESS, FALSE, tid);
SuspendThread(hThr);
CONTEXT ctx = { .ContextFlags = CONTEXT_FULL };
GetThreadContext(hThr, &ctx);
ctx.Rip = (DWORD64)buf;
SetThreadContext(hThr, &ctx);
ResumeThread(hThr);
```

OPSEC: allocate the buffer as `PAGE_READWRITE` first and re-protect to `PAGE_EXECUTE_READ` via `VirtualProtectEx` to dodge `RWX` heuristics. Picking a worker thread of `svchost.exe` is noisier than reusing a thread the attacker already controls — see [[process-injection-techniques]] and [[parent-pid-spoofing]] for related primitives.

## Detection and defence
- Sysmon Event ID 8 (`CreateRemoteThread`) does *not* fire — but ID 10 (`ProcessAccess`) with `0x1F1FFF` or `THREAD_SET_CONTEXT` calls flag this
- ETW `Microsoft-Windows-Threat-Intelligence` provider raises `EtwThreatIntProvRegPS` events on `NtSetContextThread` into another process
- EDRs hook `NtGetContextThread`/`NtSetContextThread`; consider this when planning [[etw-bypass]] or syscall stubs
- Tools like `Get-InjectedThread` (Sela) detect threads whose start address is unbacked memory

## References
- [ired.team — Injecting to Remote Process via Thread Hijacking](https://www.ired.team/offensive-security/code-injection-process-injection/injecting-to-remote-process-via-thread-hijacking) — original walkthrough
- [Elastic — Hunting for Suspicious Windows Libraries](https://www.elastic.co/security-labs/hunting-for-suspicious-windows-libraries-for-execution-and-defense-evasion) — detection of unbacked-thread execution
- [MITRE ATT&CK T1055.003](https://attack.mitre.org/techniques/T1055/003/) — Thread Execution Hijacking
