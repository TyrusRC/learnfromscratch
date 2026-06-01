---
title: Processes and threads
slug: windows-processes-and-threads
---

> **TL;DR:** A process is the address-space + handle-table container; threads are the schedulable execution units inside it. The PEB (per process) and TEB (per thread) sit at fixed gs-relative offsets and are the entry point for shellcode that needs to find loaded modules, environment, command line, or the current TIB without imports.

## What it is
Windows separates the kernel `EPROCESS`/`ETHREAD` objects from their user-mode mirrors, the PEB and TEB. The PEB (Process Environment Block) holds loaded module lists, the process command line, the image base, and `BeingDebugged`. The TEB (Thread Environment Block) holds the SEH chain, the stack base/limit, the TLS slots, and a pointer back to the PEB. Both are reachable without API calls: on x64, `gs:[0x60]` is the PEB and `gs:[0x30]` is the TEB. This makes them load-bearing for position-independent shellcode and for [[pe-format]]-aware loaders.

## Preconditions / where it applies
- Writing shellcode or a manual-map loader that cannot import anything
- Anti-debug / anti-analysis checks (read `PEB.BeingDebugged`, `NtGlobalFlag`, `ProcessHeap.Flags`)
- Process-injection tradecraft — every variant ends in a thread (real, hijacked, fiber, APC) executing your code
- EDR evasion that walks `PEB_LDR_DATA.InLoadOrderModuleList` to resolve API addresses ([[windows-api-and-syscalls]])

## Technique
PEB walk to find a loaded module and an export, in pseudo-asm (x64):

```nasm
mov rax, gs:[0x60]              ; PEB
mov rax, [rax + 0x18]           ; PEB.Ldr
mov rax, [rax + 0x20]           ; InMemoryOrderModuleList.Flink
; iterate LIST_ENTRY ; each entry - 0x10 == LDR_DATA_TABLE_ENTRY
; compare BaseDllName (UNICODE_STRING) against hash of "kernel32.dll"
```

Then parse the matched module's EAT to resolve `LoadLibraryA` / `GetProcAddress` and bootstrap everything else without imports.

Injection primitives that touch the process/thread model:

- **CreateRemoteThread / NtCreateThreadEx** — classic; heavily monitored
- **QueueUserAPC** to an alerting thread — needs an alertable target thread (`SleepEx`, `WaitFor*Ex`)
- **Thread hijack** — `OpenThread` + `SuspendThread` + `GetThreadContext` + patch `Rip` + `SetThreadContext` + `ResumeThread`
- **Process Hollowing** — `CreateProcess(SUSPENDED)` → unmap original image → write new image → `SetThreadContext` to new entry → `ResumeThread`
- **PPID spoof** + **mitigation policy** — `UpdateProcThreadAttribute` with `PROC_THREAD_ATTRIBUTE_PARENT_PROCESS` to fake parent; combine with `BlockNonMicrosoftBinaries` to disable third-party DLLs from loading (useful against AV DLLs that inject via AppInit)
- **Fibers / Early Bird / Ekko sleep obfuscation** — manipulating thread schedule for evasion

Useful anti-debug fields:

- `PEB.BeingDebugged` — set by `NtCreateUserProcess` when a debugger is attached
- `PEB.NtGlobalFlag` — `0x70` when started under a debugger (FLG_HEAP_*)
- `TEB.NtTib.ArbitraryUserPointer` — historical anti-attach signal

From the kernel side (`!process 0 0` in WinDbg), `EPROCESS` holds the token pointer (`Token`), the VadRoot (address-space VADs), and the `Pcb` (KPROCESS). Token swapping — copy `EPROCESS->Token` from a SYSTEM process into your own — is the canonical kernel-mode privilege escalation primitive (used by BYOVD chains, see [[tokens-and-privileges]] and loldrivers.io).

## Detection and defence
- EDRs hook or use kernel callbacks for `NtCreateThreadEx`, `NtMapViewOfSection`, `NtWriteVirtualMemory`, `NtProtectVirtualMemory` — most injections trip one
- `PsSetCreateProcessNotifyRoutineEx` gives kernel callbacks even when ntdll is bypassed
- Process-creation events (4688 / Sysmon 1) with mismatched parent/child and command-line anomalies catch PPID spoof when parent-image is logged from kernel rather than process token
- Pageguard / Memory scanning detects unbacked RX regions from hollowing or manual map
- Hardening: HVCI/VBS for kernel; CFG and CET for userland; Microsoft-only binaries mitigation in critical processes

## References
- [Microsoft — Process Environment Block](https://learn.microsoft.com/en-us/windows/win32/api/winternl/ns-winternl-peb) — semi-official PEB layout
- [HackTricks — process injection](https://book.hacktricks.wiki/en/windows-hardening/basic-powershell-for-pentesters/index.html) — injection primer
- [ired.team — Windows internals & injection](https://www.ired.team/offensive-security/code-injection-process-injection) — collected technique writeups
