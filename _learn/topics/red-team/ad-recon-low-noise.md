---
title: Low-noise AD recon
slug: ad-recon-low-noise
---

> **TL;DR:** Pull just enough LDAP / SYSVOL data to plan your next move, without lighting up SharpHound-shaped detections or BloodHound CollectionMethod=All log volume.

## What it is
Active Directory enumeration done with restraint. Instead of bulk-collecting every object, you query narrowly, paginate slowly, and prefer protocols and tools that already see traffic on the wire (LDAP from a domain-joined host, ADWS through PowerShell `ActiveDirectory` module, SYSVOL reads over SMB). The goal is to look like a normal authenticated user, not a collection tool.

## Preconditions / where it applies
- Any valid domain user (often that's all LDAP needs)
- A host where your tooling can ride normal auth — domain-joined workstation, jump box, or proxied through a beacon
- Mature targets running Defender for Identity, Falcon Identity Protection, or anything watching for SharpHound-style fan-out

## Technique
Pick the smallest data set you need for the current question. Common low-noise queries:

```
# Just the users, no group recursion. ADWS path.
Get-ADUser -Filter * -Properties servicePrincipalName,description,lastLogonTimestamp

# Kerberoastable accounts in one shot
Get-ADUser -LDAPFilter '(&(servicePrincipalName=*)(!samAccountName=krbtgt))' -Properties servicePrincipalName

# AS-REP roastable
Get-ADUser -LDAPFilter '(&(userAccountControl:1.2.840.113556.1.4.803:=4194304))'
```

Throttle BloodHound collection. `SharpHound --CollectionMethods DCOnly` pulls everything LDAP/SAMR can answer from the DC, skipping per-host RPC sweeps that generate the 4624/4634 storm. `bloodhound-python` over SOCKS speaks LDAP only.

Prefer ADWS via the `ActiveDirectory` module — it blends into normal admin traffic. Avoid SAMR enumeration of every host, SMB null-session sweeps, and `net group "Domain Admins" /domain` from random workstations.

Read SYSVOL directly when you can — GPP cpassword, GPO contents, scripts. SYSVOL traffic is normal.

For BloodHound, scope by OU (`--OU "OU=Servers,DC=corp,DC=local"`) and split runs across days. Cypher the small subgraph you actually need rather than re-collecting.

When you cannot run AD tooling on the foothold host without lighting up command-line telemetry, tunnel `rpcclient` from your own box through a beacon's SOCKS proxy (`socks 7777` in Cobalt Strike, then `proxychains rpcclient <DC> -U user` with `enumdomusers`, `queryuser`, `enumprivs`). The compromised host sees no `net user`, `net group`, or `Get-ADUser` process events — only outbound SMB to the DC from the beacon process, which is far less correlated. The same SOCKS path works for Impacket's `reg.py`, `lookupsid.py`, and a `nmap -sT -Pn` against a narrow port list when full RPC enumeration would be too loud.

## Detection and defence
- Defender for Identity flags reconnaissance: LDAP enumeration of sensitive groups, SAMR enumeration, DNS zone transfer attempts
- The LDAP server channel logs ring buffer flags unusual query volume per principal
- 4662 events with specific GUIDs (DS-Replication-Get-Changes-All, msDS-KeyCredentialLink) catch interesting reads
- Defenders should restrict ms-DS-MachineAccountQuota, tier admin accounts, and alert on LDAP queries from non-admin user contexts touching attribute sets associated with attack tooling

## References
- [BloodHound docs — SharpHound collection methods](https://bloodhound.specterops.io/collectors/sharphound/all-flags) — what each flag actually hits
- [thehacker.recipes — AD recon](https://www.thehacker.recipes/ad/recon) — LDAP filters and tooling
- [SpecterOps blog](https://posts.specterops.io/) — research on quieter collection
- [ired.team — rpcclient via SOCKS to bypass command-line logging](https://www.ired.team/offensive-security/enumeration-and-discovery/enumerating-windows-domains-using-rpcclient-through-socksproxy-bypassing-command-line-logging) — proxychains pattern for silent AD enumeration
- [[opsec-fundamentals]]
