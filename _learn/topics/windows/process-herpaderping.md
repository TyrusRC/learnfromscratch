---
title: Process Herpaderping
slug: process-herpaderping
---

> **TL;DR:** Map a benign image into a new process, then overwrite the backing file on disk with malicious bytes before the kernel notifies AV — the EDR scans the wrong content while the dirty payload executes.

## What it is
A defense-evasion primitive disclosed by Johnny Shaw (`jxy-s`) that abuses the gap between when Windows creates a process from a section and when the kernel delivers the `PsSetCreateProcessNotifyRoutineEx` callback. The attacker keeps a write handle on the executable file, maps it with `NtCreateSection(SEC_IMAGE)`, spawns the process with `NtCreateProcessEx`, then rewrites the file contents through the still-open handle so any AV that scans the path on the notification sees innocuous bytes.

## Preconditions / where it applies
- Local execution as a standard user — no privileges beyond writing the target file
- Works against Windows 10 / Server 2019+ where AV relies on file-path scanning at the process-create notification
- Requires the malicious binary to be self-contained (image is already mapped before the swap)

## Technique
Open the target with `FILE_SHARE_READ | FILE_SHARE_DELETE`, write the real (malicious) PE, create an image section, create the process from that section, then overwrite the file on disk with a decoy before calling `NtCreateThreadEx`. By the time the kernel fires the load-image notify routine, the file path resolves to harmless content.

```c
hFile = CreateFile(L"target.exe", GENERIC_READ|GENERIC_WRITE, FILE_SHARE_READ|FILE_SHARE_DELETE, ...);
WriteFile(hFile, payloadPe, payloadSize, ...);            // 1. write real payload
NtCreateSection(&hSec, ..., SEC_IMAGE, hFile);            // 2. map as image
NtCreateProcessEx(&hProc, ..., hSec, ...);                // 3. create process object
SetFilePointer(hFile, 0, 0, FILE_BEGIN);
WriteFile(hFile, decoyBytes, decoySize, ...);             // 4. obscure on disk
NtCreateThreadEx(&hThr, ..., hProc, entryRva, ...);       // 5. start execution
```

The variant that overwrites with garbage instead of a clean PE is sometimes called *herpaderping*; replacing with a signed binary is called *ghosting* or doppelganging — see [[process-injection-techniques]].

## Detection and defence
- Subscribe via `MiniFilter` or `PsSetCreateProcessNotifyRoutineEx2` and hash the *section* not the file path — Microsoft Defender added this in 2022
- Sysmon Event ID 1 hash field shows discrepancy with the on-disk file hash post-execution
- EDRs that scan on `IRP_MJ_CLEANUP` rather than process-create will see the dirty bytes; require both
- Block writable+executable file handles to `.exe` images during creation

## References
- [jxy-s/herpaderping — README](https://github.com/jxy-s/herpaderping/blob/main/README.md) — original PoC and deep dive
- [Microsoft Security Blog — process creation properties](https://www.microsoft.com/en-us/security/blog/2022/06/30/using-process-creation-properties-to-catch-evasion-techniques/) — mitigation design
- [CrowdStrike — Herpaderping: risk or unintended behavior](https://www.crowdstrike.com/en-us/blog/herpaderping-security-risk-or-unintended-behavior/) — detection analysis
