---
title: Attack Surface Reduction rules and bypasses
slug: asr-rules-and-bypasses
aliases: [ASR rules, ASR bypass, Attack Surface Reduction]
---

> **TL;DR:** ASR rules are Defender-integrated mitigations that block specific attack behaviours (Office macro child processes, credential theft from LSASS, etc.). Each rule has a GUID, can run in audit or block mode, and has known bypasses. Understanding ASR coverage gaps is critical for CRTL and modern red-team engagements against Defender-protected environments.

## What ASR rules are

ASR rules ship with Microsoft Defender for Endpoint and are enforced by the Defender AV engine (not kernel CI). They target specific attack patterns rather than broad application control. Each rule:
- Has a unique GUID
- Operates in **Disabled / Audit / Warn / Block** mode independently
- Is deployed via GPO, Intune, PowerShell, or ConfigMgr
- Generates events in `Microsoft-Windows-Windows Defender/Operational` (Event IDs 1121 block, 1122 audit)

## Key rules and what they block

| GUID | Rule name | What it blocks |
|---|---|---|
| `D4F940AB-401B-4EFC-AADC-AD5F3C50688A` | Block Office apps from creating child processes | cmd, powershell, wscript spawned by Word/Excel/etc. |
| `3B576869-A4EC-4529-8536-B80A7769E899` | Block Office apps from creating executable content | Dropping PE/script to disk from Office |
| `75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84` | Block Office apps from injecting into other processes | `CreateRemoteThread` from Office |
| `92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B` | Block Win32 API calls from Office macros | `VirtualAlloc`, `CreateThread` from VBA |
| `9E6C4E1F-7D60-472F-BA1A-A39EF669E4B2` | Block credential stealing from LSASS | Open-process on lsass.exe |
| `BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550` | Block executable content from email client and webmail | PE drops from Outlook/webmail |
| `D3E037E1-3EB8-44C8-A917-57927947596D` | Block JavaScript or VBScript from launching downloaded content | Downloaded script execution |
| `5BEB7EFE-FD9A-4556-801D-275E5FFC04CC` | Block execution of potentially obfuscated scripts | Heavily encoded PS/JS/VBS |
| `26190899-1602-49E8-8B27-EB1D0A1CE869` | Block Office communication apps from creating child processes | Teams/Outlook spawning processes |
| `7674BA52-37EB-4A4F-A9A1-F0F9A1619A2C` | Block Adobe Reader from creating child processes | Reader spawning cmd/powershell |
| `E6DB77E5-3DF2-4CF1-B95A-636979351E5B` | Block persistence through WMI event subscription | `EventConsumer` creation |
| `56A863A9-875E-4185-98A7-B882C64B5CE5` | Block abuse of exploited vulnerable signed drivers | BYOVD block |

## Querying ASR status

```powershell
# PowerShell — get all ASR rule states
Get-MpPreference | Select-Object -ExpandProperty AttackSurfaceReductionRules_Ids
Get-MpPreference | Select-Object -ExpandProperty AttackSurfaceReductionRules_Actions
# Actions: 0=Disabled, 1=Block, 2=Audit, 6=Warn

# WMI/CIM query
Get-CimInstance -Namespace root\Microsoft\Windows\Defender -ClassName MSFT_MpPreference |
    Select-Object AttackSurfaceReductionRules_Ids, AttackSurfaceReductionRules_Actions

# Intune: check via Graph API
# GET /deviceManagement/deviceConfigurations/{id}/deviceStatuses
```

## Bypass techniques per rule category

### Office child-process block bypass
The rule blocks `cmd.exe`, `powershell.exe`, `mshta.exe` as direct children. Bypasses:
- **WMI process creation** — `Win32_Process.Create()` from VBA spawns under `WmiPrvSE.exe`, not Office
- **Scheduled task creation** — `Schedule.Service` COM object; child runs under `svchost.exe`
- **COM object execution** — `Shell.Application`, `WScript.Shell` via COM may bypass depending on rule version
- **DDE instead of macros** — DDE payloads are not always covered by ASR macro rules

```vba
' WMI spawn — bypasses Office child process rule
Set objWMI = GetObject("winmgmts:\\.\root\cimv2")
Set objProcess = objWMI.Get("Win32_Process")
objProcess.Create "cmd /c whoami > C:\temp\out.txt", Null, Null, pid
```

### LSASS credential theft block bypass
- **Direct syscalls** — ASR hooks user-mode `OpenProcess`; direct `NtOpenProcess` via [[syscall-direct-and-indirect]] bypasses
- **LSASS dump via comsvcs.dll** — `rundll32 comsvcs.dll MiniDump` may not trigger the ASR rule
- **PPL bypass** — If running as SYSTEM, use `MiraclePtr` or duplicate from an existing handle via [[edr-hooks-and-unhooking]]
- **Duplicating handles** — `NtDuplicateObject` from a process already holding an LSASS handle
- **Silent Process Exit** — configure `WerFault.exe` to dump LSASS on crash

### Obfuscated script block bypass
- ASR uses heuristic entropy/pattern checks — restructuring obfuscation to use string concatenation instead of encoded blocks
- Loading scripts via .NET `Assembly.Load()` rather than PowerShell execution
- Compiling to a managed DLL and invoking via `InstallUtil` or `MSBuild`

### WMI persistence block bypass
- ASR blocks `__EventConsumer` creation but not modification of existing subscriptions
- Use scheduled tasks (`schtasks`) or registry run keys instead — different ASR rules may not cover these

## GPO deployment

```
Computer Configuration → Administrative Templates → Windows Components →
  Microsoft Defender Antivirus → Microsoft Defender Exploit Guard →
    Attack Surface Reduction → Configure Attack Surface Reduction rules

# Per-rule GUID = value (0=Disabled, 1=Block, 2=Audit, 6=Warn)
```

**Recommended approach for red teams:** run `Get-MpPreference` first. Many organisations deploy ASR in audit mode only — check `Actions` values. Audit mode logs but does not block.

## Detection and defence

- **Event ID 1121** (block) and **1122** (audit) in Defender Operational log
- Centralise ASR events to SIEM — `ASRAuditBlockRule` table in Defender for Endpoint / Sentinel
- Run all rules in block mode, not audit, for production enforcement
- Pair ASR with [[amsi-bypass]] detection — ASR + AMSI together cover more ground than either alone
- Monitor for WMI-based process creation from Office processes as ASR evasion indicator

## OPSEC pitfalls

- ASR audit events still generate telemetry — even in audit mode, your attempt is logged
- Testing against ASR in a lab? Set rules to block mode; audit mode gives false confidence
- WMI-spawn bypass is well-known; EDR vendors additionally monitor `WmiPrvSE.exe` child processes
- Some ASR rules are "preview" and may change behaviour between Defender updates

## References

- [Microsoft — ASR rules reference](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference)
- [Microsoft — ASR rule GUIDs and descriptions](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-deployment)
- [Optiv — ASR bypass research](https://www.optiv.com/insights)

See also: [[amsi-bypass]], [[edr-hooks-and-unhooking]], [[wdac-policy-bypass]], [[living-off-the-land-binaries-lolbas]], [[office-vba-macros-initial-access]], [[process-injection-techniques]], [[syscall-direct-and-indirect]], [[wmi-event-subscription-persistence]]
