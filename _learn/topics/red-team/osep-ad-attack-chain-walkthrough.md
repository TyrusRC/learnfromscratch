---
title: OSEP AD attack chain walkthrough
slug: osep-ad-attack-chain-walkthrough
aliases: [osep-ad-chain, pen300-ad-walkthrough]
---

> **TL;DR:** A composite, lab-flavoured walkthrough of an OSEP-style Active Directory attack chain: phish a low-priv user, neutralize [[amsi-bypass]] and [[etw-bypass]], enumerate quietly with [[bloodhound]], pick the right Kerberos abuse ([[kerberoasting]], [[asreproast]], [[constrained-delegation]], [[resource-based-constrained-delegation]], [[s4u2self-abuse]]), hop through MSSQL trusts, dump NTDS via VSS, and seal persistence with a golden ticket. Pair with [[osep-exam-strategy-and-pacing]], [[osep-payload-development-toolkit]], [[active-directory]] and [[dcsync]]. This note is written from public PEN-300 syllabus knowledge — no exam content.

## Why it matters

PEN-300 / OSEP doesn't reward novel zero-days; it rewards a clean, repeatable chain across a hardened-ish AD environment. Most candidates fail not because they can't kerberoast, but because they:

- Trip AMSI / Defender on the first payload and burn the foothold.
- Run `SharpHound -c All` against a domain with LDAP signing alarms and get sandboxed.
- Find a constrained-delegation primitive and forget how to actually pivot through it.
- Reach a DC and don't have a calm NTDS extraction routine.

This walkthrough is the mental model you should be able to narrate in your sleep before sitting the exam. Treat it as scaffolding — the exam network will deviate, and your job is to know which decision points still apply.

## Stage 0 — Footprint and goals

Before any payload moves, write down:

- Domain name, forest, child domains (if any), known DCs.
- Initial credentials or phish target.
- Out-of-scope hosts (jump host, mail server in some labs).
- "Win condition" — usually low-priv shell + domain-admin equivalent + flag on DC.

Map this to your [[oscp-style-box-attack-pattern]] muscle memory but with a forest-wide mindset. See [[active-directory]] for the object model you're operating on.

## Stage 1 — Initial access via phishing

The lab usually hands you a client-side vector: a macro doc, an HTA, or a signed installer that "phones home" to a controlled callback. See [[client-side-attacks-primer]], [[office-vba-macros-initial-access]], [[jscript-hta-wsh-initial-access]].

Decision points:

- **Delivery channel.** Email-attached doc vs. SMB share vs. hosted download. Pick the one with the simplest user story.
- **Macro vs. HTA vs. signed binary.** Macros require macro-enabled Office; HTAs bypass mark-of-the-web in older builds; signed binaries dodge SmartScreen if you have a code-signing cert in the lab.
- **First-stage payload.** Keep it tiny — a shellcode loader that pulls stage-2 from your C2 ([[c2-frameworks]], [[sliver-c2-deep]], [[havoc-c2-deep]], [[mythic-framework-deep]]).

Common landing: a low-priv user (`alice`) on `WS01` with Defender enabled and AppLocker in audit mode.

## Stage 2 — AMSI / ETW disable + payload execution

Before any PowerShell or .NET tradecraft, neuter telemetry. This is bread-and-butter OSEP.

- **AMSI**: patch `AmsiScanBuffer` in-process, or hijack the provider COM ID. See [[amsi-bypass]] and [[amsi-providers-tampering]].
- **ETW**: patch `EtwEventWrite` / `NtTraceEvent` stub. See [[etw-bypass]].
- **WLDP** if you're running unsigned dynamic code under CLM. See [[wldp-bypass]].
- **Unhook user-mode EDR** if a vendor agent is present — [[edr-hooks-and-unhooking]], [[syscall-direct-and-indirect]].

OSEP graders explicitly want to see you bypass AMSI rather than rely on string mangling, so structure your loader so AMSI is patched before any sensitive content lands. Cross-reference [[osep-payload-development-toolkit]] for the templates.

If AppLocker is enforcing, see [[applocker-bypass-techniques]] for the LOLBin trick that fits the lab (usually `InstallUtil`, `MSBuild`, or a signed-DLL side-load via [[dll-side-loading]]).

## Stage 3 — Local enumeration, quietly

