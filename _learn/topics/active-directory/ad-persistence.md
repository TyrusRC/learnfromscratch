---
title: AD persistence
slug: ad-persistence
---

> **TL;DR:** Once you own the domain, plant primitives that survive password resets and tier-0 cleanups: AdminSDHolder ACEs, DCShadow object writes, Skeleton Key, golden/silver tickets, certificate persistence, and backdoor SPNs.

## What it is
Persistence in AD is about keeping privileged authentication available even after blue team rotates credentials, resets DA passwords, or removes group memberships. The strongest primitives bury themselves in normally-trusted plumbing: the SDProp template (AdminSDHolder), replication (DCShadow), the LSASS auth chain (Skeleton Key), the KDC's signing keys ([[golden-tickets]]) or per-service keys ([[silver-tickets]]), and certificate-based identity ([[shadow-credentials]] + [[adcs-attacks]]).

## Preconditions / where it applies
- Domain Admin or equivalent — most primitives below need SYSTEM on a DC or `Replicating Directory Changes` rights.
- Some (Skeleton Key, DSRM, DCShadow) require code execution on a DC; others (AdminSDHolder ACE, cert-based) only need authenticated LDAP from anywhere.
- Forest-level persistence (e.g. krbtgt forge against a child) needs awareness of [[child-to-forest-root|SID History abuse]].

## Technique
A toolkit, not a single technique. Pair more than one — defenders rarely catch them all.

- **AdminSDHolder ACE:** add a FullControl ACE on `CN=AdminSDHolder,CN=System,DC=corp`. Every 60 min SDProp re-applies it to protected groups (DAs, EAs, Schema Admins). Removal requires fixing the template *and* every protected object.
  ```bash
  dacledit.py -action write -principal me -rights FullControl \
    -target-dn "CN=AdminSDHolder,CN=System,DC=corp,DC=lab" corp/da:'pw'@dc
  ```
- **DCShadow:** register a rogue DC via `mimikatz lsadump::dcshadow`, push arbitrary attribute changes (SID History, primaryGroupID 512, msDS-KeyCredentialLink). Replication accepts them as if they came from a real DC, then the rogue DC unregisters.
- **Skeleton Key:** `mimikatz misc::skeleton` patches LSASS on a DC so every account accepts a single master password (`mimikatz` by default) in addition to its real one. Lives until the DC reboots.
- **Golden ticket:** offline-forge a TGT with the krbtgt hash. Survives DA password resets; killed only by *two* krbtgt rotations 10 hours apart. See [[golden-tickets]].
- **Silver ticket:** forge a service ticket with a service account hash — no DC traffic at use time. See [[silver-tickets]].
- **DSRM backdoor:** flip `DsrmAdminLogonBehavior=2` on a DC and pass-the-hash with the DSRM password — local admin to the DC over the network.
- **Certificate persistence:** enroll a long-lived (10-year) client-auth cert for a DA via [[adcs-attacks|AD CS]] or write `msDS-KeyCredentialLink` ([[shadow-credentials]]). Password resets do not revoke certs.
- **Backdoor SPNs:** add a kerberoastable SPN to a privileged account; come back later to kerberoast a known weak password you planted.
- **Group nesting:** add a stale-looking group ("Print Operators") nested 3 levels into Domain Admins.

Combine: AdminSDHolder ACE grants WriteDACL; WriteDACL on a tier-0 user lets you re-plant `msDS-KeyCredentialLink` whenever blue removes it.

For the AdminSDHolder ACE, PowerView's `Add-ObjectAcl -TargetADSprefix 'CN=AdminSDHolder,CN=System' -PrincipalSamAccountName me -Rights All` is the canonical one-liner. You do not have to wait the full hour for SDProp to fan out — connecting to a DC with `ldp.exe`, binding as a privileged user, and rewriting `CN=AdminSDHolder` directly will kick SDProp on the next inspection cycle (or you can trigger it by calling `FixUpInheritance` via `RootDSE`). Verify reach after propagation with `Get-ObjectAcl -SamAccountName 'Domain Admins' -ResolveGUIDs | ? IdentityReference -match me` — the backdoor works without you ever being a DA group member, which is the whole point.

## Detection and defence
- Monitor 4662 events on AdminSDHolder, the domain head, and `CN=Configuration` (DCShadow registers there).
- Alert on 4742 (computer object modified) for objects added/removed quickly — DCShadow's signature.
- Rotate krbtgt twice with a 10h gap on incident response; treat any DA compromise as needing this.
- Strict-mapping AD CS (KB5014754) + audit `msDS-KeyCredentialLink` writes.
- Disable WDigest + LSASS Protected Process Light + Credential Guard to block Skeleton Key class attacks.
- Periodically diff DACLs of protected objects against a known-good snapshot.

## References
- [SpecterOps — Designing AD DACL Backdoors](https://posts.specterops.io/an-ace-up-the-sleeve-designing-active-directory-dacl-backdoors-925f86a1d3f8) — AdminSDHolder ACE strategy
- [HarmJ0y — DCShadow](https://www.dcshadow.com/) — original write-up
- [HackTricks — AD persistence](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/index.html) — primitive catalogue
- [the.hacker.recipes — Persistence](https://www.thehacker.recipes/ad/persistence) — categorised techniques
- [ired.team — Backdooring AdminSDHolder](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/how-to-abuse-and-backdoor-adminsdholder-to-obtain-domain-admin-persistence) — Add-ObjectAcl + SDProp timing walkthrough
