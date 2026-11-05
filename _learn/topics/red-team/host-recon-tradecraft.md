---
title: Host reconnaissance tradecraft
slug: host-recon-tradecraft
aliases: [host-recon, post-compromise-enumeration, situational-awareness]
---

> **TL;DR:** After landing on a host, enumerate before acting — installed software, privileges, credentials, network state, defences. Use in-memory tools (Seatbelt, SharpUp, BOFs) to collect situational awareness without writing to disk or spawning noisy processes.

## What it is
Host reconnaissance is the first post-compromise phase: understanding what you've landed on, what privileges you have, what defences are running, and what paths exist to escalate or pivot. Good recon determines every subsequent action — skip it and you walk into EDR blind. The tradecraft emphasises low-noise collection: prefer [[bof-cobalt-strike-development]] and in-memory .NET tools over `cmd.exe` one-liners that trigger command-line logging.

## Preconditions / where it applies
- Initial code execution on a Windows host (user or admin context)
- Beacon, Meterpreter, or other implant providing command execution
- Applies to every engagement — CRTO, CRTP, OSEP all start with host recon after initial access
- The techniques here feed into [[data-hunting-and-exfiltration]] and privilege escalation paths

## Technique

### Seatbelt — comprehensive collection

Seatbelt (GhostPack) is the go-to .NET situational-awareness tool. Run via `execute-assembly` from Cobalt Strike:

```text
# Run all safe checks (no admin required)
execute-assembly /tools/Seatbelt.exe -group=all

# Targeted modules
execute-assembly /tools/Seatbelt.exe AntiVirus          # installed AV/EDR products
execute-assembly /tools/Seatbelt.exe LogonSessions       # current logon sessions
execute-assembly /tools/Seatbelt.exe InterestingFiles     # sensitive files in user dirs
execute-assembly /tools/Seatbelt.exe ChromiumPresence     # browser data locations
execute-assembly /tools/Seatbelt.exe WindowsCredentialFiles # DPAPI credential blobs
execute-assembly /tools/Seatbelt.exe MappedDrives         # network drive mappings
execute-assembly /tools/Seatbelt.exe ScheduledTasks       # non-Microsoft scheduled tasks
execute-assembly /tools/Seatbelt.exe InstalledProducts    # installed software (WMI)
execute-assembly /tools/Seatbelt.exe ProcessOwners        # which users own which processes
```

Key Seatbelt groups: `user` (non-admin user checks), `system` (requires admin), `slack` (Slack workspace data), `chrome` (Chrome data), `remote` (remote system checks).

### SharpUp — privilege escalation checks

```text
# Check for all known privesc vectors
execute-assembly /tools/SharpUp.exe audit

# Specific checks
execute-assembly /tools/SharpUp.exe HijackablePaths       # writable PATH dirs
execute-assembly /tools/SharpUp.exe ModifiableServices     # services with weak permissions
execute-assembly /tools/SharpUp.exe UnquotedServicePaths   # classic unquoted path vuln
execute-assembly /tools/SharpUp.exe AlwaysInstallElevated  # MSI elevation
execute-assembly /tools/SharpUp.exe ModifiableScheduledTasks
```

### Manual enumeration (when tools aren't available)

**Current user and privileges:**

```cmd
whoami /all
net user %username% /domain
net localgroup Administrators
```

```powershell
# Token privileges — look for SeImpersonate, SeDebug, SeBackup
whoami /priv
[System.Security.Principal.WindowsIdentity]::GetCurrent().Groups |
    ForEach-Object { $_.Translate([System.Security.Principal.NTAccount]) }
```

**Installed software:**

```powershell
# Registry-based (faster, no WMI)
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" |
    Select-Object DisplayName, DisplayVersion, Publisher | Sort-Object DisplayName
Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" |
    Select-Object DisplayName, DisplayVersion, Publisher | Sort-Object DisplayName
```

Look for: VPN clients (credential stores), password managers, remote access tools, development tools (Git credentials), database clients.

**AV/EDR detection:**

```powershell
# Check running processes against known AV/EDR process names
Get-Process | Where-Object {
    $_.Name -match 'MsMpEng|csfalcon|cb|CylanceSvc|SentinelAgent|bdservicehost|avp'
}

# WMI query for installed AV (reports to Security Center)
Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct |
    Select-Object displayName, pathToSignedProductExe
```

```text
# Seatbelt BOF alternative (TrustedSec SA BOF)
inline-execute /bofs/antivirusproducts.o
```

**Network state:**

```cmd
ipconfig /all
route print
arp -a
netstat -ano | findstr ESTABLISHED
net use
net share
```

