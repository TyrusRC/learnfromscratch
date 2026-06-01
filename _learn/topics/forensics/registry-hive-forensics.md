---
title: Registry hive forensics
slug: registry-hive-forensics
---

> **TL;DR:** SAM, SYSTEM, SECURITY, SOFTWARE, and per-user NTUSER.DAT / UsrClass.dat hold authentication material, services, run keys, USB history, MRU lists, and shellbag activity — pull them offline with RegRipper / `reglookup` and you get a near-complete picture of what ran, who logged in, and what was attached.

## What it is
The Windows registry is a hive-file-backed key/value store. Each hive serves a different purpose:

| Hive | On-disk path | What's in it |
|---|---|---|
| `SAM` | `C:\Windows\System32\config\SAM` | Local accounts, NT hashes (encrypted with SYSKEY) |
| `SYSTEM` | `C:\Windows\System32\config\SYSTEM` | Services, drivers, CurrentControlSet, USB device history, network interfaces |
| `SECURITY` | `C:\Windows\System32\config\SECURITY` | Audit policy, cached domain creds (`SECURITY\Cache`), LSA secrets |
| `SOFTWARE` | `C:\Windows\System32\config\SOFTWARE` | Installed apps, persistence keys (`Run`/`RunOnce`), uninstall entries, Windows version + install date |
| `NTUSER.DAT` | `C:\Users\<u>\NTUSER.DAT` | Per-user persistence, MRUs, typed paths, RDP MRUs, run keys |
| `UsrClass.dat` | `C:\Users\<u>\AppData\Local\Microsoft\Windows\UsrClass.dat` | COM, shellbags, AppX, file extension associations |

Hives live in transactional log files (`*.LOG1`, `*.LOG2`) — replay them onto the hive before parsing to avoid missing the last edits.

## Preconditions / where it applies
- DFIR triage of a Windows host (live registry via reg.exe, or offline image).
- Often the *only* source of certain artefacts (USB-attached devices, ShellBag folder access, deleted scheduled tasks).

## Technique
**1. Acquire.** Don't `copy` while the host is live — files are locked. Use:
```cmd
reg save HKLM\SAM      C:\triage\SAM
reg save HKLM\SYSTEM   C:\triage\SYSTEM
reg save HKLM\SECURITY C:\triage\SECURITY
reg save HKLM\SOFTWARE C:\triage\SOFTWARE
:: per-user
reg save "HKU\<sid>" C:\triage\NTUSER_<u>.DAT
```
On a triage image: copy `\Windows\System32\config\*` and per-user `NTUSER.DAT` + `UsrClass.dat`.

**2. Replay transaction logs.** `RECmd` / `yarp-print --replay` apply `.LOG1`/`.LOG2`. Skip this and you may see a hive that's hours stale at the head.

**3. RegRipper — the swiss army parser.**
```bash
rip.pl -r SYSTEM -p winver
rip.pl -r SYSTEM -p services             # service / driver enumeration
rip.pl -r SYSTEM -p usbstor              # USB device history
rip.pl -r SOFTWARE -p run                # autoruns
rip.pl -r NTUSER.DAT -p userassist       # GUI program execution counts
rip.pl -r UsrClass.dat -p shellbags      # folder browsing
```

**4. High-value keys by investigation question.**

*What ran here?*
- `SOFTWARE\Microsoft\Windows\CurrentVersion\Run` / `RunOnce` / `RunOnceEx` — persistence; see [[registry-run-keys-persistence]].
- `NTUSER.DAT\Software\Microsoft\Windows\CurrentVersion\Run` — per-user persistence.
- `NTUSER.DAT\...\UserAssist` — GUI program launches (ROT13-encoded names, run count, last execution).
- `SYSTEM\CurrentControlSet\Services` — services + their `ImagePath`; cross-check 7045 in event log ([[windows-event-log-analysis]]).
- `SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall` — installed apps and (sometimes) silent installer paths.
- `NTUSER.DAT\...\Explorer\MUICache` — every executable ever launched from Explorer.
- `SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store` — programs flagged by PCA.

