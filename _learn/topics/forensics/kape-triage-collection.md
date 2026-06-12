---
title: KAPE — Kroll Artifact Parser and Extractor
slug: kape-triage-collection
---

> **TL;DR:** KAPE (Eric Zimmerman / Kroll) is the de facto Windows triage collection tool. Targets define WHAT to collect (registry hives, EVTX, prefetch, jumplists, browser artifacts, $MFT). Modules define WHAT to parse it with (Eric Zimmerman tools, hayabusa, chainsaw, plaso). One run produces a triage image + parsed timeline.

## What it is
KAPE is a Windows GUI/CLI written in C# (free for non-commercial DFIR). It uses Volume Shadow Copies + raw NTFS access to grab files that are locked by the OS (Registry hives, $MFT, $UsnJrnl, EVTX still open). The artefact list is community-curated — "Targets" and "Modules" are YAML files in `KapeFiles/`.

## Preconditions / where it applies
- Administrative access to the target Windows host
- Local execution (`kape.exe`) or pushed via PsExec / Velociraptor / EDR live response
- Output volume large enough for triage (~5-20 GB depending on targets)

## Tradecraft

**Standard triage collection — `!SANS_Triage` superset:**

```cmd
kape.exe --tsource C: --target !SANS_Triage --tdest D:\triage\HOST01 ^
  --vhdx HOST01 --zip HOST01
```

This captures:
- All registry hives (SYSTEM, SOFTWARE, SECURITY, SAM, NTUSER.DAT, UsrClass.dat)
- All EVTX
- `$MFT`, `$UsnJrnl:$J`, `$LogFile`
- Prefetch, Amcache, Shimcache references
- Browser history (Chrome, Edge, Firefox)
- Jump lists, LNK, RecentDocs
- Scheduled task XML, Service registry
- WMI repository (`%SystemRoot%\System32\wbem\Repository\`)
- PowerShell history (per-user `ConsoleHost_history.txt`)

`--vhdx` writes a mountable VHDX (preserves paths); `--zip` is the portable alternative.

**Module run — parse what you just collected:**

```cmd
kape.exe --msource D:\triage\HOST01 --mdest D:\out\HOST01 ^
  --module !EZParser,Hayabusa,Chainsaw_Sigma --mflush
```

`!EZParser` runs the full Eric Zimmerman tool suite (EvtxECmd, RECmd, PECmd, MFTECmd, AmcacheParser, …) producing CSV.

**Targeted collection — only what you need (faster, smaller):**

```cmd
:: Web-server compromise: grab IIS + EVTX + processes
kape.exe --tsource C: --target IISLogs,EventLogs,RegistryHives ^
  --tdest D:\triage\WEB01

:: AD DC compromise: grab NTDS + SYSTEM + EVTX
kape.exe --tsource C: --target NTDS,RegistryHives,EventLogs ^
  --tdest D:\triage\DC01
```

For DC NTDS extraction, KAPE handles the VSS snapshot transparently — no `ntdsutil ifm` needed.

**Network share collection — push from analyst workstation:**

```cmd
kape.exe --tsource \\HOST01\C$ --target !SANS_Triage --tdest D:\triage\HOST01
```

Uses your authenticated session; no agent on target. Works when EDR live response is unavailable.

**Common module chains worth memorising:**
- `!EZParser` → general parsing
- `Hayabusa` → EVTX hits sorted by severity
- `Chainsaw_Sigma` → Sigma hits with context
- `Plaso_Log2Timeline` → super-timeline (slow but exhaustive)
- `Volatility_3` → memory image triage (needs separate `winpmem` collection)

**Combine with [[velociraptor-threat-hunting]]:** KAPE is the gold-standard local collection; Velociraptor scales the same artefacts across thousands of hosts. Many IR shops use Velociraptor's `Windows.KapeFiles.Targets` artifact to remote-execute KAPE-equivalent collection without dropping the binary.

## Detection and defence (analyst tradecraft)

- ALWAYS collect $MFT + EVTX + Registry hives even for "small" jobs — those three answer 80% of investigations
- KAPE's `--tflush` empties dest dir first; don't combine with `--zip` if you want both ZIP and raw
- VSS access requires SeBackupPrivilege; running KAPE non-elevated will silently skip locked files
- KAPE Targets/Modules update independently from `kape.exe`; run `Get-KAPEUpdate.ps1` weekly
- For chain of custody, hash the collection with `--vhdx` and record SHA-256 + collection time in case notes

## OPSEC for defenders

- KAPE writes to disk; if the host is being live-triaged for ransomware in progress, prefer Velociraptor or EDR live response to avoid alerting attacker file-system monitors
- Collection from a mounted forensic image (no live target) — use `--tsource E:` pointing at the mounted volume; the same Target set works
- KAPE itself trips some EDR signatures (the binary is well-known); whitelist for IR team or rename per engagement
- VSC mounting touches `_$Recycle.Bin` and may surface attacker-staged data in temp paths — review before assuming it's KAPE noise

## References
- [KAPE docs](https://www.kroll.com/en/services/cyber-risk/incident-response-litigation-support/kroll-artifact-parser-extractor-kape)
- [KapeFiles repo](https://github.com/EricZimmerman/KapeFiles) — Targets + Modules YAML
- [Eric Zimmerman tools](https://ericzimmerman.github.io/) — paired parsers
- [13Cubed — KAPE tutorial series](https://www.youtube.com/@13Cubed)
- [SANS FOR508 — KAPE in IR](https://www.sans.org/cyber-security-courses/advanced-incident-response-threat-hunting-training/)

See also: [[velociraptor-threat-hunting]], [[hayabusa-windows-event-log-triage]], [[chainsaw-evtx-hunting]], [[mft-analysis]], [[shimcache-amcache]], [[prefetch-analysis]], [[windows-event-log-analysis]], [[registry-hive-forensics]], [[volatility-plugins]], [[memory-image-forensics]]
