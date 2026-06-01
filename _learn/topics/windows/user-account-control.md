---
title: User Account Control (UAC)
slug: user-account-control
---

> **TL;DR:** UAC splits an admin's logon into a filtered Medium-IL token and an unfiltered High-IL token; bypasses trick an `autoElevate=true` signed binary into spawning attacker-controlled code without the consent prompt, taking you from Medium to High integrity inside the same session.

## What it is
UAC is the security boundary-but-not-quite-a-boundary that Microsoft introduced in Vista to make running as admin daily-driver-safe. At interactive logon, an admin user receives two tokens (split-token model): a stripped Medium-IL primary and a full High-IL secondary. Apps run with the Medium token by default; elevation either prompts (consent.exe) or is silent for select Microsoft binaries marked `autoElevate=true` in their embedded manifest. Microsoft has said multiple times that UAC is "not a security boundary" — meaning bypasses are not serviced as security bugs, but they remain extremely common in attack chains.

## Preconditions / where it applies
- You are running as a member of the local Administrators group with a Medium-IL token (typical user shell on workstations)
- UAC is set to anything other than "Always Notify"; the default "Notify me only when apps try to make changes" is permissive enough for almost every public bypass
- The host has the signed `autoElevate` binary the bypass targets (most are stock Windows components)
- See [[tokens-and-privileges]] for why the Medium↔High split matters

## Technique
Bypass categories (see hfiref0x/UACME for ~80 numbered methods):

- **DLL hijack against an autoElevate target** — drop a planted DLL where an elevated, signed binary will search for it. Classic: SystemPropertiesAdvanced.exe loading `srrstr.dll` from a per-user path, or `fodhelper.exe` loading from `%LOCALAPPDATA%`.
- **Registry hijack of a launched protocol/handler** — `fodhelper.exe` reads `HKCU\Software\Classes\ms-settings\Shell\Open\command` before HKCR. Set it to your payload; launch fodhelper; payload runs High-IL.

```powershell
New-Item "HKCU:\Software\Classes\ms-settings\Shell\Open\command" -Force
Set-ItemProperty "HKCU:\Software\Classes\ms-settings\Shell\Open\command" -Name "(default)" -Value "powershell -nop -w hidden -c <payload>"
Set-ItemProperty "HKCU:\Software\Classes\ms-settings\Shell\Open\command" -Name "DelegateExecute" -Value ""
Start-Process "C:\Windows\System32\fodhelper.exe"
```

- **Environment variable / WindowsApps abuse** — `computerdefaults.exe`, `sdclt.exe`, `eventvwr.exe` are recurring targets. `eventvwr.exe` historically read `HKCU\Software\Classes\mscfile\shell\open\command`.
- **COM elevation moniker abuse** — instantiate `Elevation:Administrator!new:{CLSID}` for a COM class marked Auto-Elevate; chain with token-stealing or DLL hijack on the spawned object.
- **Token / handle manipulation** — duplicate an existing High-IL token from a process you have access to (limited; usually requires equal IL already).
- **Silent install (msi) abuse** — `AlwaysInstallElevated` policy turns any MSI install into SYSTEM; this is configuration weakness, not UAC bypass per se.

Patching cycle: each Patch Tuesday Microsoft kills 1-2 specific binaries (manifest changes, embedded handler hardcoding). New variants pop within weeks because the architecture itself is the issue.

## Detection and defence
- Set UAC to "Always Notify" — kills `autoElevate`-based bypasses by forcing a prompt
- Run as a non-admin user; require runas for elevation (the whole bypass class assumes admin group membership)
- Block `HKCU\Software\Classes` writes via Attack Surface Reduction rules and registry SACLs on commonly abused keys
- Sysmon: parent-child anomalies where `fodhelper.exe`/`computerdefaults.exe` spawn `cmd.exe`/`powershell.exe`/`rundll32.exe`
- Restrict `AlwaysInstallElevated` to 0 in both HKLM and HKCU group policy
- EDRs alert on creation of `Software\Classes\ms-settings` and `mscfile` shell-handler keys

## References
- [UACME — hfiref0x](https://github.com/hfiref0x/UACME) — exhaustive catalogue of numbered bypasses with source
- [Microsoft — How UAC works](https://learn.microsoft.com/en-us/windows/security/identity-protection/user-account-control/how-user-account-control-works) — split-token model reference
- [HackTricks — UAC](https://book.hacktricks.wiki/en/windows-hardening/authentication-credentials-uac-and-efs/uac-user-account-control.html) — operator-focused bypass summary
