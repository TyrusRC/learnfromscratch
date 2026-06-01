---
title: Reflective DLL Injection
slug: reflective-dll-injection
---

> **TL;DR:** Inject a DLL into a remote process without ever calling `LoadLibrary` by bundling a PE loader (`ReflectiveLoader`) inside the DLL itself, so the image never touches disk and bypasses image-load callbacks.

## What it is
Reflective DLL injection (Stephen Fewer, 2008) ships a self-loading export named `ReflectiveLoader` inside the DLL. The injector writes the raw DLL bytes into a target process with `VirtualAllocEx`/`WriteProcessMemory` and starts a thread on that export. The loader then parses its own PE headers, resolves `kernel32!LoadLibraryA` / `GetProcAddress` / `VirtualAlloc` via PEB walking, allocates a properly aligned region, maps sections, fixes the IAT, applies relocations, and finally calls `DllMain(DLL_PROCESS_ATTACH)` — all without the OS image loader. See also [[process-injection-techniques]].

## Preconditions / where it applies
- Handle to the target with `PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION`
- Architecture of the DLL must match the target process (x64 vs x86)
- Works on every supported Windows version; defeats user-mode hooks on `LoadLibrary*` but not modern memory-scanning EDR

## Technique
The injector locates the `ReflectiveLoader` RVA by parsing the DLL's export directory, writes the buffer remotely, then spawns a thread at `base + RVA`. The loader is position-independent so it works from any allocation.

```c
// pseudo-injector
HANDLE h = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
LPVOID rmt = VirtualAllocEx(h, NULL, dllSize, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
WriteProcessMemory(h, rmt, dllBuf, dllSize, NULL);
DWORD rva = GetReflectiveLoaderOffset(dllBuf);
CreateRemoteThread(h, NULL, 0, (LPTHREAD_START_ROUTINE)((BYTE*)rmt + rva), NULL, 0, NULL);
```

OPSEC: avoid `RWX` allocations — allocate `RW`, then `VirtualProtectEx` to `RX` after copy. Many EDRs flag MZ headers in private commit; consider sRDI to ship the DLL as position-independent shellcode without the PE header in memory.

## Detection and defence
- Sysmon EID 8 (CreateRemoteThread) into a non-loader thread start address inside private memory
- ETW Threat-Intelligence `NtAllocateVirtualMemory` with `RWX` in a remote PID
- EDR memory scans for `MZ`/`PE` magic bytes in `MEM_PRIVATE` regions

## References
- [ired.team — Reflective DLL Injection](https://www.ired.team/offensive-security/code-injection-process-injection/reflective-dll-injection) — original walkthrough
- [Stephen Fewer — ReflectiveDLLInjection (GitHub)](https://github.com/stephenfewer/ReflectiveDLLInjection) — canonical reference implementation
