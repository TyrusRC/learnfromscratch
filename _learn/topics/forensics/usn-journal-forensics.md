---
title: USN Journal ($UsnJrnl:$J) Forensics
slug: usn-journal-forensics
---

> **TL;DR:** `$UsnJrnl:$J` is NTFS's per-volume change log, and reading its reason codes turns "what files touched the disk in the last 72 hours" into a sortable CSV.

## What it is
The Update Sequence Number journal is an alternate data stream on the `$Extend\$UsnJrnl` metadata file, written every time a file is created, renamed, written, or deleted. Each record stores the file reference number, parent reference, USN, timestamp, and a bitmask of *reason* flags (`DATA_OVERWRITE`, `FILE_CREATE`, `FILE_DELETE`, `RENAME_NEW_NAME`, `CLOSE`, etc.). For DFIR it answers questions `$MFT` cannot: order of operations, which process-chain touched a path, and what was deleted between two acquisitions.

## Preconditions / where it applies
- Enabled by default on Windows 7+ system volumes; sometimes disabled on data volumes
- Acquire via KAPE's `!SANS_Triage` target or `RawCopy.exe /FileNamePath:"C:\$Extend\$UsnJrnl:$J"`
- Retention is *not* time-based: the journal is a sparse circular buffer (typically 32–512 MiB), so a busy volume can wrap in hours
- Volume Shadow Copies often preserve older journal segments — always enumerate VSS with `vssadmin list shadows` before discarding

## Technique
Parse with `MFTECmd` so reason codes are decoded and joined against the live `$MFT`:

```powershell
MFTECmd.exe -f E:\triage\C\$Extend\$J `
            -m E:\triage\C\$MFT `
            --csv .\out --csvf usn.csv
```

The `-m` flag resolves `ParentEntryNumber` back to a full path, which is critical because the journal itself only stores parent FRNs. Pivot the CSV on `Name` to spot staging directories (`%PROGRAMDATA%\<random>\`), or on `UpdateReasons` to isolate suspicious sequences like `FILE_CREATE` → `DATA_EXTEND` → `RENAME_NEW_NAME` → `CLOSE` happening within milliseconds — the canonical signature of a dropper writing then renaming a payload. Correlate USN timestamps against `$MFT.SI.Modified`; if USN shows a write but MFT timestamps are older, you have evidence of timestomping after the fact.

```powershell
# carve a wrapped/partial journal
usn_journal_recover.py --image disk.E01 --offset 0x12340000 > recovered.j
```

## Detection and defence
- Anti-forensics: `fsutil usn deletejournal /d C:` wipes and recreates the journal — leaves a tiny journal with a fresh `Journal ID` on the volume, which itself is an IOC
- Attackers also resize the journal to ~1 MiB to force rapid wrap-around; monitor `fsutil usn queryjournal C:` for unexpected `Maximum Size` changes
- Hardening: increase journal size to 1 GiB on critical hosts (`fsutil usn createjournal m=0x40000000 a=0x1000000 C:`) and ship VSS snapshots off-host nightly
- Tampering signals: monotonic USN suddenly resets to a low value, `Journal ID` differs between VSS snapshots, gaps spanning known-malicious windows

## References
- [Change Journals (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/win32/fileio/change-journals) — reason flag reference
- [Zimmerman MFTECmd](https://ericzimmerman.github.io/) — `$J` parser with MFT join

See also: [[mft-analysis]], [[disk-image-forensics]], [[prefetch-analysis]].
