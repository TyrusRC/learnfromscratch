---
title: $MFT Record Analysis
slug: mft-analysis
---

> **TL;DR:** The Master File Table is NTFS's authoritative ledger of every file, and parsing FILE records reveals timeline, slack, and resident data invisible to a live filesystem walk.

## What it is
`$MFT` is the root metadata file of any NTFS volume: a flat array of 1 KiB FILE records, one per file or directory, holding attributes like `$STANDARD_INFORMATION`, `$FILE_NAME`, and `$DATA`. Small files live entirely *inside* their MFT record as resident data, while larger ones use non-resident runs pointing at cluster ranges. DFIR analysts parse it to reconstruct deletions, recover wiped payloads, and detect timestamp tampering ("timestomping") that filesystem APIs would hide.

## Preconditions / where it applies
- NTFS volume; ReFS and FAT have completely different layouts
- Raw image (E01/RAW) or triage acquisition (`KAPE` `!SANS_Triage` target) that copies `$MFT` and `$LogFile`
- Live capture needs a volume snapshot or `FTK Imager` / `RawCopy` because `$MFT` is locked
- Known gaps: heavy churn on small volumes recycles records; only the last write survives in the active record

## Technique
Extract `$MFT` from the image or VSS copy, then parse with Eric Zimmerman's `MFTECmd`:

```powershell
MFTECmd.exe -f E:\triage\C\$MFT --csv .\out --csvf mft.csv
MFTECmd.exe -f E:\triage\C\$MFT --de 0x1A4F2  # dump entry 107762 in detail
```

Key columns to pivot on: `EntryNumber`, `SequenceNumber`, `InUse`, `ParentEntryNumber`, the four `SI` timestamps, and the four `FN` timestamps. A classic timestomp signal is `SI.Created > FN.Created` or sub-second zeros on `SI` while `FN` retains nanosecond precision. Resident `$DATA` shows up in the `ResidentData` field — useful for recovering small PowerShell droppers even after deletion, because the bytes remain inside the MFT entry until the slot is reused. For deleted records, filter `InUse == False` and join `ParentEntryNumber` back to the live tree to reconstruct where the file lived. Non-resident files expose data runs (`StartCluster:LengthInClusters`) you can carve directly with `dd skip=`.

## Detection and defence
- Anti-forensics: `SetMACE`, `timestomp.exe`, and `nTimestomp` rewrite `$STANDARD_INFORMATION` but rarely touch `$FILE_NAME`; the mismatch is the tell
- `$MFT` defragmentation or `chkdsk /f` can shred deleted records — capture before remediation
- Harden by enabling object-access SACLs on sensitive directories so creation/deletion is mirrored in the Security log
- Tampering signals: huge gaps in `EntryNumber` sequence, identical timestamps across thousands of records, or `$LogFile` transactions that contradict the current FILE record

## References
- [NTFS Master File Table (Microsoft Learn)](https://learn.microsoft.com/en-us/windows/win32/fileio/master-file-table) — official structure reference
- [MFTECmd documentation](https://ericzimmerman.github.io/) — Zimmerman's parser and column reference

See also: [[disk-image-forensics]], [[usn-journal-forensics]], [[shimcache-amcache]].
