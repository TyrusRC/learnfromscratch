---
title: Recon Data Services — Shodan, Censys, and Friends
slug: recon-data-services
---

> **TL;DR:** Shodan, Censys, BinaryEdge, SecurityTrails, FOFA, Hunter, ZoomEye, and Spyse give API-first answers about exposed hosts, certificates, and DNS history — knowing each service's dorks and quotas turns recon from spraying into queries.

## What it is
Recon data services are paid or freemium platforms that continuously scan the internet and index the results: open ports, TLS certificates, HTTP banners, DNS history, ASN ownership, favicons. Each has a different crawl cadence, geography bias, and query language. Treating them as APIs — not web UIs — lets you fold their answers into pipelines that produce target lists for a given program scope.

## Preconditions / where it applies
- Bug-bounty or red-team scope where external surface mapping is in scope
- Per-service API key (or a shared team key) with known monthly quota
- Some discipline about caching results so you do not burn credits re-querying

## Technique

```bash
# Shodan — facets, certificate pivots, favicon hash
shodan search --fields ip_str,port,org,hostnames 'ssl.cert.subject.cn:"*.target.tld"'
shodan search 'http.favicon.hash:-1539918363 org:"Target Inc"'
curl -s "https://api.shodan.io/shodan/host/search?key=$K&query=ssl.cert.serial:12345&facets=port,org"

# Censys — structured search over certs + hosts
censys search 'services.tls.certificates.leaf_data.subject.common_name: target.tld' \
  --index-type hosts --pages 5
curl -s -u "$ID:$SECRET" \
  'https://search.censys.io/api/v2/hosts/search?q=services.port%3A8443+and+autonomous_system.asn%3A13335'

# SecurityTrails — DNS history and sibling domains
curl -s -H "APIKEY: $K" "https://api.securitytrails.com/v1/domain/target.tld/subdomains"
curl -s -H "APIKEY: $K" "https://api.securitytrails.com/v1/history/target.tld/dns/a"

# BinaryEdge — host + torrent + leaked credential indexes
curl -s -H "X-Key: $K" "https://api.binaryedge.io/v2/query/domains/subdomain/target.tld"

# FOFA — base64-encoded queries, strong in APAC space
q=$(printf 'cert="target.tld"' | base64 -w0)
curl -s "https://fofa.info/api/v1/search/all?email=$E&key=$K&qbase64=$q&size=200"

# Hunter.io — email pattern + employee enumeration
curl -s "https://api.hunter.io/v2/domain-search?domain=target.tld&api_key=$K"

# ZoomEye — Chinese counterpart, complementary coverage
curl -s -H "API-KEY: $K" "https://api.zoomeye.org/host/search?query=ssl:%22target.tld%22"

# Spyse / fallbacks — most useful for reverse-IP and ASN expansion
curl -s -H "Authorization: Bearer $K" "https://api.spyse.com/v4/data/domain/subdomain?domain=target.tld"
```

Pipeline pattern: pull cert CNs from Censys, expand via SecurityTrails subdomain history, cross-check liveness with httpx, then feed Shodan facets (`port`, `product`, `http.title`) to triage interesting hosts.

## Detection and defence
- Defender signals: spikes in Censys/Shodan UI traffic from your bug-bounty researchers (useful intel, not a threat), or scan banners that match these services' source ASNs (Censys 162.142.125.0/24, Shodan documented ranges)
- Hardening: minimise banner verbosity, rotate self-signed certs out of prod, separate management interfaces onto VPN-only IPs, monitor your own footprint in these services and alert on diffs; use the same APIs internally so you see what attackers see

## References
- [Shodan REST API](https://developer.shodan.io/api) — query, facets, on-demand scan endpoints
- [Censys Search API v2](https://search.censys.io/api) — hosts and certificates index
- [SecurityTrails API](https://docs.securitytrails.com/) — DNS history and reverse lookups

See also: [[certificate-transparency]], [[asn-enumeration]], [[tech-stack-fingerprinting]].
