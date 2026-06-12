---
title: PSExec family
slug: psexec-family
---

> **TL;DR:** Sysinternals PSExec and its descendants (paexec, csexec, impacket-psexec, smbexec, wmiexec) all do "auth to SMB → drop binary → start a service → return a shell" with different tradeoffs in stealth, output capture, and dependencies.

## What it is
PSExec popularised the SMB-service-create lateral pattern: connect to `\\target\ADMIN$`, upload a service binary, create + start a service via `svcctl` over named pipes, attach to stdin/stdout pipes for an interactive shell, then clean up. Variants tweak the recipe — different binary names, no on-disk drop, different output channels — but the core primitive is identical and detection follows the same shape. See [[smb-exec]] for the lower-level mechanics and [[wmi-exec]] / [[dcom-exec]] / [[winrm-exec]] for non-service alternatives.

## Preconditions / where it applies
- Local admin on the target (required to create services).
- SMB (445/tcp) reachable; `ADMIN$` share enabled (default).
- An NTLM hash, Kerberos ticket, or password for an admin-equivalent account.
- File-and-printer-sharing firewall rule allowed inbound.

## Technique
Tool selection cheat sheet:

| Tool | Drops binary | Output channel | Notes |
|---|---|---|---|
| `PsExec.exe` (Sysinternals) | yes (`PSEXESVC.exe`) | named pipe | signed, EULA prompt unless `-accepteula` |
| `paexec` | yes (random name) | named pipe | open-source PsExec clone |
| `csexec` | yes | named pipe | C# rewrite, supports Kerberos |
| `impacket-psexec` | yes (`RemComSvc`) | SMB named pipe | hash/ticket auth out of the box |
| `impacket-smbexec` | **no** | semi-interactive via temp file on share | noisier on share, no service binary on disk |
| `impacket-wmiexec` | **no** | WMI `Win32_Process` + admin share read | no service at all, blends with WMI noise |
| `impacket-atexec` | **no** | scheduled task + share read | works when service create is blocked |

Canonical Impacket call:

```
psexec.py -hashes :<NThash> corp/admin@10.0.0.5
# kerberos / overpass-the-hash compatible
psexec.py -k -no-pass corp.local/admin@fs01.corp.local
```

For OpSec, prefer `wmiexec` or `dcomexec` over service-create variants — no 7045 event.

## Detection and defence
- 4697 / 7045 (service installed) with random-name service binary in `%SystemRoot%` — the loudest PSExec tell.
- 5145 (detailed file share) showing writes to `ADMIN$\<name>.exe` followed by `\PIPE\svcctl`.
- Sysmon EID 1 with parent `services.exe` and image in `%SystemRoot%` matching impacket service-binary signatures (`RemComSvc`, `PSEXESVC`).
- Block remote service creation on workstations; LAPS + tiering; enforce SMB signing; alert on 7045 from non-baseline binaries.

## References
- [PsExec — Sysinternals](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec) — original tool docs.
- [Impacket examples](https://github.com/fortra/impacket/tree/master/examples) — psexec/smbexec/wmiexec/atexec sources.
- [PSExec internals — HackTricks](https://book.hacktricks.wiki/en/windows-hardening/lateral-movement/psexec-and-winexec.html) — service-create walkthrough.

See also: [[smb-exec]], [[wmi-exec]], [[evil-winrm]], [[rmm-tool-abuse-screenconnect-anydesk]], [[sccm-mecm-lateral-movement]]
