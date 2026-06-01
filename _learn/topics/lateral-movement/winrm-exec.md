---
title: WinRM exec
slug: winrm-exec
---

> **TL;DR:** PowerShell Remoting over WinRM (5985/HTTP, 5986/HTTPS) gives a clean interactive shell, full PowerShell pipeline, and no service-install footprint — the lowest-noise lateral exec when the port is open and the user is in the right group.

## What it is
WinRM is Microsoft's WS-Management implementation. PowerShell Remoting (`Enter-PSSession`, `Invoke-Command`) and tools like `evil-winrm` ride it to run code as the authenticated user on the remote host. Unlike [[smb-exec]] and [[psexec-family]] there is no service create, no `ADMIN$` write, and no 7045 — just HTTP(S) with WSMan SOAP. That makes it the preferred path when defenders are watching SMB and EDR is service-create-aware.

## Preconditions / where it applies
- Target listening on 5985 (HTTP) or 5986 (HTTPS) — defaults if WinRM is enabled (servers post-2012, DCs, Exchange).
- Account is a member of `Remote Management Users` or local Administrators (Administrators by default).
- For non-domain auth: `TrustedHosts` configured or HTTPS with cert auth.
- Credentials: password, NT hash (`evil-winrm -H`), or Kerberos ticket.

## Technique
PowerShell-native:

```powershell
$cred = Get-Credential corp\alice
Enter-PSSession -ComputerName srv01 -Credential $cred
# or scripted, one-shot
Invoke-Command -ComputerName srv01 -Credential $cred -ScriptBlock { whoami; hostname }
```

`evil-winrm` from Linux (hash auth, file upload, AMSI bypass helpers):

```
evil-winrm -i 10.0.0.5 -u alice -H <NThash>
*Evil-WinRM* PS> upload local.ps1 C:\Windows\Temp\x.ps1
*Evil-WinRM* PS> .\x.ps1
```

Impacket alternative for scripted batches: `wmiexec.py -shell-type powershell` is similar in shape but uses WMI; for actual WinRM use `pypsrp` or `crackmapexec winrm`. `nxc winrm <subnet> -u user -H hash` is the fastest sweep.

Forensic correlation gap worth knowing: the `Microsoft-Windows-WinRM/Operational` log on the source records an `ActivityID` GUID that matches the `ShellID` written to the remote `wsmprovhost.exe` shell logs — a hunter joining those two fields can pin source-to-target across an entire estate even when source IPs are NATed. `Invoke-Command -Authentication Kerberos -SessionOption (New-PSSessionOption -NoMachineProfile)` skips loading the user profile on the target (no `C:\Users\<acct>` directory created), shaving an obvious filesystem artefact that defenders triage after suspected WinRM abuse.

## Detection and defence
- Event log `Microsoft-Windows-WinRM/Operational` 91/142/161 — session create from remote IP.
- 4624 logon type 3 with `LogonProcessName=Kerberos|NTLM` and `ProcessName=…\wsmprovhost.exe` — WinRM session host.
- `wsmprovhost.exe` spawning `powershell.exe` / `cmd.exe` (Sysmon EID 1) is the canonical chain.
- Defences: scope WinRM to management subnets, require HTTPS + cert auth, restrict `Remote Management Users` membership, enable PowerShell ScriptBlock logging (EID 4104) and module logging.

## References
- [PowerShell Remoting docs — Microsoft](https://learn.microsoft.com/en-us/powershell/scripting/learn/remoting/running-remote-commands) — protocol + config.
- [evil-winrm](https://github.com/Hackplayers/evil-winrm) — features and hash-auth syntax.
- [WinRM lateral movement — HackTricks](https://book.hacktricks.wiki/en/network-services-pentesting/5985-5986-pentesting-winrm.html) — operator notes.
- [ired.team — WinRM for lateral movement](https://www.ired.team/offensive-security/lateral-movement/t1028-winrm-for-lateral-movement) — `ActivityID`/`ShellID` correlation and 4648 source-side telemetry.
