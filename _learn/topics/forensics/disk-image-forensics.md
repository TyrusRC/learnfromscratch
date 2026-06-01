---
title: Disk-image forensics
slug: disk-image-forensics
---

> **TL;DR:** Mount or parse a `dd` / E01 image with Sleuth Kit / Autopsy; carve deleted files, walk the MFT / inode tree, and pull browser history, registry hives, and journal artefacts.

## What it is
Disk-image forensics works against a forensically-sound copy of a storage device — usually raw `dd`, EWF (`.E01`), or VMDK. Analysis recovers filesystem metadata (timestamps, allocation bitmaps), deleted-file content from unallocated space, and OS-specific artefacts (Windows registry, NTFS journal, Linux journald, browser SQLite). Sleuth Kit provides the primitives; Autopsy is the GUI shell.

## Preconditions / where it applies
- A disk image acquired with `dd`, `ewfacquire`, `dc3dd`, `FTK Imager`, or extracted from a VM snapshot.
- Write-blocked or read-only access to preserve the original.
- Hash baseline (`md5sum` / `sha256sum`) recorded before any analysis step.

## Technique
Identify partitions and filesystems, then iterate.

```bash
mmls evidence.dd                       # partition table
fsstat -o 2048 evidence.dd             # FS details for partition at sector 2048
fls -r -o 2048 evidence.dd > files.txt # recursive file listing including deleted
icat -o 2048 evidence.dd 12345 > out   # extract by inode/MFT entry
```

For carving by file-magic against unallocated space when filesystem metadata is gone:

```bash
foremost -t all -i evidence.dd -o carved/
photorec evidence.dd          # interactive, signature-based
```

Windows-specific high-value artefacts:
- **NTFS $MFT** — parse with `MFTECmd` or `analyzeMFT.py` for full file metadata even after deletion.
- **Registry hives** (`SYSTEM`, `SOFTWARE`, `NTUSER.DAT`) — `RegRipper` for AutoRuns, MRU lists, USB history.
- **USN Journal ($UsnJrnl:$J)** and **$LogFile** — recent renames, deletions, creates.
- **Prefetch / Amcache / ShimCache** — execution evidence.
- **Browser** — `dburl` against `History`, `Cookies`, `Login Data` SQLite files; decrypt with `DPAPI` master keys.

For Linux images, look at `/var/log/journal/`, `~/.bash_history`, `/etc/shadow`, and ext4 journal with `debugfs`. Mount read-only with `mount -o ro,loop,offset=$((2048*512)) evidence.dd /mnt/case`.

## Detection and defence
- Full-disk encryption (BitLocker, LUKS, FileVault) blocks offline analysis without keys; ensure TPM + PIN.
- Secure-delete utilities and SSD TRIM destroy unallocated data — but $MFT entries and journal artefacts often survive.
- For incident response, capture memory ([[memory-image-forensics]]) before powering down — encryption keys live in RAM.

## References
- [The Sleuth Kit](https://www.sleuthkit.org/sleuthkit/) — `mmls`, `fls`, `icat`, `fsstat`
- [Autopsy](https://www.sleuthkit.org/autopsy/) — GUI on top of TSK with ingest modules
- [MFTECmd / EZ Tools](https://ericzimmerman.github.io/) — registry, MFT, prefetch parsers
- [RegRipper](https://github.com/keydet89/RegRipper3.0) — Perl plugin framework for Windows registry
- See also: [[memory-image-forensics]], [[file-concentration]]
