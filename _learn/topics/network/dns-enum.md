---
title: DNS enumeration
slug: dns-enum
---

> **TL;DR:** Zone transfers when allowed, wordlist + permutation brute force when not, plus AD-integrated DNS via authenticated LDAP queries (`adidnsdump`) and passive sources to catch what active probing misses.

## What it is
DNS is usually the first map you draw of a target. Externally it advertises mail, VPN, SSO, and CDN endpoints; internally it leaks workstation hostnames, server roles, and AD site topology. Modern enumeration stitches together several signal sources: classic zone transfers (AXFR/IXFR) when a secondary is misconfigured, brute-forced subdomain queries against an authoritative server, certificate transparency and passive DNS feeds for what already exists, and authenticated LDAP queries against AD-integrated DNS zones when you have any domain credential.

## Preconditions / where it applies
- External: knowledge of the apex domain and reachability to any public resolver/authoritative server.
- Internal AD: at least one domain credential (for `adidnsdump`) or unauthenticated DNS query access from the network.
- AXFR works when at least one server's allow-transfer is `any` or includes your IP.

## Technique
1. Identify nameservers and try zone transfer.
2. Brute force + permute against authoritative servers.
3. Pull AD-integrated zones via LDAP if you have a foothold.

```bash
# Discovery and AXFR
dig +short NS example.com
for ns in $(dig +short NS example.com); do
  dig @"$ns" example.com AXFR
done
```

```bash
# External brute force (modern tooling)
subfinder -d example.com -all -silent | tee subs.txt
amass enum -passive -d example.com
puredns bruteforce wordlist.txt example.com -r resolvers.txt
dnsx -l subs.txt -a -resp                       # resolve + filter alive
shuffledns -d example.com -w wordlist.txt -r resolvers.txt
```

```bash
# AD-integrated DNS — bypass restricted zone transfer with LDAP
adidnsdump -u 'domain\user' --include-tombstoned target-dc.corp.local
# yields a flat list of every record in the ForestDnsZones / DomainDnsZones partitions
```

Pair with certificate transparency (`crt.sh`, `chaos`), Rapid7 / SecurityTrails passive DNS, and reverse-DNS sweeps over discovered IP ranges. Wildcard DNS at the apex requires a filter pass — `puredns` and `dnsx` both detect and discard wildcard-poisoned answers.

## Detection and defence
- Allow zone transfers only between explicit nameserver IPs (`allow-transfer` ACL) and over TSIG.
- Rate-limit recursive queries (`response-rate-limiting`) and alert on bursts from one source — useful but easily defeated by distributed resolvers.
- For AD DNS, restrict default `Authenticated Users` read on the DNS partitions and enable enhanced LDAP signing.
- Related: [[http-enum]], [[ligolo-ng]].

## References
- [HackTricks — Pentesting DNS](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-dns.html) — broad reference for enumeration verbs.
- [Dirk-jan Mollema — adidnsdump](https://github.com/dirkjanm/adidnsdump) — LDAP-backed AD DNS extraction.
- [ProjectDiscovery — subfinder / dnsx / puredns](https://github.com/projectdiscovery) — modern fast tooling stack.
