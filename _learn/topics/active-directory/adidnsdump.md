---
title: ADIDNS dump
slug: adidnsdump
---

> **TL;DR:** Any authenticated user can enumerate every DNS record stored inside Active Directory by querying the `DC=DomainDnsZones` LDAP partition — a low-noise alternative to AXFR for internal hostname discovery.

## What it is
When DNS is "AD-integrated", records live as `dnsNode` objects under `CN=MicrosoftDNS,DC=DomainDnsZones,DC=corp,DC=local` (and `ForestDnsZones` for forest-wide zones). By default the zone container grants `List Contents` to Authenticated Users but hides the record data (`dnsRecord` attribute) behind `List Object` mode — so a `subtree` LDAP search returns the object names but not their A/AAAA/SRV blobs. The trick is that the names alone leak inventory, and any record an attacker themselves can read in full (because it lacks an explicit DACL) provides the IP too.

## Preconditions / where it applies
- Any valid domain credential (user or machine) with LDAP read on the domain
- Network reach to a DC on TCP/389 or TCP/636
- Useful as one of the first steps post-foothold, before noisier discovery (port scans, AXFR attempts)

## Technique
Dirk-jan Mollema's `adidnsdump` walks the DNS partition and decodes the wire-format `dnsRecord` blob. Use `--print-zones` to find zone names first, then dump:

```bash
adidnsdump -u corp\\alice -p Pass --print-zones ldap://10.0.0.10
adidnsdump -u corp\\alice -p Pass -r ldap://10.0.0.10  # resolve hidden records
```

The `-r` flag attempts DNS resolution against the DC for record names whose ACL hides the blob from the current user — many shops leave name resolution open to authenticated callers, so unreadable records still produce IPs.

Equivalent PowerShell on a domain-joined host:

```powershell
Get-DnsServerResourceRecord -ComputerName dc01 -ZoneName corp.local |
  Select HostName, RecordType, RecordData
```

Output typically reveals: print servers, internal web apps, SCCM/MECM endpoints, backup boxes, jump hosts, dev domains — high-value targets that don't appear in external recon. ADIDNS records can also be *written* by authenticated users (the dnsNode default DACL grants Create Child), which is the primary write primitive behind mitm6/WPAD-style attacks.

## Detection and defence
- Detect bulk LDAP searches against `CN=MicrosoftDNS` with `objectClass=dnsNode` — rare for legitimate clients
- Set zone-level permission `DNS UPDATE PROXY` group restrictions and remove Create Child from Authenticated Users on zones that don't need dynamic updates
- Disable LLMNR / NBT-NS and WPAD lookup at the host level so attacker-poisoned DNS records have no callers
- Monitor for new records added with TTLs of 0 or names like `wpad`, `proxy`, or single-label entries

## References
- [adidnsdump](https://github.com/dirkjanm/adidnsdump) — reference tool and protocol notes
- [Dirk-jan — Exploiting and detecting ADIDNS](https://dirkjanm.io/exploiting-the-adidns-protocol-in-active-directory-attacks/) — write side and defence
- [HackTricks — ADIDNS poisoning](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/dns.html) — companion reading
- See also: [[ldap-enumeration]], [[bloodhound]]
