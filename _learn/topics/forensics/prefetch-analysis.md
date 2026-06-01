---
title: Windows Prefetch (.pf) Analysis
slug: prefetch-analysis
---

> **TL;DR:** Prefetch files prove a binary executed, when, how often, and which DLLs and data files it touched in its first ten seconds — gold for execution-evidence questions.

## What it is
Windows' boot/application Prefetcher writes a `.pf` file under `C:\Windows\Prefetch\` whenever an executable runs interactively. The file is named `<EXE>-<HASH>.pf`, where the hash is derived from the full path; the SCCA (`MAM\x04`) structure inside stores the executable name, run count, up to eight last-run timestamps, and a referenced-files list (typically 100–300 paths). For DFIR this is *the* artifact for answering "did this binary execute on this host, when, and from where".

## Preconditions / where it applies
- Enabled by default on Windows 7–11 *client* SKUs; disabled by default on Server SKUs (`EnablePrefetcher` under `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters`)
- Acquire from a triage image (`KAPE` `Prefetch` target) or `RawCopy.exe`
- Compressed with Xpress Huffman on Win10+; legacy tools that don't decompress will fail silently
- Known gaps: max 1024 `.pf` files (256 on Win7), rotated FIFO; binaries run from network shares often skipped

## Technique
Parse with Zimmerman's `PECmd`:

```powershell
PECmd.exe -d C:\triage\Windows\Prefetch --csv .\out --csvf prefetch.csv
PECmd.exe -f C:\triage\Windows\Prefetch\POWERSHELL.EXE-022A1FCE.pf -k
```

The CSV exposes `ExecutableName`, `RunCount`, `LastRun` through `PreviousRun7`, `Hash`, `Size`, and the joined `FilesLoaded` list. Cross-check the path hash: if `POWERSHELL.EXE-022A1FCE.pf` exists alongside `POWERSHELL.EXE-AE8EE6CB.pf`, the second hash means PowerShell was *also* launched from a non-standard path (e.g., copied to `C:\Users\Public\`) — a classic LOLBin relocation IOC. The eight last-run timestamps let you build a frequency timeline without touching the registry. The `FilesLoaded` block frequently reveals what data the binary opened: a `mimikatz.pf` referencing `\DEVICE\HARDDISKVOLUME2\USERS\ADMIN\DESKTOP\CREDS.TXT` is its own conclusion.

## Detection and defence
- Anti-forensics: `del /f C:\Windows\Prefetch\*.pf`, `Remove-Item` from PowerShell, or setting `EnablePrefetcher=0`; absence on a client SKU is itself suspicious
- Some malware overwrites the `.pf` with zeros to keep filename but kill content — PECmd will throw "invalid header" which you should alert on, not filter out
- Hardening: forward `Microsoft-Windows-Kernel-Process/Analytic` and Sysmon Event ID 1 to SIEM so execution evidence is duplicated off-host
- Tampering signals: `RunCount` of 1 with eight populated `LastRun` slots, hashes that don't match the recorded path, or mtime of `.pf` predating the executable's own creation time

## References
- [Libyal libscca](https://github.com/libyal/libscca) — SCCA format reference and parser
- [PECmd documentation](https://ericzimmerman.github.io/) — flag reference and CSV columns

See also: [[mft-analysis]], [[shimcache-amcache]], [[usn-journal-forensics]].
