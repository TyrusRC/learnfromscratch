---
title: Process Ghosting
slug: process-ghosting
---

> **TL;DR:** Write a payload to a file marked delete-pending, map it as an image section, close the handle to delete the file, then spawn a process from the now-orphaned section — so AV/EDR has nothing on disk to scan.

## What it is
Process Ghosting is an executable image tampering technique published by Gabriel Landau (Elastic, 2021). It is a cousin of Process Doppelgänging and Herpaderping. The trick is the Windows file delete-pending state set via `NtSetInformationFile(FileDispositionInformation)`: once a handle is marked delete-pending, other openers fail with `STATUS_DELETE_PENDING`. The attacker still owns a handle that can be passed to `NtCreateSection(SEC_IMAGE)`, after which the file is closed (and physically deleted), yet the in-memory image section survives and is used to bootstrap a real process via `NtCreateProcessEx` / `RtlCreateProcessParametersEx` / `NtCreateThreadEx`.

## Preconditions / where it applies
- Local code execution; no special privileges beyond write access to a working directory
- Works on Windows 10 / Server 2019+ — the delete-pending path predates this and still works on recent builds
- Effective primarily against on-write file scanners that race the section creation

## Technique
The flow is six syscalls. Once the section exists, the file on disk is irrelevant — process creation reads memory, not the filesystem.

```c
// 1. Create the carrier file
hFile = CreateFileW(L"C:\\Temp\\ghost.exe", DELETE | SYNCHRONIZE, 0, ...);
// 2. Mark it delete-pending BEFORE writing the payload
FILE_DISPOSITION_INFORMATION fdi = { TRUE };
NtSetInformationFile(hFile, &iosb, &fdi, sizeof fdi, FileDispositionInformation);
// 3. Write payload PE bytes
WriteFile(hFile, payload, payloadLen, &w, NULL);
// 4. Snapshot it as an image section
NtCreateSection(&hSection, SECTION_ALL_ACCESS, NULL, 0, PAGE_READONLY, SEC_IMAGE, hFile);
// 5. Close the handle — file is gone from disk
CloseHandle(hFile);
// 6. Create process from the section
NtCreateProcessEx(&hProc, ..., hSection, ...);
```

Operators often pair this with [[parent-pid-spoofing]] and [[process-injection-techniques]] to further break attribution. The ghosted process has no backing file, so `GetModuleFileName` on it returns an inconsistent path that itself is a hunting signal.

## Detection and defence
- Sysmon event ID 1 (ProcessCreate) with an `Image` path that no longer exists on disk
- Kernel-mode callbacks (`PsSetCreateProcessNotifyRoutineEx`) still fire — modern EDR hooks here
- Microsoft Defender added detection in 2021; ensure ELAM / image-load callbacks are enabled
- Hunt for `FILE_DISPOSITION_INFORMATION` set followed by `NtCreateSection(SEC_IMAGE)` on the same handle

## References
- [Elastic — Process Ghosting](https://www.elastic.co/blog/process-ghosting-a-new-executable-image-tampering-attack) — Gabriel Landau's original write-up
- [hasherezade/process_ghosting](https://github.com/hasherezade/process_ghosting) — reference PoC