*What was attached?*
- `SYSTEM\CurrentControlSet\Enum\USBSTOR` and `USB` — every USB mass-storage device ever attached, with VID/PID/serial.
- `SYSTEM\MountedDevices` — drive-letter assignment history (correlate with USBSTOR).
- `SOFTWARE\Microsoft\Windows Portable Devices\Devices` — friendly name + last connected (since Win7).
- `NTUSER.DAT\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2` — per-user drive mounts (lateral movement!).

*Who logged on?*
- `SAM\SAM\Domains\Account\Users` — local accounts; hashes (use `secretsdump.py SYSTEM SAM LOCAL`).
- `SECURITY\Cache` — cached domain credentials (mscash2; see [[cached-domain-credentials]]).
- `SECURITY\Policy\Secrets` — LSA secrets (service account passwords; `secretsdump.py -lsa`).
- `SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList` — SID → username + profile path.

*What was browsed?*
- `UsrClass.dat\Local Settings\Software\Microsoft\Windows\Shell\BagMRU` + `Bags` — **ShellBags** — folder browsing history including external / network paths. Parse with `Eric Zimmerman's SBECmd`.
- `NTUSER.DAT\...\TypedPaths` — paths typed into Explorer address bar.
- `NTUSER.DAT\...\RecentDocs` — recently opened files by extension.
- `NTUSER.DAT\...\OpenSavePidlMRU` — file open/save dialog MRUs.

*Was this an RDP source?*
- `NTUSER.DAT\Software\Microsoft\Terminal Server Client\Default` — MRUs of recent RDP destinations.
- `NTUSER.DAT\Software\Microsoft\Terminal Server Client\Servers\<host>` — per-host last-username (lateral movement!).

*Persistence and tampering?*
- `SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\<exe>\Debugger` — [[ifeo-debugger-persistence|IFEO debugger hijack]].
- `SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\Shell` / `Userinit` — boot-time persistence.
- `SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved` — autoruns the user disabled (anti-forensic when attacker disables their own marker).
- `SYSTEM\CurrentControlSet\Control\Lsa\Notification Packages` — DLL-loaded into LSASS.

**5. Timelining.** Hive last-write times are per-key. Combine with `RegistryExplorer` / `RegRipper` + `mactime` to build a registry timeline alongside MFT timestamps ([[mft-analysis]]). Sudden burst of last-write times in service/run keys at an oddly precise hour is the most reliable signal of registry-based persistence install.

**6. Anti-forensics signs.**
- Reflective registry keys (no flat-file backing, only in-memory) — gone after reboot, never on disk.
- `RegHide` / null-byte-prefixed key names invisible to `reg.exe` but visible via raw hive parsing.
- Tools that backdoor `Run` keys then restore them on shutdown — only the LOG files capture the transient state.

## Detection and defence
- Forward registry changes you care about to a SIEM via Sysmon Event ID 13 (RegSetValue) or Windows Event 4657 with proper SACLs.
- Snapshot critical keys daily and diff (`HKLM\System\CurrentControlSet\Services`, `Run`/`RunOnce`, `Winlogon`).
- Disable LSA cache (`SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\CachedLogonsCount = 0`) on tier-0 hosts to remove mscash2 attack surface.

## References
- [Eric Zimmerman's RECmd / RegistryExplorer / SBECmd](https://ericzimmerman.github.io/) — modern parsing
- [RegRipper](https://github.com/keydet89/RegRipper3.0) — long-running plugin catalogue
- [Microsoft — Registry hive files](https://learn.microsoft.com/en-us/windows/win32/sysinfo/registry-hives) — canonical layout
- *Windows Forensic Analysis* — Harlan Carvey; book-length treatment
