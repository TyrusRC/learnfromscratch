---
title: API content discovery
slug: api-content-discovery
---

> **TL;DR:** Brute-forcing API routes is not the same as web content discovery — paths are short, methods matter, and parameters are typed. Use route-aware wordlists, scrape JS for endpoint hints, and verb-fuzz every found path.

## What it is
APIs rarely return helpful 404s or directory listings, so generic wordlists from web content discovery miss most routes. API-specific discovery combines spec hunting ([[swagger-discovery]]), JS scraping for `fetch`/`axios` patterns, and route-aware brute force with tools that send realistic JSON bodies and try multiple HTTP methods per path.

## Preconditions / where it applies
- A reachable API surface (browser app, mobile app, or a known base URL like `/api/v1/`)
- Permission to fuzz — content discovery generates large traffic volume
- Bonus: a captured authentication token so authenticated routes also resolve

## Technique
1. Pull every JS bundle the SPA loads. Grep for fetch/axios/XHR call sites and route templates:

   ```bash
   gau target.com | grep -E '\.js($|\?)' | uniq > js.txt
   while read u; do curl -s "$u"; done < js.txt | \
     grep -Eo '"/(api|v[0-9]+)/[A-Za-z0-9_/{}\-]+"' | sort -u
   ```

2. Try canonical spec locations: `/swagger.json`, `/openapi.json`, `/v2/api-docs`, `/api-docs`, `/graphql`, `/.well-known/openapi`. Most servers return the full spec to unauthenticated callers.

3. Run a route-aware brute-forcer with verb permutations:

   ```bash
   kr scan https://api.target.com -w routes-large.kite -A=apiroutes-240528
   ffuf -u https://api.target.com/api/FUZZ -w api-wordlist.txt -mc 200,201,204,400,401,403,405
   ```

4. For each discovered path, fuzz HTTP methods (`GET POST PUT PATCH DELETE OPTIONS`). A 405 on GET that flips to 200 on POST often reveals undocumented mutation endpoints.
5. Pivot on version strings (`v1` -> `v2`, `internal`, `admin`, `legacy`). Old versions frequently keep working without the new authorisation checks.

## Detection and defence
- Spike of 401/403/404 from a single token or IP across many distinct routes — classic content-discovery signature
- WAF rules that score on unique-path-rate-per-minute, not just total requests
- Disable directory-style error leakage; return a uniform 404 body regardless of route existence
- Remove production-served spec files or gate them behind auth
- Reject unexpected HTTP verbs at the gateway rather than letting them reach the backend

## References
- [Kiterunner](https://github.com/assetnote/kiterunner) — route-aware HTTP brute-forcer with realistic bodies
- [HackTricks: Swagger / OpenAPI](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/swagger-api.html) — spec-hunting locations
- [OWASP API Security Top 10 2023](https://owasp.org/API-Security/editions/2023/en/0xa9-improper-inventory-management/) — orphan endpoints risk
