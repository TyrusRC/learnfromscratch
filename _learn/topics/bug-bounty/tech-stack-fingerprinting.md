---
title: Tech-stack fingerprinting
slug: tech-stack-fingerprinting
---

> **TL;DR:** Identify the frameworks, libraries, CDN, WAF, and language behind every live host. Stack drives wordlist choice, payload selection, and which CVEs to map against — without it, fuzzing is random.

## What it is
Tech fingerprinting reduces an opaque HTTP response to a structured "this is Spring Boot 2.7, with Tomcat, behind Cloudflare, using a React 18 frontend." Each identified component changes which wordlist to fuzz with, which payloads encode-bypass the WAF, and which n-day CVEs might already work ([[n-day-rapid-exploitation]]).

## Preconditions / where it applies
- A live HTTP/S host within scope
- Some response body / headers / cookies to analyse (not just a 403 block page)
- A continuously updated fingerprint database (Wappalyzer rules, retire.js signatures, nuclei templates)

## Technique
1. Passive header analysis — cheapest signals, no extra traffic:

```
Server: nginx/1.18.0
X-Powered-By: Express
X-AspNet-Version: 4.0.30319
Set-Cookie: JSESSIONID=...     -> Java servlet container
Set-Cookie: laravel_session=... -> Laravel
Set-Cookie: connect.sid=...     -> Express session
```

2. Body-level signals:
   - HTML comments (`<!-- powered by WordPress 6.4 -->`)
   - Meta tags (`<meta name="generator" content="Drupal 10">`)
   - CSP / report-to headers list internal hostnames + asset hosts
   - `<script src="/static/_next/...">` → Next.js; `/static/runtime~main.abc.js` → Webpack
   - Favicon hash (`mmh3` of the body) cross-referenced with Shodan favicon search
3. Active fingerprinting:
   - Predictable 404 bodies per framework (Django, Rails, Express each have a unique default)
   - Probing well-known paths: `/wp-login.php`, `/.well-known/security.txt`, `/actuator`, `/_next/`, `/__webpack_hmr`
   - JS bundle parsing for library imports + version strings ([[js-recon]])
4. Tools to automate the pass:

```
# whatweb — comprehensive plugin set
whatweb -v https://target.tld

# wappalyzer CLI / browser ext (browser version detects SPA frameworks better)
wappalyzer https://target.tld

# nuclei tech-detect templates
nuclei -u https://target.tld -t technologies/ -severity info
```

5. Fingerprint the WAF too. `wafw00f` and nuclei's `waf-detect` templates identify Cloudflare, Akamai, F5, AWS WAF; this determines which payload encodings to try.
6. Record findings per host in the asset graph ([[asset-graphing]]). The same target may have 5 different frameworks across its subdomains — admin in WordPress, marketing in HubSpot, app in Next.js. Each is a different bug shop.

## Detection and defence
- Strip identifying headers (`Server`, `X-Powered-By`, `X-AspNet-Version`) at the edge proxy
- Customise framework 404 pages to a generic site-wide error template
- Don't expose `/actuator`, `/.git/`, `/_next/__webpack_hmr` outside development
- Defender: fingerprint your own surface and reconcile against asset inventory — drift detection catches shadow IT
- Repeated nuclei tech-detect template signatures from a single IP are an easy WAF/SOC alert

## References
- [Wappalyzer rules](https://github.com/wappalyzer/wappalyzer) — community fingerprint definitions
- [whatweb](https://github.com/urbanadventurer/WhatWeb) — CLI fingerprint scanner
- [Shodan favicon search](https://search.shodan.io/) — pivot by favicon hash to find more hosts with the same stack
- [HackTricks — Pentesting Web Methodology](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/index.html) — fingerprinting checklist
