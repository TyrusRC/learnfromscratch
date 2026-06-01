---
title: Banner grabbing and fingerprinting
slug: banner-and-fingerprinting
---

> **TL;DR:** Headers, error pages, favicon hashes, and JS asset hashes collapse "what is this site running?" into a CVE search — the cheapest, fastest first step of any web engagement.

## What it is
Fingerprinting is the act of mapping an unknown target to a known stack — web server, language runtime, framework, CMS, plugin, version — by reading observable artefacts. A precise stack identity turns generic poking into targeted exploit hunting: from "some PHP app" to "Drupal 7.58, vulnerable to SA-CORE-2018-002". Modern recon chains combine banner reading, content hashing, and behavioural probes for triangulation.

## Preconditions / where it applies
- Any HTTP(S) endpoint, including those behind CDNs (origin sometimes leaks via a debug header or 502 page)
- Targets that have not deliberately stripped tokens (most production sites)
- Useful even when content is bland — favicons and TLS cert SANs still talk

## Technique
Layer signals from cheapest to most invasive.

```bash
# 1. Headers
curl -sI https://target/ | tee headers.txt
# Look for: Server, X-Powered-By, X-AspNet-Version, X-Generator,
# Set-Cookie name (PHPSESSID, JSESSIONID, ASP.NET_SessionId, laravel_session),
# Via, X-Backend-Server, X-Drupal-Cache

# 2. Multi-tool fingerprint
whatweb -a 3 https://target/
httpx -u https://target/ -tech-detect -title -web-server -status-code
wappalyzer-cli https://target/      # or browser extension on a real visit
nuclei -t technologies/ -u https://target/

# 3. Favicon hash (Shodan-style)
python3 -c "import mmh3, base64, requests; \
  r=requests.get('https://target/favicon.ico'); \
  print(mmh3.hash(base64.encodebytes(r.content)))"
# pivot the hash on Shodan: http.favicon.hash:-<value>

# 4. Error-page hash
curl -s https://target/this-does-not-exist | sha1sum
# Compare against a corpus of default 404 pages per framework

# 5. Behavioural probes
curl -s https://target/?XDEBUG_SESSION_START=1
curl -s -H 'Accept: application/json' https://target/  # framework JSON 404s
```

CMS-specific probes: `/wp-login.php`, `/administrator/` (Joomla), `/user/login` and `/CHANGELOG.txt` (Drupal), `/sites/default/files/`, `/typo3/`, `/umbraco/`. JS bundle filenames (`runtime.<hash>.js`, `chunk-vendors.<hash>.js`) often map straight to Angular/Vue/React build templates.

## Detection and defence
- Strip identifying headers: `server_tokens off;`, `ServerSignature Off`, `expose_php = Off`, `server.tag = ""` (lighttpd)
- Replace default 404/500 pages with branded generic ones
- Randomise or remove favicon on sensitive admin hosts; do not reuse the same favicon across staging and prod
- Monitor for high-volume tech-detect scans (httpx/whatweb UA strings) at the WAF
- Force generic cookie names (`SESSION`) instead of framework defaults where the platform allows

## References
- [Wappalyzer fingerprints](https://github.com/wappalyzer/wappalyzer) — signature corpus
- [projectdiscovery/httpx](https://github.com/projectdiscovery/httpx) — fast banner + tech detect
- [Shodan favicon hash guide](https://www.shodan.io/search/filters) — `http.favicon.hash` pivot
- [WhatWeb](https://github.com/urbanadventurer/WhatWeb) — plugin-based fingerprinting

See also: [[information-disclosure]], [[git-source-leakage]], [[backup-and-config-leakage]].