```powershell
# DNS cache — reveals recently resolved internal hostnames
Get-DnsClientCache | Select-Object Entry, Data
# Network connections with process names
Get-NetTCPConnection -State Established |
    Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess,
    @{n='Process';e={(Get-Process -Id $_.OwningProcess).Name}}
```

**Saved credentials:**

```cmd
:: Credential Manager
cmdkey /list

:: WiFi passwords
netsh wlan show profiles
netsh wlan show profile name="SSID" key=clear

:: RDP connection history (recent targets)
reg query "HKCU\Software\Microsoft\Terminal Server Client\Servers"
```

```powershell
# Chrome saved passwords location (decrypt with SharpDPAPI)
Test-Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"

# PuTTY saved sessions (may contain credentials)
reg query "HKCU\Software\SimonTatham\PuTTY\Sessions"

# WinSCP saved passwords (obfuscated, trivially reversible)
reg query "HKCU\Software\Martin Prikryl\WinSCP 2\Sessions"
```

**Scheduled tasks and services:**

```powershell
# Non-Microsoft scheduled tasks (filter noise)
Get-ScheduledTask | Where-Object { $_.Author -notmatch 'Microsoft' -and $_.State -ne 'Disabled' } |
    Select-Object TaskName, TaskPath, @{n='Actions';e={$_.Actions.Execute}}

# Services with non-system accounts (potential credential exposure)
Get-WmiObject Win32_Service | Where-Object {
    $_.StartName -and $_.StartName -notmatch 'LocalSystem|LocalService|NetworkService'
} | Select-Object Name, StartName, PathName, State
```

**Logged-on users:**

```cmd
query user
qwinsta
net session 2>nul
```

```powershell
# Remote logged-on users via NetSessionEnum (requires network access)
# PowerView
Get-NetSession -ComputerName fileserver
Get-NetLoggedon -ComputerName dc01
```

### BOF-based recon (lowest noise)

TrustedSec Situational Awareness BOFs run inline in Beacon — no fork-and-run, no child process:

```text
inline-execute /bofs/whoami.o
inline-execute /bofs/netstat.o
inline-execute /bofs/arp.o
inline-execute /bofs/ipconfig.o
inline-execute /bofs/listdns.o
inline-execute /bofs/nslookup.o dc01.corp.local
inline-execute /bofs/netuser.o administrator /domain
inline-execute /bofs/netLocalGroupListMembers.o Administrators
inline-execute /bofs/schtasksenum.o
inline-execute /bofs/sc_query.o
```

BOFs produce **no Sysmon Event ID 1** (process creation), no command-line logging, no ETW from `cmd.exe`/`powershell.exe`. They are the gold standard for host recon OPSEC.

## Detection and defence
- `execute-assembly` loads the CLR in a sacrificial process — `clrjit.dll` load in `dllhost.exe` or `rundll32.exe` is a high-fidelity signal
- WMI queries for `AntiVirusProduct` are logged in WMI-Activity/Operational
- Mass `cmdkey /list`, `netsh wlan show profile`, registry enumeration in quick succession is anomalous for normal users
- BOFs are harder to detect but Beacon's named-pipe communication for output can be monitored
- Seatbelt's WMI queries generate `Microsoft-Windows-WMI-Activity/Operational` events
- Enable PowerShell ScriptBlock Logging (Event ID 4104) to catch recon cmdlets
- Sysmon Event ID 13 (registry value set/query) logs credential store enumeration patterns

## OPSEC notes
- Run recon **before** escalating — you need to know what defences exist before triggering them
- Batch your questions: one Seatbelt `-group=all` run is quieter than 20 individual commands
- Avoid `net user /domain` from a workstation — it's commonly alerted. Use LDAP queries or BOFs instead
- Never run `ipconfig /all` from `cmd.exe` when you can read the same data from the registry or a BOF
- If Defender is running, patch AMSI before loading Seatbelt — or use unmanaged-code alternatives

## References
- [GhostPack — Seatbelt](https://github.com/GhostPack/Seatbelt)
- [GhostPack — SharpUp](https://github.com/GhostPack/SharpUp)
- [TrustedSec Situational Awareness BOFs](https://github.com/trustedsec/CS-Situational-Awareness-BOF)
- [LOLBAS Project](https://lolbas-project.github.io/) — living-off-the-land techniques
- [ired.team — Credential access](https://www.ired.team/offensive-security/credential-access-and-credential-dumping)

See also: [[cobalt-strike-operations]], [[bof-cobalt-strike-development]], [[data-hunting-and-exfiltration]], [[av-evasion-primer]], [[amsi-bypass]], [[privilege-escalation-windows]], [[lateral-movement-overview]], [[opsec-fundamentals]]
