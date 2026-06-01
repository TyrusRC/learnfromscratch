---
title: ShimCache and Amcache for Execution Evidence
slug: shimcache-amcache
---

> **TL;DR:** ShimCache and Amcache are two registry-hive artifacts that survive prefetch deletion and together answer "did this PE ever touch the box, and when".

## What it is
ShimCache (a.k.a. AppCompatCache) lives in `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache\AppCompatCache` and records up to ~1024 PE files the OS evaluated for application-compatibility shims. It stores the path, last-modified `$STANDARD_INFORMATION` timestamp, and on older Windows an "Executed" flag. Amcache (`C:\Windows\AppCompat\Programs\Amcache.hve`) is richer: per-PE SHA1, PE header data, publisher, file size, first-run time, and parent install metadata. Both persist even after the EXE is deleted, prefetch is wiped, and event logs rotated.

## Preconditions / where it applies
- ShimCache present on every Windows version; the *format* changes per build, so the parser must match
- Amcache exists on Windows 7 SP1+ with the compatibility update; Windows 10/11 split it into `Amcache.hve` + `AmcacheTransactions.hve` log files (replay required)
- Acquire `SYSTEM` hive from `C:\Windows\System32\config\SYSTEM` plus its `.LOG1/.LOG2` to replay pending transactions; same for `Amcache.hve`
- Known gaps: ShimCache only flushes to disk on shutdown — a still-running compromised host has stale on-disk values; live capture via `reg save` reads from memory

## Technique
Parse offline with Zimmerman's tools after replaying registry logs:

```powershell
AppCompatCacheParser.exe -f E:\triage\C\Windows\System32\config\SYSTEM `
                         --csv .\out --csvf shim.csv
AmcacheParser.exe -f E:\triage\C\Windows\AppCompat\Programs\Amcache.hve `
                  -i --csv .\out
```

ShimCache rows are ordered most-recent-first, but the timestamp is the file's *modified* time, **not** the execution time — many analysts get this wrong. Use it to prove presence and ordering, then pivot to Amcache or Prefetch for actual run time. Amcache's `Unassociated file entries` table is the high-value sheet: SHA1 of the binary, full path, link date, and `FileKeyLastWriteTimestamp` (effectively first-seen). A SHA1 here that VirusTotal flags, plus a path in `C:\Users\Public\` or `C:\ProgramData\<random>\`, is a textbook second-stage dropper finding even when the file is long gone.

## Detection and defence
- Anti-forensics: deleting `Amcache.hve` works only until next reboot (it regenerates); ShimCache cannot be edited live because the kernel only writes at shutdown — attackers instead `shutdown /a` and brute-power the box to skip the flush
- Hardening: enable Sysmon Event ID 1 with `ImageLoaded` hashing so PE first-seen is mirrored to the event log and forwarded
- Tampering signals: Amcache SHA1 present with no matching `$MFT` entry and no Prefetch (binary was wiped); ShimCache showing a path that never appears in USN journal; Amcache transaction logs not replayed (analyst error or attacker hint)

## References
- [Mandiant: Leveraging the AppCompat Cache](https://cloud.google.com/blog/topics/threat-intelligence/leveraging-application-compatibility-cache-forensic-investigations/) — format and gotchas
- [AmcacheParser documentation](https://ericzimmerman.github.io/) — column reference

See also: [[prefetch-analysis]], [[mft-analysis]], [[disk-image-forensics]].
