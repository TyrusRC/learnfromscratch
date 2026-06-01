---
title: LNK and JumpList forensics
slug: lnk-jumplist-forensics
---

> **TL;DR:** Windows shortcut files (`.lnk`) and Application JumpLists (`automaticDestinations-ms` / `customDestinations-ms`) record the full path, drive serial, MAC times and even the NetBIOS / MAC address of every file the user opened recently — they survive after the original file is deleted and are some of the most reliable proof-of-access artefacts in Windows DFIR.

## What it is
Whenever Explorer opens a file, Windows writes a Shell Link (`.lnk`) into `%APPDATA%\Microsoft\Windows\Recent\` and appends an entry to the per-application JumpList in `%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations\`. The shortcut and JumpList entry both embed a `SHELL_LINK` structure that records:

- Target file's **full absolute path** at the time of access.
- Target's **size, MAC timestamps, file attributes** at the time of access.
- Volume **serial number** and **drive type** (fixed / removable / network).
- Origin machine's **NetBIOS name** and **MAC address** (for network shares).
- Sometimes a chain of `LinkTargetIDList` shell items (each folder in the path).

Because they capture state at access time and persist after deletion, LNK and JumpList artefacts often catch off-system activity (USB, network shares) and recover deleted-file paths.

## Preconditions / where it applies
- Windows DFIR triage. Works against any user's profile, live or offline.
- Insider-threat, IP-theft, lateral-movement source attribution — anywhere you need "did this user open this file" with high confidence.

## Technique
**1. Where they live.**

| Artefact | Path |
|---|---|
| Recent LNKs | `C:\Users\<u>\AppData\Roaming\Microsoft\Windows\Recent\*.lnk` |
| Office MRU LNKs | `C:\Users\<u>\AppData\Roaming\Microsoft\Office\Recent\*.lnk` |
| Start Menu LNKs | `C:\Users\<u>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\*.lnk` (per-user) and `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\` (system) |
| Automatic JumpLists | `C:\Users\<u>\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations\<AppID>.automaticDestinations-ms` |
| Custom JumpLists | `C:\Users\<u>\AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations\<AppID>.customDestinations-ms` |

The `<AppID>` is a hex string identifying the application; consult the published [JumpList AppID list](https://github.com/EricZimmerman/JumpList/blob/master/JumpList/Resources/AppIDs.txt) to map e.g. `9d1f905ce5044aee` → Word 2016 / 2019 / 365.

**2. Parse.**
```bash
# LECmd — Eric Zimmerman, single LNK
LECmd.exe -f file.lnk --csv out/

# JLECmd — JumpList parser
JLECmd.exe -d "C:\Users\u\AppData\Roaming\Microsoft\Windows\Recent" --csv out/

# Python alternative
python -m liblnk file.lnk
```
You get a row per LNK / per JumpList DestList entry with: target path, target MAC times, file size, volume serial, drive type, machine ID (NetBIOS), MAC address.

**3. Reading the fields.**

- **TargetFullPath:** absolute path of the opened file at access time. If the path starts with a drive letter not present on the host now, it points to a USB or network mount.
- **VolumeSerialNumber:** cross-reference with `SYSTEM\MountedDevices` and `USBSTOR` ([[registry-hive-forensics]]) to identify which removable device.
- **DriveType:** 3 = fixed, 2 = removable, 4 = remote. Removable + a volume serial not in current `MountedDevices` = file was opened from a USB no longer present.
- **MachineID / MAC:** for network shares, these belong to the source machine that originally created the link (or the local machine if local file). MAC address survives even if the share is long gone — strong attribution.
- **AccessTime / WriteTime / CreateTime:** the target's MAC times at access — preserved even after the target is deleted.

**4. JumpList structure.**
The `.automaticDestinations-ms` file is a Microsoft Compound Document (OLE2) containing:
- **DestList** stream — ordered list of MRU entries (each entry has access count, last-access time, target path, machine ID).
- One stream per entry, each holding a full `SHELL_LINK` structure as if it were a standalone `.lnk` file.

`.customDestinations-ms` is simpler: a sequence of concatenated `SHELL_LINK` records preceded by a header — used for tasks pinned by the application (e.g., Word's "Recent" + "Pinned" sections).

**5. Investigation patterns.**

*Did the user open X.docx?* Look in `Recent\*.lnk` and the Word JumpList. Even after deleting X.docx, the LNK still shows the path and times.

*Was a USB device used to exfiltrate files?* Pull every LNK with `DriveType=2`, group by `VolumeSerialNumber`. Each unique serial is a distinct USB; cross-reference with USB-history in registry to identify model/serial.

*Was a network share accessed?* `DriveType=4` LNKs + `MachineID` give source host. Also check `NTUSER.DAT\Network` and `MountPoints2` for drive mappings.

*Did the user execute a payload from a network share?* LNK with `TargetFullPath` UNC path in `\\<host>\C$\Windows\Temp\` is highly suspicious.

*Reconstructing a deleted file's path:* the LNK preserves the full path long after the target is gone; combined with [[mft-analysis|MFT entries]] you may recover the file from unallocated space.

**6. Office MRU + Registry MRU triangulation.** Each Office app also writes to `NTUSER.DAT\Software\Microsoft\Office\<ver>\<app>\User MRU\...\Item N` — same data, redundant store. Use both when one has been tampered.

**7. Pinned-vs-recent distinction.** JumpList DestList entries carry a `Pinned` flag — pinned items survive `Recent`-folder clears, making them anti-anti-forensic.

**8. Pitfalls.**
- LNKs are not created on every open — only on Explorer / Open-File-Dialog opens; programmatic `CreateFile` calls don't generate them.
- Some apps disable JumpList entirely (e.g., "private browsing" modes).
- Group Policy can wipe `Recent` on logoff (`Computer Configuration → Administrative Templates → Windows Components → File Explorer → Clear history of recently opened documents on exit`).
- Be careful with timestamps — a LNK's own MAC times reflect when *the LNK* was written, distinct from the target's MAC times *inside* the LNK.

## Detection and defence
- Don't rely on these as authoritative; assume an attacker who knows Windows DFIR will clear `Recent\` after their session.
- For long-term retention, ship `Recent\` snapshots into the SIEM or use Microsoft's User Activity Center / Activity History (cloud-synced).
- Threat hunters: alert on LNKs created in user profiles that point at suspicious removable drives or UNC paths to known-sensitive shares.

## References
- [Microsoft — \[MS-SHLLINK\] Shell Link Binary File Format](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-shllink/) — canonical spec
- [Eric Zimmerman — LECmd / JLECmd](https://ericzimmerman.github.io/) — modern parsers
- [Forensicsmatters — JumpList AppID list](https://github.com/EricZimmerman/JumpList/blob/master/JumpList/Resources/AppIDs.txt)
- *Windows Forensic Analysis* — Harlan Carvey; LNK + JumpList chapters
