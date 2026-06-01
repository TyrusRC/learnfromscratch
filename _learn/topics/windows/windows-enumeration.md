---
title: Windows host enumeration
slug: windows-enumeration
---

> **TL;DR:** First 60 seconds on a Windows shell: identify the user/token, OS build + patch level, local privesc surface (services, scheduled tasks, autoruns, file ACLs), domain context, and AV/EDR posture. Drives every subsequent decision.

## What it is
Post-access enumeration on Windows is the structured collection of identity, configuration, and exposure information that maps the host to known privilege-escalation primitives and identifies the EDR you have to evade. Run it manually for stealth or via WinPEAS/Seatbelt/PrivescCheck when time matters. See [[tokens-and-privileges]] for token interpretation and [[credential-dumping]] for what to do once you have SYSTEM.

## Preconditions / where it applies
- Any Windows shell — interactive RDP, WinRM, beacon, web shell
- LOLBINS-only constraint: every command below is built into the OS, no transfer needed
- Workstation, server, and domain controller — adjust focus (DC adds AD / SYSVOL collection)

## Technique
Identity and integrity.

```cmd
whoami /all
whoami /priv
whoami /groups
echo %USERDOMAIN%\%USERNAME%
net user %USERNAME% /domain
```

OS version and patches — pairs to public exploit DB.

```cmd
systeminfo
wmic qfe list brief
ver
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName
```

Local accounts and groups.

```cmd
net user
net localgroup administrators
quser
```

Network posture.

```cmd
ipconfig /all
route print
netstat -ano
arp -a
nltest /dclist:%USERDNSDOMAIN%
```

Services with weak permissions (unquoted path, weak DACL, modifiable binary):

```cmd
sc qc <name>
icacls "C:\Path\To\service.exe"
wmic service get name,pathname,startmode,startname
```

Scheduled tasks and autoruns.

```cmd
schtasks /query /fo LIST /v
reg query HKLM\Software\Microsoft\Windows\CurrentVersion\Run
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Run
dir "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup"
```

Installed software and credential troves.

```cmd
wmic product get name,version
dir /s /b C:\Users\*\*.kdbx C:\Users\*\unattend.xml C:\Windows\Panther\Unattend.xml
findstr /si /n "password" *.xml *.ini *.config *.ps1
cmdkey /list
```

AV / EDR posture.

```cmd
sc query | findstr /i "defender sense crowd carbon sentinel cylance cb"
tasklist /svc | findstr /i "msmpeng sentinel cb traps"
reg query "HKLM\SOFTWARE\Microsoft\Windows Defender" /s
Get-MpPreference   # if PowerShell available — exclusions are gold
```

Domain / AD if joined.

```cmd
net group "Domain Admins" /domain
net group "Enterprise Admins" /domain
gpresult /R
klist
nltest /domain_trusts /all_trusts
```

Automated kits — `winPEAS.exe` (or `.bat` for AMSI-free), `Seatbelt.exe -group=all`, `PrivescCheck.ps1`. Pair with [[user-account-control]] checks (`reg query HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA`).

Bypassing command-line logging — when 4688/Sysmon-1 with `CommandLine` is on, swap `net user`, `sc query`, and `schtasks` for COM equivalents that never appear as separate processes: instantiate `WScript.Network` (hostname/username/domain), `Shell.Application` (drives, namespace), and `Schedule.Service` (`.Connect()` + `.GetFolder("\\").GetTasks(0)`) from inside an existing PowerShell/beacon. Domain recon over a SOCKS-proxied `rpcclient` from your attacker host (`enumdomusers`, `querydispinfo`, `lsaquery`) leaves zero command-line evidence on the target — only an SMB null/auth session in 4624 logs.

## Detection and defence
- Burst of read-only registry / WMI / `net` commands within seconds of logon — Sysmon event 1 sequence detection
- Hits on `findstr password`, `cmdkey /list`, `vssadmin list shadows` — high-signal
- Disable cmd.exe / Powershell for non-admin users; enforce Constrained Language Mode + AMSI; enable PS Script Block Logging (event 4104)
- Remove sensitive cleartext from unattend.xml, web.config, scheduled-task arguments
- Honeyfiles in `%USERPROFILE%\Documents\passwords.txt` trip a canary on read

## References
- [HackTricks — Windows local privesc index](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/index.html) — exhaustive checklist
- [PEASS-ng / WinPEAS](https://github.com/peass-ng/PEASS-ng/tree/master/winPEAS) — canonical auto-enum tool
- [Seatbelt](https://github.com/GhostPack/Seatbelt) — Windows host situational-awareness collector
- [ired.team — Enumeration and Discovery](https://www.ired.team/offensive-security/enumeration-and-discovery) — COM-based hostname/user/domain enumeration and command-line logging bypass via rpcclient over SOCKS
