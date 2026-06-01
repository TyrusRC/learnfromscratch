---
title: Google / Bing dorking
slug: google-dorking
---

> **TL;DR:** Search-engine operators (`site:`, `inurl:`, `intitle:`, `ext:`, `filetype:`) turn Google and Bing into a passive scanner for forgotten subdomains, exposed configs, and indexed sensitive files.

## What it is
Google dorking — also called Google hacking — uses search-engine advanced operators to constrain results to assets you care about. Because Google and Bing crawl what is publicly linked, a well-aimed query surfaces content the target never intended to advertise: leaked `.env` files, indexed S3 buckets, exposed Jenkins instances, public Trello boards, even forgotten subdomains absent from [[certificate-transparency]] logs. The technique is passive (your queries hit Google, not the target) and survives WAFs.

## Preconditions / where it applies
- Target domain or organisation name
- A scope that permits passive-recon use of public search engines (essentially every program)
- A second search engine to cross-check — Bing, DuckDuckGo, and Yandex index different corners of the web

## Technique
1. **Subdomain enumeration.** Quick passive supplement to [[subdomain-enumeration]]:
   ```
   site:*.target.tld -site:www.target.tld
   ```
   Page through results; Google caps deep paging, so add `-site:<known sub>` to push fresh ones up.
2. **Indexed sensitive files.** Variants of:
   ```
   site:target.tld ext:env | ext:log | ext:bak | ext:sql | ext:json
   site:target.tld inurl:wp-content inurl:uploads
   site:target.tld intitle:"index of" "parent directory"
   ```
3. **Exposed admin panels / dashboards.**
   ```
   site:target.tld intitle:"Jenkins" | intitle:"Grafana" | intitle:"phpMyAdmin"
   site:target.tld inurl:/actuator | inurl:/api/swagger | inurl:/graphql
   ```
4. **Credential-shaped content.**
   ```
   site:target.tld "BEGIN RSA PRIVATE KEY"
   site:pastebin.com target.tld
   site:trello.com target.tld
   site:github.com "target.tld" password
   ```
5. **Third-party / acquisition surface.** Pivot off org names and known emails to find cloud doc shares:
   ```
   "ACME Inc" site:s3.amazonaws.com
   "ACME Inc" site:docs.google.com
   ```
6. Save productive queries as a personal dorks file; the GHDB (Exploit-DB Google Hacking Database) is a good seed list. Loop the best ones into a scheduled pipeline ([[continuous-recon-automation]]) using a search-API wrapper.

## Detection and defence
- Target sees no traffic — defence is preventative: `robots.txt` (advisory, not enforcement), `X-Robots-Tag: noindex` headers, and aggressive removal via Google Search Console
- Real fix is to never publish secrets in the first place; once indexed, removal is slow
- For the hunter: respect rate limits — Google will captcha-throttle a heavy session; rotate engines and queries

## References
- [Exploit-DB Google Hacking Database](https://www.exploit-db.com/google-hacking-database) — curated dork catalogue
- [Google search operators reference](https://support.google.com/websearch/answer/2466433) — official operator list
- [HackTricks search-engine recon](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — dorking in the wider recon flow