Once stage-2 is running as `alice`, do **not** spray `SharpHound -c All` immediately. Start narrow:

- `whoami /all` — groups, privileges, integrity level.
- `systeminfo` — patch level, AV signature dates.
- `net user /domain alice`, `net group "Domain Admins" /domain` — sanity check.
- Local creds: `cmdkey /list`, `vaultcmd /listcreds:"Windows Credentials"`, scheduled-task XMLs in `C:\Windows\System32\Tasks`.

If you can write to `HKCU` of another user via runas-elevation later, note it. If you find a `.kdbx`, exfil and crack offline; don't try to brute on host.

## Stage 4 — BloodHound collection without tripping alarms

Default SharpHound collection is loud. The lab usually has:

- LDAP signing required (so unauthenticated LDAP probes fail).
- Auditing on `4662` / `5145` for "interesting" objects.
- A canary OU or a fake `svc_backup` account.

Tradecraft:

- Use `--CollectionMethods DCOnly` first. It's pure LDAP, no SMB sessions, no local-admin checks — far quieter. See [[bloodhound]].
- Run from your foothold under `alice`'s token; don't spawn a new logon session.
- Avoid `Session` and `LoggedOn` until you actually need them. They generate SMB `IPC$` connections to every host.
- Jitter the collection: `--Throttle 1000 --Jitter 50`.
- Avoid the canary account in any path you plan to take.

Once the JSON is offline in your Neo4j, look for:

- Shortest paths from `alice` to `Domain Admins`.
- Kerberoastable users (`HasSPN`).
- AS-REP-roastable users (`DontReqPreAuth`).
- Constrained / RBCD delegation edges.
- `GenericAll`, `GenericWrite`, `WriteDACL`, `WriteOwner` over interesting principals.
- MSSQL service accounts and `AllowedToAct` edges.

## Stage 5 — Kerberos abuses

### Kerberoasting

If a service account like `svc_sql` has an SPN and a weak password, request its TGS and crack offline. See [[kerberoasting]]. In modern labs the password is AES-256 only, so request the etype you can crack (`Get-DomainSPNTicket -Identity svc_sql -OutputFormat hashcat`). Hashcat `-m 19700` for AES-256 if etype downgrade is blocked.

Decision: if cracking is slow, move on and revisit — don't burn 4 hours on one hash.

### AS-REPRoasting

Look for users with `DONT_REQ_PREAUTH`. Request AS-REP, crack offline. See [[asreproast]]. Often the lab seeds one obviously-weak account (`helpdesk`, `intern`) to teach the technique.

### Constrained delegation

If `svc_web` has `msDS-AllowedToDelegateTo` populated for `CIFS/FILE01`, and you control `svc_web`'s TGT (because you kerberoasted it), you can S4U2Self + S4U2Proxy to impersonate any user to `FILE01\CIFS`. See [[constrained-delegation]] and [[s4u2self-abuse]].

Tooling: Rubeus `s4u /user:svc_web /rc4:<hash> /impersonateuser:administrator /msdsspn:cifs/file01 /ptt`.

### Resource-based constrained delegation

If you have `GenericWrite` on a computer object (say `FILE01$`), write a fake msDS-AllowedToActOnBehalfOfOtherIdentity pointing at a computer account you control (or create one — `MachineAccountQuota` default of 10). Then S4U yourself as `administrator` against `FILE01`. See [[resource-based-constrained-delegation]].

This is the OSEP-favourite path because `MachineAccountQuota` is almost always non-zero.

## Stage 6 — MSSQL trust hops

The lab often gives you a linked-server chain: `SQL01` -> `SQL02` -> `SQL-DC`. Steps:

- Find SQL with `Get-SQLInstanceDomain` (PowerUpSQL).
- `Get-SQLServerLink -Instance SQL01` — enumerate links.
- `Get-SQLServerLinkCrawl` to recursively walk linked servers as the linked login.
- On the terminal hop, if `xp_cmdshell` is allowed or you have `IMPERSONATE` for `sa`, you have RCE as the SQL service account.

If the SQL service account is `svc_sql` and is in a privileged group on another host (e.g. local admin on `FILE01` via group policy preferences), you've just laterally moved without touching SMB.

## Stage 7 — Lateral movement to fileserver / DC

By now you should have at least one of:

- A high-priv user's TGT in memory via S4U abuse.
- An MSSQL chain that lands you SYSTEM on a host.
- A domain admin credential from a misconfigured GPO or scheduled task.

