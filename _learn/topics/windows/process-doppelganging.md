---
title: Process Doppelgänging
slug: process-doppelganging
---

> **TL;DR:** Abuse NTFS transactions to write a malicious image to disk, map it as a section, spawn a process from that section, then roll the transaction back so the file on disk never existed.

## What it is
Process Doppelgänging is a code-injection / process masquerading technique presented by Liberman and Kogan (BlackHat EU 2017). It chains four primitives — `CreateTransaction`, `CreateFileTransacted`, `NtCreateSection` with `SEC_IMAGE`, and the undocumented `NtCreateProcessEx` — so the kernel builds a process image from a transacted file that is rolled back before the loader finishes. On-disk scanners and most AV minifilters see nothing because the malicious bytes are only ever visible inside the transaction handle.

## Preconditions / where it applies
- Local code execution; no elevation strictly required, though SYSTEM widens target choices
- NTFS volume (transactions are an NTFS feature; ReFS will not work)
- Pre-`NtCreateProcessEx` is undocumented and version-sensitive — works most reliably on Windows 7–10 1709; later builds added behavioural detection in Defender

## Technique
Open a transaction, write the payload PE inside it, create an image section from the transacted file handle, then call `NtCreateProcessEx` against that section and `RtlCreateProcessParametersEx` + `NtCreateThreadEx` to give the new process a fake command line pointing at a benign host (e.g. `svchost.exe`). Finally `RollbackTransaction` so the file vanishes.

```c
CreateTransaction(NULL, 0, 0, 0, 0, 0, L"Doppel");
HANDLE hFile = CreateFileTransacted(L"C:\\Windows\\Temp\\zone.txt",
    GENERIC_WRITE|GENERIC_READ, 0, NULL, CREATE_ALWAYS, 0, NULL, hTx, NULL, NULL);
WriteFile(hFile, payloadPE, payloadSize, &w, NULL);
NtCreateSection(&hSec, SECTION_ALL_ACCESS, NULL, 0, PAGE_READONLY, SEC_IMAGE, hFile);
RollbackTransaction(hTx);
NtCreateProcessEx(&hProc, PROCESS_ALL_ACCESS, NULL, GetCurrentProcess(),
    PS_INHERIT_HANDLES, hSec, NULL, NULL, FALSE);
```

OPSEC: Process Explorer shows the fake image name from the rolled-back file, but PPL and ELAM-protected hosts still refuse the section map. Pair with [[parent-pid-spoofing]] to fix the parent-child telemetry too.

## Detection and defence
- Sysmon Event ID 1 with `Image` pointing at a non-existent path is a strong tell
- Kernel callbacks via `PsSetCreateProcessNotifyRoutineEx` see the section-backed create; modern EDR hooks `NtCreateProcessEx`
- Monitor `TxF` ETW provider (`Microsoft-Windows-Kernel-Transaction`) for `CreateTransaction` followed by `Rollback` from non-DB processes

## References
- [ired.team — Process Doppelgänging](https://www.ired.team/offensive-security/code-injection-process-injection/process-doppelganging) — original walkthrough
- [hasherezade/process_doppelganging](https://github.com/hasherezade/process_doppelganging) — reference PoC
- [MITRE ATT&CK T1055.013](https://attack.mitre.org/techniques/T1055/013/) — technique mapping

Related: [[process-injection-techniques]], [[parent-pid-spoofing]]
