---
title: Process Hollowing
slug: process-hollowing
---

> **TL;DR:** Spawn a benign process suspended, carve out its image with `NtUnmapViewOfSection`, write a malicious PE in its place, fix relocations, point the entry thread at the new code and `ResumeThread` — payload runs under a legitimate process name and PID.

## What it is
A classic image-replacement injection that uses `CreateProcessA(..., CREATE_SUSPENDED, ...)`, `NtUnmapViewOfSection`, `VirtualAllocEx`, `WriteProcessMemory`, `GetThreadContext`/`SetThreadContext`, and `ResumeThread` to substitute the in-memory image of a host process (commonly `svchost`, `explorer`, `notepad`) with an attacker PE. The PEB image path still points at the original file on disk, which is why hollowed processes often look benign in casual triage.

## Preconditions / where it applies
- Same-integrity or higher rights on the spawned victim process (typically Medium IL is enough for a user-owned host)
- A PE payload whose sections you can map and whose `.reloc` table you can walk if the requested image base is taken
- Works across all supported Windows versions; well known to AV/EDR so usually needs additional unhooking

## Technique
Create the host suspended, query its `PEB->ImageBaseAddress` via `NtQueryInformationProcess`, unmap the original image, allocate fresh memory at that base, copy headers and sections, apply base relocations if the alloc fell elsewhere, then redirect the suspended thread's `Rcx`/`Eax` to the new entry point.

```c
CreateProcessA(target, NULL, ..., CREATE_SUSPENDED, ..., &si, &pi);
NtUnmapViewOfSection(pi.hProcess, peb.ImageBaseAddress);
LPVOID base = VirtualAllocEx(pi.hProcess, peb.ImageBaseAddress,
                             nt->OptionalHeader.SizeOfImage,
                             MEM_COMMIT|MEM_RESERVE, PAGE_EXECUTE_READWRITE);
WriteProcessMemory(pi.hProcess, base, payload, headersSize, NULL);
// copy each section, apply .reloc deltas
ctx.Rcx = (DWORD64)base + nt->OptionalHeader.AddressOfEntryPoint;
SetThreadContext(pi.hThread, &ctx);
ResumeThread(pi.hThread);
```

OPSEC: image path in `_PEB->ProcessParameters` still references the carrier on disk — combine with [[parent-pid-spoofing]] and command-line spoofing for stronger masquerade. Modern EDR scans for `NtUnmapViewOfSection` against your own suspended child or for RWX private commit at the image base.

## Detection and defence
- Sysmon EID 7 (Image loaded) showing the carrier's main module load followed by no further imports, plus EID 10 (ProcessAccess) with `0x1F0FFF` from the parent
- Memory scanners (e.g. PE-sieve, Moneta) flag private+executable regions where the on-disk image should be mapped
- EDR userland hooks on `NtUnmapViewOfSection` + `NtWriteVirtualMemory` against a `CREATE_SUSPENDED` child are the canonical kill chain trigger

## References
- [ired.team — Process Hollowing and PE Relocations](https://www.ired.team/offensive-security/code-injection-process-injection/process-hollowing-and-pe-image-relocations) — original walkthrough
- [MITRE ATT&CK T1055.012](https://attack.mitre.org/techniques/T1055/012/) — Process Hollowing sub-technique mapping

Related: [[process-injection-techniques]], [[parent-pid-spoofing]], [[ntmapviewofsection-injection]]
