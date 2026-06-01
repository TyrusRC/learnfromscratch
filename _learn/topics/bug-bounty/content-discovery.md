---
title: Content discovery
slug: content-discovery
---

> **TL;DR:** Brute-force paths and parameters on a target using wordlists chosen for its tech stack; triage by status code, content length, and response diffing; recurse when the layer above warrants it.

## What it is
Content discovery is the "what URLs exist that aren't linked from anywhere" step. The application's documented routes are visible in the spider output; the interesting bugs are in routes the developers forgot, the admin panel left enabled in production, and the backup file accidentally committed to web root. This is the bridge between recon and active testing.

## Preconditions / where it applies
- A live host with a discoverable web root (HTTP 200/3xx/4xx baseline)
- Tech stack identified ([[tech-stack-fingerprinting]]) so wordlists can be tuned
- Program rules allow active probing — rate limits respected

## Technique
1. Establish the baseline before fuzzing. What does a known-bad request return? Is it 404, 200 with a custom error page, 302 to login? Without the baseline you can't filter noise.

```
curl -s -o /dev/null -w "%{http_code} %{size_download}\n" \
     https://target.tld/__definitely_not_real__
```

2. Pick wordlists by stack ([[wordlist-fuzzing-tactics]]). For Java: `WEB-INF/`, `*.jsp`, `*.do`. For Node: `.env`, `package.json`, `node_modules/`. SecLists' `Discovery/Web-Content/` is the starting library.
3. Fuzz with `ffuf` or `feroxbuster`, filtering on the baseline:

```
ffuf -w wordlist.txt -u https://target.tld/FUZZ -mc all -fc 404 -ac \
     -recursion -recursion-depth 2 -o findings.json
```

`-ac` auto-calibrates against a fake path. `-recursion` descends into discovered directories.
4. Triage by status:
   - **200** with non-baseline length → manually inspect
   - **301/302** → follow the redirect, log the destination
   - **401/403** → admin candidate, try [[login-page-attacks]] or HTTP verb tampering
   - **500** → server error on a path that exists; often indicates a real handler crashing
5. Don't forget extensions and parameters. The same wordlist with `-e .bak,.old,.swp,.zip` exposes leaked source archives. Tools like `arjun` and `param-miner` brute parameter names on a known endpoint and find hidden inputs.
6. Recurse with judgement. Recursing on every 200 explodes traffic; recurse on directories that look like apps (`/admin/`, `/api/`, `/internal/`).

## Detection and defence
- WAF and access logs see huge 404 bursts from a single source — trivial to alert on. Slow your scan, rotate IPs, or accept the noise depending on program rules
- Block sensitive paths at the edge: `*.bak`, `*.swp`, `*.git/*`, `*.env`, `.DS_Store`, `WEB-INF/`
- Return identical 404 responses for non-existent paths whether the parent directory exists or not — avoids leaking app structure via response timing
- Run your own content discovery internally on every release; if the bounty hunter finds it first you already lost

## References
- [PortSwigger — Content discovery](https://portswigger.net/web-security/essential-skills/using-burp-suite-professional-to-attack-a-target/finding-hidden-attack-surface) — methodology
- [SecLists Discovery](https://github.com/danielmiessler/SecLists/tree/master/Discovery/Web-Content) — canonical wordlist library
- [feroxbuster docs](https://github.com/epi052/feroxbuster) — modern recursive content discovery
- [PayloadsAllTheThings — Directory Bruteforce](https://github.com/swisskyrepo/PayloadsAllTheThings) — wordlist and command refs
