---
title: Web Memory Vulnerabilities
slug: web-memory-vulnerabilities
---

> **TL;DR:** Memory-safety bugs inside web infrastructure (TLS stacks, HTML parsers, shared caches) leak adjacent customers' data at scale even when the application layer is bug-free.

## What it is
Beyond the application, the servers, parsers, and middleboxes carrying traffic are written in C/C++ and occasionally over-read buffers, exposing private memory in responses. Cloudbleed (2017) was an off-by-one in a Ragel-generated HTML rewriter at Cloudflare that spilled chunks of other tenants' requests into cached pages. Heartbleed (CVE-2014-0160) let any TLS peer ask OpenSSL to echo back up to 64 KB of process memory. Smaller variants live in nginx/Apache modules and in shared backends like Memcached where tenants reuse keys.

## Preconditions / where it applies
- Multi-tenant edge proxies (CDN, WAF, TLS terminator) sharing a single process across customers
- Vulnerable native code paths: HTML rewriters, image transcoders, TLS handlers, HTTP/2 parsers
- Shared in-memory stores (Memcached, Redis) accessible from co-located tenants without per-tenant ACLs
- Search-engine and archive crawlers indexing cached pages -- making leaked data persistent

## Technique
Hunt for over-read fingerprints in cached pages:
```bash
# Look for stray HTTP headers / cookies bleeding into page bodies
curl -s https://target.tld/ | grep -aE 'Cookie:|Authorization:|^Set-Cookie'
```

Heartbleed historical PoC (memory tail in TLS heartbeat reply):
```bash
nmap -p 443 --script ssl-heartbleed target.tld
```

Memcached cross-tenant probe:
```bash
echo -e 'stats items\nstats cachedump 1 100\nquit' | nc cache.host 11211
```

Archived-leak hunting via search engines:
```
site:webcache.googleusercontent.com "authorization: bearer"
```

## Detection and defence
- Run edge code under ASAN/fuzzing; deploy memory-safe rewrites (Rust, Go) for parsers
- Per-tenant process or namespace isolation so an over-read cannot cross trust boundaries
- Aggressively purge CDN and search caches after disclosure; rotate any secret that may have been in flight
- Authenticate access to Memcached/Redis and bind to private interfaces; never expose to the internet

## References
- [Cloudflare — Incident report on memory leak (Cloudbleed)](https://blog.cloudflare.com/incident-report-on-memory-leak-caused-by-cloudflare-parser-bug/) — root cause and remediation timeline
- [Heartbleed.com](https://heartbleed.com/) — protocol explanation and impact summary

See also: [[cache-poisoning]], [[known-vuln-workflow]], [[n-day-rapid-exploitation]].
