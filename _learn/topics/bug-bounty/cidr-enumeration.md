---
title: CIDR Enumeration
slug: cidr-enumeration
---

> **TL;DR:** After ASN lookup gives you netblocks, walk every /16-/24, sweep reverse-DNS, mass-scan TLS SNI, and cross-reference whois allocations to build a high-confidence target IP pool.

## What it is
ASN enumeration produces a list of CIDR ranges owned (or announced) by the target. Those ranges still need to be expanded into live hosts, services, and TLS identities before they are useful as scope. The job is to convert a route table into an inventory: live IPs, their PTRs, their certificate names, and which of those names actually fall inside the program's scope.

## Preconditions / where it applies
- Program scope written as "anything owned by Acme" or explicit CIDR list
- ASN handed off from a prior step or pulled from BGP looking glasses
- Targets behind CDNs need an origin-discovery angle (TLS SNI sweep, historical DNS)
- Cloud allocations (AWS, GCP, Azure) require per-provider IP ranges, not whois

## Technique
Expand ASN to CIDRs, then walk them:
```bash
# ASN -> prefixes
whois -h whois.radb.net -- '-i origin AS13335' | awk '/^route/ {print $2}' | sort -u > prefixes.txt

# Live host discovery
masscan -iL prefixes.txt -p443,80,8443 --rate 5000 -oG masscan.gnmap

# Reverse-DNS sweep with dnsx
awk '/Host:/ {print $2}' masscan.gnmap | dnsx -ptr -resp-only > ptrs.txt

# Pull TLS SNI / SAN names per live IP
cat live.txt | tlsx -san -cn -silent -o sni.txt

# Cross-check whois allocation for the netblock (org name match)
whois 203.0.113.0 | grep -iE 'OrgName|netname|descr'
```

Filter SNI list to the program scope domains:
```bash
grep -Ef scope_domains.regex sni.txt | sort -u > in-scope-hosts.txt
```

## Detection and defence
- Defenders: monitor for sequential SYN scans and SNI probes across a netblock, especially from cloud egress IPs
- Hunters: respect program rate-limits; cap masscan/zmap rate and avoid noisy ports outside scope
- Cross-reference findings against passive sources (Shodan, Censys) before active scanning to cut noise
- Document the provenance of each IP -> domain mapping so triagers can verify ownership

## References
- [Team Cymru — IP to ASN mapping](https://team-cymru.com/community-services/ip-asn-mapping/) — authoritative ASN/prefix lookups
- [Projectdiscovery — tlsx](https://github.com/projectdiscovery/tlsx) — extract SAN/CN names across large IP lists

See also: [[asn-enumeration]], [[subdomain-enumeration]], [[reverse-whois]].
