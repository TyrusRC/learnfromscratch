---
title: Analytics-tag correlation
slug: analytics-tag-correlation
---

> **TL;DR:** Shared Google Analytics, Tag Manager, AdSense, or Facebook Pixel IDs across "unrelated" domains expose hidden ownership relationships — a fast pivot into in-scope subsidiaries.

## What it is
Most public sites embed third-party tracking snippets keyed by an account ID (`UA-XXXXXX-N`, `GTM-XXXXXX`, `G-XXXXXXXXX`, `pub-XXXXXXXXXXXXXXXX`, Facebook `fbq` pixel ID). Marketing teams reuse the same account across every property they own, so the ID becomes a fingerprint. Searching that ID in third-party indexes returns every other domain that ships the same snippet, which often surfaces forgotten subsidiaries, dev sites, and brand acquisitions never linked from the corporate homepage.

## Preconditions / where it applies
- Target has a public marketing site or app that loads analytics in the HTML
- Program scope is wildcard / "any asset owned by ACME" — you need a way to prove ownership
- Useful at the start of horizontal expansion when [[reverse-whois]] is too noisy or privacy-shielded

## Technique
1. Pull the apex and a couple of major subdomains and grep the rendered HTML / JS for tracker IDs.
   ```
   curl -sL https://target.tld | grep -oE 'UA-[0-9]+-[0-9]+|G-[A-Z0-9]+|GTM-[A-Z0-9]+|pub-[0-9]{16}'
   ```
2. Feed each ID to the public indexes that crawl them:
   - `https://hackertarget.com/analytics-lookup/?q=UA-XXXXXX-1`
   - `https://dnslytics.com/reverse-analytics/UA-XXXXXX-1`
   - `https://builtwith.com/relationships/tag/UA-XXXXXX-1`
   - SpyOnWeb, Sitesleuth, NerdyData for AdSense `pub-` IDs
3. Cross-reference results with [[certificate-transparency]] and [[reverse-whois]] hits to confirm ownership before adding to scope. The base account number (`UA-XXXXXX-*`) groups properties for the same Analytics account; the trailing index is per-property.
4. For Tag Manager containers, fetch `https://www.googletagmanager.com/gtm.js?id=GTM-XXXXXX` and review the JSON — embedded URLs hint at other tracked properties even when third-party indexes miss them.
5. Record each new apex, then loop it back through your normal recon pipeline ([[subdomain-enumeration]], [[asn-enumeration]]).

## Detection and defence
- No meaningful blue-team signal — these IDs are intentionally public; only ID rotation or per-brand accounts breaks the link
- For the defender: issue a distinct Analytics property per brand, never reuse a Tag Manager container across acquisitions, scrub IDs from staging clones
- When reporting, attach the tracker-ID screenshot as ownership evidence so triagers can validate scope quickly

## References
- [HackTricks external recon methodology](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — broader recon methodology that includes tag pivots
- [BuiltWith Relationships](https://builtwith.com/relationships) — tracker-ID lookup
- [DNSlytics reverse analytics](https://dnslytics.com/reverse-analytics) — free reverse-tag index
