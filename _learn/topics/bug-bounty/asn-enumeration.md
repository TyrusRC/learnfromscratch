---
title: ASN enumeration
slug: asn-enumeration
---

> **TL;DR:** Discover org-owned IP ranges via BGP / WHOIS, then sweep them for ports, services, and virtual hosts. Routed-block IPs frequently host forgotten staging and admin panels that never made it into the security team's inventory.

## What it is
An Autonomous System Number (ASN) is the routing identity a company uses to announce its IP prefixes on the public internet. Mapping an org name to its ASNs gives you every prefix they announce, which gives you every IP they can serve traffic from. This is pure horizontal recon — orthogonal to DNS-driven techniques like [[certificate-transparency]] and [[subdomain-enumeration]].

## Preconditions / where it applies
- Target operates its own infra (large SaaS, telecom, bank, cloud provider) — not just rented CDN slots
- Scope language permits "IP ranges owned by $COMPANY" (most VDPs do; some bug bounty programs scope only to specific hosts)
- You can scan from a clean source IP that won't get null-routed mid-sweep

## Technique
1. Resolve the org to ASNs. Multiple sources, cross-check the results:

```
# Hurricane Electric — by name
curl -s "https://bgp.he.net/search?search%5Bsearch%5D=ExampleCorp&commit=Search"

# whois on a known target IP gives the AS number
whois -h whois.cymru.com " -v 1.2.3.4"
```

2. Pull the prefixes announced by each ASN:

```
# RIPEstat (public, no key)
curl -s "https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS12345"

# bgpview
curl -s "https://api.bgpview.io/asn/12345/prefixes"
```

3. Validate ownership — not every prefix in an ASN belongs to your target (transit, customer cones, leased space). For each prefix, check `whois`, the `OrgName` / `NetName`, and reverse DNS. Drop anything that's clearly a cloud-tenant block.
4. Port-sweep the validated prefixes:

```
# Fast TCP top-1k with masscan; rate to taste
masscan -p1-65535 --rate 5000 -iL ranges.txt -oG masscan.gp

# Service detection on found ports
nmap -sV -Pn -iL targets.txt -p $PORTS --open
```

5. Probe HTTPS on every open 443 with `httpx -tls-grab` to extract SAN names; pivot those back into the asset graph ([[asset-graphing]]). Many internal hostnames leak via cert SANs even when DNS doesn't resolve them externally.
6. Bonus: query `crt.sh` for certs containing IPs in the range or org name — surfaces hosts you'd miss with DNS only.

## Detection and defence
- BGP/ASN data is public — there is no hiding announced space. Defenders should accept that and instead make sure every announced IP has a known owner internally
- Watch for masscan-pattern SYN floods to /16+ ranges from single source IPs in netflow
- Restrict admin panels to allowlisted source IPs even on "internal-only" hosts; the routed block reaches the public internet by definition
- Run your own ASN sweep weekly and diff — any new service that appears is either expected (ticketed) or a shadow-IT incident

## References
- [Hurricane Electric BGP Toolkit](https://bgp.he.net/) — ASN search by org name, prefix lookup
- [HackTricks — IP and ASN enumeration](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — workflow + tools
- [RIPEstat data API](https://stat.ripe.net/docs/data_api) — programmatic prefix + announcement data