Lateral options in order of stealth:

1. **WMI** with explicit creds (`Invoke-WmiMethod` or `wmiexec.py` over Kerberos).
2. **WinRM** (`Enter-PSSession`) — clean if PSRemoting is allowed.
3. **DCOM** (`MMC20.Application`, `ShellWindows`) — quieter than PsExec.
4. **SMB / PsExec** — last resort, very loud.

See [[process-injection-techniques]] if you need to land inside another session rather than spawn a new one. Use [[parent-pid-spoofing]] and [[com-hijacking]] for persistence-aware tradecraft.

## Stage 8 — Dumping NTDS via volume shadow copy

Once you're SYSTEM on a DC (or have DA equivalent), the canonical NTDS extraction:

```cmd
vssadmin create shadow /for=C:
copy \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy<N>\Windows\NTDS\NTDS.dit C:\Temp\
reg save HKLM\SYSTEM C:\Temp\SYSTEM
vssadmin delete shadows /for=C: /quiet
```

Then offline:

```bash
secretsdump.py -ntds NTDS.dit -system SYSTEM LOCAL
```

Alternative: [[dcsync]] from any principal with `DS-Replication-Get-Changes` + `DS-Replication-Get-Changes-All`. `secretsdump.py -just-dc DOMAIN/user@dc` is one line and doesn't touch disk on the DC.

VSS is the textbook OSEP answer because it's loud-but-documented; DCSync is quieter but assumes the right ACL.

## Stage 9 — Golden ticket persistence

With the `krbtgt` NT hash from NTDS:

```text
mimikatz # kerberos::golden /user:Administrator /domain:lab.local /sid:S-1-5-21-... /krbtgt:<hash> /ptt
```

You can now mint TGTs for any user for ~10 years. Use sparingly — golden tickets are the canonical "I have the domain" demonstration, but log on every DC's KDC. For exam reporting you want one clean golden-ticket logon as evidence and then move on.

See [[active-directory]] for the SID structure and [[dcsync]] for the alternative persistence using a service-account ACL.

## Defensive baseline

Even though OSEP is offensive, expect the defensive baseline so you know what's likely turned on:

- Defender + AMSI on workstations.
- LDAP signing + channel binding required.
- LAPS on workstations (so local-admin reuse is dead).
- Protected Users / Authentication Silos for tier-0 accounts.
- KRBTGT rotated every 180 days (golden ticket has a shelf life).
- ADCS in ESC1-hardened mode (don't expect ESC1 freebies on the exam — see [[adcs-attacks]] for the few that survive).
- NTLM relaying blocked by EPA / SMB signing — see [[ntlm-relay-ws2025-mitigations]].

If a primitive looks "too easy", check whether you're inside a honeypot OU first.

## Workflow to study

1. Build a lab: one DC, two member servers (one with MSSQL), two workstations. Use the BadBlood seeder for noise.
2. Rehearse the chain end-to-end three times with different starting users.
3. Practise AMSI/ETW patching from C# and PowerShell — see [[osep-payload-development-toolkit]].
4. Drill S4U2Self + S4U2Proxy until you can do it without notes.
5. Time yourself dumping NTDS via VSS, DCSync, and `ntdsutil ifm` — each under 5 minutes.
6. Write a one-page chain diagram and narrate it out loud. If you stumble, that's the weak link to drill.

## Related

- [[osep-exam-strategy-and-pacing]]
- [[osep-payload-development-toolkit]]
- [[osep-roadmap]]
- [[active-directory]]
- [[bloodhound]]
- [[kerberoasting]]
- [[asreproast]]
- [[constrained-delegation]]
- [[resource-based-constrained-delegation]]
- [[s4u2self-abuse]]
- [[dcsync]]
- [[adcs-attacks]]
- [[amsi-bypass]]
- [[etw-bypass]]
- [[applocker-bypass-techniques]]
- [[ntlm-relay-ws2025-mitigations]]

## References

- https://www.offsec.com/courses/pen-300/
- https://bloodhound.specterops.io/
- https://github.com/GhostPack/Rubeus
- https://github.com/NetSPI/PowerUpSQL
- https://specterops.io/wp-content/uploads/sites/3/2022/06/an_ace_up_the_sleeve.pdf
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/ntds-dit
