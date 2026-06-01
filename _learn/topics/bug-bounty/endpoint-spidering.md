---
title: Endpoint spidering
slug: endpoint-spidering
---

> **TL;DR:** Crawl the rendered app — not just static HTML — to surface routes, hidden parameters, and internal API calls that scanners miss; katana, hakrawler, and gospider with headless mode are the workhorses.

## What it is
Endpoint spidering walks the application like a browser would, following anchor tags, form actions, fetch/XHR calls, and JS-emitted URLs to build a request inventory. Modern SPAs render most of their attack surface client-side, so a `wget --mirror` pass captures almost nothing — you need a headless crawler that executes JS, intercepts network calls, and follows the dynamic routes. Output feeds [[content-discovery]], [[wordlist-fuzzing-tactics]], and the per-endpoint checklist from [[testing-methodology-checklists]].

## Preconditions / where it applies
- Live, reachable host (HTTP 200/302 on root)
- Authenticated and unauthenticated sessions when the app has both — crawl each separately
- For SPAs: a crawler with headless Chrome (katana `-headless`, gospider with `-js`)

## Technique
1. Seed the crawl from `httpx` output so you only spider live hosts:
   ```
   katana -list live.txt -d 3 -jc -kf all -aff -hl -silent -o endpoints.txt
   ```
   Flags: `-jc` parses JS for endpoints, `-kf all` enables known-files (robots, sitemap, swagger), `-aff` auto-fills forms, `-hl` headless.
2. Complement with passive sources — Wayback (`waybackurls`), Common Crawl (`gau`), URLScan, AlienVault OTX. Stale URLs often reveal removed-but-still-live endpoints.
   ```
   gau --subs target.tld | tee gau.txt
   ```
3. Run an authenticated crawl. Burp/Caido proxy mode + manual click-through still beats automated auth for complex flows; export the proxy history as `.har` and merge with the spider output.
4. Extract parameter names with `unfurl keys` or `paramspider`. Distinct param names per endpoint are the input for fuzzing campaigns and IDOR hunting (see [[common-issues-to-start-with]]).
5. Diff today's crawl against yesterday's — new endpoints are the highest-yield triage targets in a [[continuous-recon-automation]] loop.
6. Normalise: strip session tokens, sort, dedupe by `host + path + paramset`. A clean endpoint list is reusable across nuclei, ffuf, and manual hunting.

## Detection and defence
- Headless crawlers leave a distinctive UA and request rhythm; WAFs flag rapid sequential GETs from one IP
- Defenders should treat any non-browser UA hitting hidden routes as suspicious — log JSON-API 401s and watchlist source IPs
- For the hunter: throttle (`-rl` in katana, `-c` concurrency) and rotate egress on programs that ban aggressive crawling

## References
- [projectdiscovery/katana](https://github.com/projectdiscovery/katana) — headless-aware crawler, current best-in-class
- [hakluke/hakrawler](https://github.com/hakluke/hakrawler) — fast Go crawler, good for piping
- [HackTricks web pentesting methodology](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/index.html) — where crawling sits in the wider flow
