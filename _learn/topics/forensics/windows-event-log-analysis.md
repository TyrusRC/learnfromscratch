---
title: Windows event log analysis
slug: windows-event-log-analysis
---

> **TL;DR:** `%SystemRoot%\System32\winevt\Logs\*.evtx` records authentication, process creation, service install, scheduled tasks, PowerShell, WMI, and RDP events — knowing which Event ID lives in which channel turns "find lateral movement" into a series of single-shot `wevtutil`/`Get-WinEvent`/`EvtxECmd` queries.

## What it is
Modern Windows ships a structured XML-based event log (EVTX, since Vista). Logs are split into many *channels* (e.g., `Security`, `System`, `Application`, `Microsoft-Windows-PowerShell/Operational`). Most useful security-relevant events live across half a dozen channels — knowing which channel and Event ID covers which activity is the difference between hours and minutes of triage.

## Preconditions / where it applies
- DFIR on a Windows host, live or from a triage image.
- A defender's playbook; many IDs also appear in red-team OPSEC checks ("did my action generate event X?").

## Technique
**1. Where the logs live.**
- Live: `C:\Windows\System32\winevt\Logs\<Channel>.evtx`
- Triage: pull this directory; parse offline with **EvtxECmd** (Eric Zimmerman), **Velociraptor**, **Plaso**, **chainsaw**, or Python `python-evtx`.

**2. The "always check first" Event IDs.**

| Channel | ID | Why it matters |
|---|---|---|
| Security | 4624 | Successful logon. Field `LogonType` (3 = network, 10 = RDP / RemoteInteractive, 2 = interactive, 9 = NewCredentials runas /netonly) is gold for lateral-movement reconstruction. |
| Security | 4625 | Failed logon. Brute force, password spraying. |
| Security | 4634 / 4647 | Logoff / user-initiated logoff. |
| Security | 4648 | Logon using explicit credentials (`runas /netonly`, `mimikatz sekurlsa::pth`). |
| Security | 4672 | Special privileges assigned at logon → admin session. |
| Security | 4688 | Process creation. Requires audit policy + `Include command line in process creation events` enabled. |
| Security | 4697 | Service installed. Classic [[psexec-family|PsExec]] artefact. |
| Security | 4698 / 4702 | Scheduled task created / updated; see [[scheduled-tasks-forensics]]. |
| Security | 4720 / 4732 | User created / added to Administrators. |
| Security | 4768 / 4769 | Kerberos AS-REQ / TGS-REQ on the **DC**. Encryption type 0x17 = RC4 → kerberoast/AS-REP candidates. |
| Security | 5140 / 5145 | Network share access / detailed share access — file-server lateral movement. |
| System | 7045 | New service installed (Service Control Manager view). |
| System | 7036 | Service state change — paired with 7045. |
| Microsoft-Windows-PowerShell/Operational | 4103 | PowerShell module logging — every cmdlet + parameters. |
| Microsoft-Windows-PowerShell/Operational | 4104 | Script block logging — full script source after deobfuscation. Most powerful single ID for offensive PowerShell. |
| Microsoft-Windows-WMI-Activity/Operational | 5857–5861 | WMI provider activity; catches [[wmi-exec]] and WMI event subscriptions ([[wmi-event-subscription-persistence]]). |
| Microsoft-Windows-TerminalServices-LocalSessionManager/Operational | 21 / 24 / 25 | RDP session connect / disconnect / reconnect with source IP. |
| Microsoft-Windows-TaskScheduler/Operational | 106 / 140 / 141 | Task registered / updated / deleted. |
| Microsoft-Windows-Sysmon/Operational | 1, 3, 7, 8, 10, 11, 13 | If Sysmon is installed: process create, network, image load, CreateRemoteThread, ProcessAccess, FileCreate, RegSetValue. |

**3. Query templates.**

```powershell
# All 4688s with command line in the last 24 hours
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4688; StartTime=(Get-Date).AddDays(-1)} |
  ForEach-Object { [pscustomobject]@{Time=$_.TimeCreated; CmdLine=$_.Properties[8].Value; Parent=$_.Properties[13].Value} }

# Every 4624 LogonType 10 (RDP) to this host
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4624} |
  Where-Object { $_.Properties[8].Value -eq 10 }

# PowerShell script blocks containing "Invoke-Mimikatz" anywhere
Get-WinEvent -LogName 'Microsoft-Windows-PowerShell/Operational' -FilterXPath "*[System[EventID=4104]]" |
  Where-Object { $_.Message -match 'Mimikatz|sekurlsa|Invoke-Kerberoast' }
```

```bash
# Offline with EvtxECmd
EvtxECmd.exe -d C:\triage\Logs --csv out/ --csvf events.csv
chainsaw hunt -s rules/sigma -m evtx C:\triage\Logs   # Sigma rule sweep
```

**4. Correlation patterns.**
- **PsExec → SMB → service:** 5140 on file server, then 7045 + 4697 + 4688 (parent `services.exe`, image in `\\$ADMIN`).
- **WMI exec:** 4624 type 3 → WMI-Activity 5857 → 4688 child of `WmiPrvSE.exe`.
- **Pass-the-hash:** 4624 type 9 (`runas /netonly`) followed by 4624 type 3 elsewhere with the impersonated account.
- **Kerberoast:** burst of 4769s for non-machine SPNs with `Ticket Encryption Type 0x17` (RC4).
- **Living-off-the-land:** 4104 with obfuscated PowerShell (high entropy, base64), or 4688 with LOLBAS binaries (`certutil`, `bitsadmin`) — see [[living-off-the-land]] and [[living-off-the-land-binaries-lolbas]].

**5. Anti-forensics signs.**
- `Microsoft-Windows-EventLog` channel 1102 — "Audit log was cleared" — usually attacker noise.
- Logs missing entire time windows but file `LastWriteTime` updated → selective clearing via WMI or `wevtutil cl <channel>`.
- 4624s with very short session lengths and immediate 4634s → token-stealing tools.

## Detection and defence
- Enable **command-line auditing** (`Include command line in process creation events` GPO) and **PowerShell script block logging** + **module logging** — both make 4688 / 4103 / 4104 actually useful.
- Increase log size from the 20 MB default to at least 1 GB on the Security channel.
- Forward to a SIEM via WEF (Windows Event Forwarding) so local log clearing doesn't destroy evidence.
- Pair with [[shimcache-amcache]], [[prefetch-analysis]], and registry timeline ([[registry-hive-forensics]]) for execution evidence outside the event log.

## References
- [Microsoft — Audit policy recommendations](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/audit-policy-recommendations) — official baseline
- [SANS — Hunt Evil poster](https://www.sans.org/security-resources/posters/) — Event ID quick reference
- [EvtxECmd](https://ericzimmerman.github.io/) — Eric Zimmerman parser
- [Chainsaw](https://github.com/WithSecureLabs/chainsaw) — fast Sigma-driven EVTX hunting

See also: [[hayabusa-windows-event-log-triage]], [[chainsaw-evtx-hunting]], [[kape-triage-collection]], [[velociraptor-threat-hunting]], [[sigma-rules-detection-as-code]]
