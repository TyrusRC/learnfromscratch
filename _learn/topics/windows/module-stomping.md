---
title: Module Stomping (DLL Hollowing)
slug: module-stomping
---

> **TL;DR:** Force a target process to load a benign signed DLL, then overwrite that DLL's `.text` (typically at `AddressOfEntryPoint`) with shellcode and run it via `CreateRemoteThread` — no `RWX` allocations, execution attributed to a legitimate module.

## What it is
Module stomping (a.k.a. DLL hollowing or module overloading) hides shellcode inside the memory image of an already-mapped, Microsoft-signed DLL. The loader has already done the work — the pages are `RX` and backed by a real on-disk file — so heuristic scanners that look for private `RWX` regions, unbacked executable memory, or DLLs loaded from `%TEMP%` see nothing odd. Only a byte-level comparison against the on-disk image betrays the implant.

## Preconditions / where it applies
- Handle to target with `PROCESS_VM_WRITE | PROCESS_VM_OPERATION | PROCESS_CREATE_THREAD`
- A DLL the target is happy to load (e.g. `amsi.dll`, `windowscodecs.dll`); pick one with a generous `.text` section
- Shellcode that fits inside the stomped section and is position-independent

## Technique
Inject `LoadLibraryW` against the target with a benign module name, locate its `AddressOfEntryPoint` via the in-process PE headers, then `WriteProcessMemory` shellcode over that region and spawn a remote thread starting at the entry point.

```c
// inside target after CreateRemoteThread(LoadLibraryW, "amsi.dll")
HMODULE hMod = GetModuleHandleA("amsi.dll");
PIMAGE_DOS_HEADER dos = (PIMAGE_DOS_HEADER)hMod;
PIMAGE_NT_HEADERS nt  = (PIMAGE_NT_HEADERS)((BYTE*)hMod + dos->e_lfanew);
LPVOID ep = (BYTE*)hMod + nt->OptionalHeader.AddressOfEntryPoint;
WriteProcessMemory(hTarget, ep, shellcode, sizeof(shellcode), NULL);
CreateRemoteThread(hTarget, NULL, 0, (LPTHREAD_START_ROUTINE)ep, NULL, 0, NULL);
```

OPSEC: pages stay `RX`, so `VirtualProtectEx` to `RWX` (the classic Cobalt Strike tell) is unnecessary. Pair with thread-stack spoofing for cleaner stack walks. Avoid stomping DLLs that the host process actually calls into (e.g. `kernel32.dll`).

## Detection and defence
- Moneta / pe-sieve flag modified `.text` pages whose hash diverges from disk
- Sysmon EID 8 (`CreateRemoteThread`) where the start address resolves inside a loaded module but the bytes don't match the on-disk image
- EDR userland hooks on `WriteProcessMemory` targeting executable sections of signed modules

## References
- [ired.team — Module Stomping](https://www.ired.team/offensive-security/code-injection-process-injection/modulestomping-dll-hollowing-shellcode-injection) — original walkthrough
- [Forrest Orr — Masking Malicious Memory Artifacts (Phantom DLL Hollowing)](https://www.forrest-orr.net/post/masking-malicious-memory-artifacts-part-ii-insights-from-moneta) — detection internals

Related: [[process-injection-techniques]], [[amsi-bypass]]
