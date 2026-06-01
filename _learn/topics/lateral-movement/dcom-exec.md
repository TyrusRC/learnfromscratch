---
title: DCOM exec
slug: dcom-exec
---

> **TL;DR:** Abuse exposed COM objects (MMC20.Application, ShellWindows, ShellBrowserWindow, Excel DDE) over DCOM to launch processes remotely as the calling user — no service install, no PSExec footprint.

## What it is
Distributed COM lets a client invoke methods on COM objects hosted on a remote machine via RPC. A handful of COM classes expose methods that ultimately call `ShellExecute` / `CreateProcess`. With local admin on the target, DCOM activation runs the chosen command on the remote host under the invoking account, without dropping a service binary or touching `\\PIPE\svcctl` like [[psexec-family]] does.

## Preconditions / where it applies
- Local administrator privileges on the target (DCOM launch/activation ACLs default to admins).
- TCP 135 (RPC endpoint mapper) plus the dynamic high-port RPC range reachable.
- Target running a Windows version with the abused ProgID registered (Office DCOM objects require Office installed).
- Firewall profile allowing DCOM — many hardened boxes scope 135 to management VLANs only.

## Technique
Instantiate the remote object and call its exec-equivalent method. From PowerShell:

```powershell
$c = [activator]::CreateInstance([type]::GetTypeFromProgID('MMC20.Application','TARGET'))
$c.Document.ActiveView.ExecuteShellCommand('cmd.exe',$null,'/c calc.exe','7')
```

ShellWindows / ShellBrowserWindow variants (no Office dependency):

```powershell
$h = [type]::GetTypeFromCLSID('9BA05972-F6A8-11CF-A442-00A0C90A8F39','TARGET')
$o = [activator]::CreateInstance($h)
$o.Item().Document.Application.ShellExecute('cmd.exe','/c whoami > C:\out','C:\Windows\System32',$null,0)
```

Impacket equivalent: `dcomexec.py -object MMC20 dom/user:pass@target 'cmd /c ...'`. Output capture works by writing to an admin share and reading back, since the COM call itself returns nothing useful. Excel `DDEInitiate` is the third common variant but requires Office.

## Detection and defence
- Event 4624 logon type 3 from the operator, immediately followed by a child process under `mmc.exe`, `explorer.exe`, or `excel.exe` whose parent chain is unusual (no interactive shell).
- Sysmon EID 1 with parent `mmc.exe` spawning `cmd.exe` / `powershell.exe` is the canonical DCOM-exec tell.
- Restrict DCOM launch permissions via `DComCnfg` or `HKLM\Software\Classes\AppID\{CLSID}` ACLs; block TCP 135 + high RPC ports from workstation VLANs.
- Attack-surface-reduction rule "Block Office applications from creating child processes" kills the Excel-DDE variant.

## References
- [Lateral Movement using the MMC20.Application COM Object — Enigma0x3](https://enigma0x3.net/2017/01/05/lateral-movement-using-the-mmc20-application-com-object/) — original DCOM lateral exec writeup.
- [Lateral Movement via DCOM — HackTricks](https://book.hacktricks.wiki/en/windows-hardening/lateral-movement/dcom-exec.html) — ProgID/CLSID catalogue.
- [ired.team — DCOM Lateral Movement](https://www.ired.team/offensive-security/lateral-movement/t1175-distributed-component-object-model) — ShellWindows/ShellBrowserWindow recipes.
