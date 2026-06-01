---
title: Anti-Debugging on Windows
slug: anti-debugging-windows
---

> **TL;DR:** Read `PEB.BeingDebugged`, `PEB.NtGlobalFlag`, ask `NtQueryInformationProcess` about your own debug port, and bail early from a TLS callback — the standard battery of cheap user-mode anti-debug checks.

## What it is
Anti-debugging code lives inside a payload to detect whether it is being interactively reverse-engineered (WinDbg, x64dbg, IDA) and alter behaviour — exit, sleep, decoy, or self-destruct. None of these tricks defeat a determined analyst, but in aggregate they slow triage and break unattended sandboxes. The four classics are: the documented `IsDebuggerPresent` API, the direct `PEB->BeingDebugged` byte it reads, the `NtGlobalFlag` heap-flag side effect, and `NtQueryInformationProcess` queries for `ProcessDebugPort`, `ProcessDebugObjectHandle`, and `ProcessDebugFlags`.

## Preconditions / where it applies
- Pure user-mode; no privileges required
- Works against ring-3 debuggers (OllyDbg, x64dbg, WinDbg user); kernel debuggers (KD) need different checks (`KdDebuggerEnabled`, `SharedUserData`)
- Trivially bypassed by anyone who patches the PEB or sets a conditional breakpoint after the checks — value is in stacking many

## Technique
TLS callbacks fire before `main`, so place checks there to catch analysts who break on the entry point. Hand-inlined PEB access avoids the obvious `IsDebuggerPresent` import.

```c
// PEB walk — no imports, no signature
#ifdef _WIN64
  PPEB peb = (PPEB)__readgsqword(0x60);
#else
  PPEB peb = (PPEB)__readfsdword(0x30);
#endif
if (peb->BeingDebugged) ExitProcess(0);

// NtGlobalFlag heap flags set by loader under a debugger
DWORD ngf = *(DWORD*)((BYTE*)peb + (sizeof(void*) == 8 ? 0xBC : 0x68));
if (ngf & (FLG_HEAP_ENABLE_TAIL_CHECK
         | FLG_HEAP_ENABLE_FREE_CHECK
         | FLG_HEAP_VALIDATE_PARAMETERS)) ExitProcess(0);

// NtQueryInformationProcess — ProcessDebugPort == 0x7
DWORD_PTR port = 0;
NtQueryInformationProcess(GetCurrentProcess(), 7, &port, sizeof port, NULL);
if (port) ExitProcess(0);
```

Stack timing checks (`rdtsc` before/after a no-op, `QueryPerformanceCounter`), `OutputDebugString` + `GetLastError`, and parent-process / loaded-module enumeration (looking for `dbghelp.dll`, `ScyllaHide`) for diminishing returns. Combine with [[amsi-bypass]] and [[etw-bypass]] in a hardened loader.

## Detection and defence
- For defenders: signature on the PEB-offset constants (`0x60`/`0x30`, `0xBC`/`0x68`) and on direct `NtQueryInformationProcess(7|0x1F)` calls
- ETW provider `Microsoft-Windows-Threat-Intelligence` surfaces process-debug-port queries to EDR
- Counter-tooling: ScyllaHide, TitanHide, x64dbg's anti-anti-debug plugin patch the PEB bytes back to zero on the fly
- Sandbox vendors normalise these fields, so anti-debug tuned only at PEB usually fails to detect modern sandboxes

## References
- [Check Point — Anti-Debug Tricks](https://anti-debug.checkpoint.com/techniques/debug-flags.html) — exhaustive catalogue of flags-based checks
- [Apriorit — Anti-Reverse Engineering Protection Techniques](https://www.apriorit.com/dev-blog/367-anti-reverse-engineering-protection-techniques-to-use-before-releasing-software) — TLS callbacks, NtQueryInformationProcess, timing
