---
title: Parent PID spoofing
slug: parent-pid-spoofing
---

> **TL;DR:** `UpdateProcThreadAttribute` with `PROC_THREAD_ATTRIBUTE_PARENT_PROCESS` lets you choose any process you can open as the parent of the child you launch — useful to evade parent/child anomaly detection.

## What it is
Windows lets `CreateProcess` accept a `STARTUPINFOEX` with thread attributes that override default behaviour. One attribute, `PROC_THREAD_ATTRIBUTE_PARENT_PROCESS`, sets the new process's parent to an arbitrary handle. EDR rules that say "powershell.exe spawned from winword.exe is bad" can be sidestepped by parenting under explorer.exe or svchost.exe instead.

## Preconditions / where it applies
- Privilege to `OpenProcess` the chosen parent with `PROCESS_CREATE_PROCESS` (often requires same integrity level, sometimes higher privilege)
- Local code execution as a user
- Most useful when a detection rule keys off parent/child pair specifically

## Technique
Minimal C:

```c
STARTUPINFOEXA si = { sizeof(si) };
PROCESS_INFORMATION pi = { 0 };
SIZE_T sz = 0;
InitializeProcThreadAttributeList(NULL, 1, 0, &sz);
si.lpAttributeList = (LPPROC_THREAD_ATTRIBUTE_LIST)HeapAlloc(GetProcessHeap(), 0, sz);
InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &sz);

HANDLE hParent = OpenProcess(PROCESS_CREATE_PROCESS, FALSE, target_pid);
UpdateProcThreadAttribute(si.lpAttributeList, 0,
    PROC_THREAD_ATTRIBUTE_PARENT_PROCESS, &hParent, sizeof(HANDLE), NULL, NULL);

CreateProcessA(NULL, "cmd.exe /c whoami", NULL, NULL, FALSE,
    EXTENDED_STARTUPINFO_PRESENT, NULL, NULL, &si.StartupInfo, &pi);
```

The new `cmd.exe` will have its `InheritedFromUniqueProcessId` set to `target_pid`. Process Explorer, Sysmon Event 1, and EDR process trees all show the spoofed parent.

Watch-outs:
- Token still comes from the calling process unless you explicitly do CreateProcessAsUser/WithToken — so `cmd.exe` runs as your user, not as the parent's user
- Sysmon Event 1 includes the *real* creator under `ParentProcessGuid` reconciliation in newer Sysmon versions and via the `OriginalProcessId` field in some EDR sensors
- Choosing a parent at a higher integrity level requires SeDebugPrivilege

**Common parents to spoof:** `explorer.exe`, `svchost.exe`, `lsass.exe` (for SYSTEM), `MsMpEng.exe` for irony.

**Combine with command-line spoofing.** Allocate a PEB, overwrite `RTL_USER_PROCESS_PARAMETERS->CommandLine` after creation but before resume, so process arguments differ from the recorded creation arguments. Some EDRs only log creation-time argv and miss the swap; modern ones use ETW-TI and see both.

## Detection and defence
- Sysmon EID 1 with mismatch between `ParentProcessGuid` lineage and the calling thread's actual GUID
- ETW Threat Intelligence emits `EVENT_TRACE_KERNEL_AUDIT_PROCESS_OBJECT` with the true creator PID
- Defenders should alert on process creations where `CreatingProcessId != ParentProcessId` (visible via ETW-TI, not Sysmon-only)
- Token-mismatch heuristics: child token user differs from claimed parent's owner

## References
- [Microsoft Docs — UpdateProcThreadAttribute](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute) — official API reference
- [ired.team — PPID spoofing](https://www.ired.team/offensive-security/defense-evasion/parent-process-id-ppid-spoofing) — code samples
- [WithSecure Labs](https://labs.withsecure.com/) — detection research on PPID spoofing
- [[edr-hooks-and-unhooking]] [[opsec-fundamentals]]
