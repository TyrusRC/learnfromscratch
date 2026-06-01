---
title: Volatility Plugins for Memory Triage
slug: volatility-plugins
---

> **TL;DR:** Volatility's plugin catalogue turns a raw memory dump into process trees, injected-code reports, and credential material — pick Vol3 for modern Windows, fall back to Vol2 only for legacy profiles.

## What it is
Volatility is the de-facto open-source memory-forensics framework. Volatility 2 (Python 2, profile-based) parses Windows XP through 10 1809 reliably; Volatility 3 (Python 3, symbol-table based) covers Windows 10/11 and Server 2019/2022 but has a smaller plugin set and slightly different output schema. Plugins are organised by intent: process enumeration (`pslist`, `psscan`, `pstree`), injected code (`malfind`, `hollowfind`), credentials (`hashdump`, `lsadump`, `mimikatz`), and network (`netscan`, `netstat`). DFIR uses them to answer "what was running, what was hidden, and what secrets were in RAM" at the moment of capture.

## Preconditions / where it applies
- Raw, crash-dump, or hibernation-file image; `VMware .vmem`, `Hyper-V .bin+.vsv`, and `VirtualBox .sav` need conversion (`vol2 imagecopy` or `vmss2core`)
- Vol3 auto-detects the OS via PDB symbols downloaded from Microsoft — air-gapped analyst boxes need a pre-populated `symbols` directory
- Acquire with `WinPMEM`, `DumpIt`, `Magnet RAM Capture`, or `LiME` (Linux); avoid `procdump -ma` for full-system work
- Known gaps: pagefile is not in RAM dumps — combine with `MemProcFS` or a disk image to follow paged-out pages

## Technique
Triage flow for an unknown Windows dump:

```bash
# Vol3
vol -f mem.raw windows.info                          # confirm build + KDBG
vol -f mem.raw windows.pslist
vol -f mem.raw windows.psscan      # pool-scan, finds unlinked procs
vol -f mem.raw windows.pstree
vol -f mem.raw windows.malfind --dump-dir ./malfind  # RWX + no file backing
vol -f mem.raw windows.cmdline
vol -f mem.raw windows.netscan
vol -f mem.raw windows.hashdump
vol -f mem.raw windows.lsadump      # LSA secrets, autologon creds
```

`pslist` walks `PsActiveProcessHead`, so a rootkit unlinking from that list disappears; `psscan` carves `_EPROCESS` from the pool and recovers it — a delta between the two is a textbook hidden-process IOC. `malfind` flags VADs that are `PAGE_EXECUTE_READWRITE` with no mapped file — classic reflective-DLL or shellcode signature; dump the region and run `capa` or YARA against it. For credential theft investigations, Vol2 still ships `mimikatz` and `hollowfind` plugins that have no Vol3 equivalent yet — keep Python 2 + Vol2 around in a venv:

```bash
vol2.py -f mem.raw --profile=Win10x64_19041 mimikatz
vol2.py -f mem.raw --profile=Win10x64_19041 hollowfind
```

## Detection and defence
- Anti-forensics: kernel-mode rootkits hook `NtQuerySystemInformation` to hide processes — defeated by `psscan`; userland packers (VMProtect, Themida) inflate `malfind` false-positive rate so always corroborate with strings/imports
- Direct memory anti-acquisition (DMA blocking, `SecureBootDMA`) can refuse `WinPMEM`; pre-deploy an EDR-side memory dumper that runs in kernel mode
- Hardening: enable Credential Guard so `lsadump` and `mimikatz` return only blobs; enable HVCI to constrain RWX allocations and shrink the `malfind` haystack
- Tampering signals: `pslist` count differs from `psscan` count, `_EPROCESS` with `DirectoryTableBase=0`, kernel modules signed by revoked certs in `windows.modules`

## References
- [Volatility 3 documentation](https://volatility3.readthedocs.io/en/latest/) — plugin index and symbol setup
- [Volatility Foundation GitHub](https://github.com/volatilityfoundation/volatility3) — source and issue tracker

See also: [[memory-image-forensics]], [[traffic-analysis]], [[mft-analysis]].
