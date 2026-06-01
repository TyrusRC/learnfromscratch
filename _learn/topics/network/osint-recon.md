---
title: OSINT recon
slug: osint-recon
---

> **TL;DR:** Build a model of the target's people, infrastructure, and tech stack using public sources before sending a single packet at them.

## What it is
Open-source intelligence recon is the passive phase: everything you can learn from third-party data and the public internet without interacting with target systems. The output is three artefacts — an employee list (for [[password-spraying]] and phishing), an infrastructure map (IP space, ASNs, certificates, DNS), and a tech-stack inventory (frameworks, vendors, SaaS, code repos). All three seed the active phase: [[dns-enum]], [[host-discovery]] and the per-service deep dives.

## Preconditions / where it applies
- A scope: a primary domain, a corporate name, or a parent organisation.
- Legal authorisation if any technique edges into interactive territory (search-engine dorks are fine; sending a CAPTCHA-busted scraper at a target's own login page is not).
- Internet access from an attribution-managed source — use a separate browser profile, VPN, or burner cloud egress.

## Technique
**People.** LinkedIn for org chart and tech-stack stamps (skill listings reveal the SIEM, EDR, IdP). Email-format inference from public sources (Hunter.io, sales tooling, GitHub commit emails). Validate generated `firstname.lastname@corp.com` candidates against MX validation or M365 OAuth endpoints. Cross-reference Have-I-Been-Pwned for known leak material.

**Infrastructure.** Map IP space from ASNs (`whois -h whois.radb.net -- '-i origin AS12345'`), then enrich with passive DNS:

```bash
# Subdomains from CT logs (no scanning)
curl -s 'https://crt.sh/?q=%25.corp.com&output=json' \
  | jq -r '.[].name_value' | tr -d '"' | sort -u
# Shodan for exposed services without scanning yourself
shodan search 'ssl:"corp.com"' --fields ip_str,port,product
```

Censys, Shodan, FOFA, ZoomEye and BinaryEdge each cover slightly different slices of the public internet; combine for coverage. Certificate-transparency (`crt.sh`, `censys certificates`) is the single best subdomain source because every public TLS cert is logged.

**Tech stack.** Wappalyzer / BuiltWith fingerprints public web properties. GitHub/GitLab dorks (`org:corp filename:.env`, `"corp.com" "AKIA"`) hunt leaked secrets and internal hostnames in code. Job postings list explicit product names ("experience with Splunk, CrowdStrike, Okta"). Sentry/error-tracking artefacts in JS bundles leak internal hostnames.

**Inventory pivots.** Once you have one canonical IP, pivot via reverse-DNS, shared cert SANs, favicon hashes (Shodan's `http.favicon.hash`), and Cloudflare CNAME chains to enumerate adjacent assets.

## Detection and defence
- Most pure-OSINT activity is invisible to the target by definition — that is the point.
- Defensive countermeasures live at the source: remove employee directory exposure, scrub secrets from public repos, rotate certificates that previously named decommissioned hosts, and use wildcard certs cautiously (they hide subdomains in CT logs).
- Monitor your own attack surface with the same tools (Censys/Shodan API for owned IP space) and run continuous CT-log monitoring to catch shadow-IT issuance.

## References
- [crt.sh](https://crt.sh) — certificate-transparency search; the highest-signal passive subdomain source.
- [HackTricks — external recon methodology](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — end-to-end passive recon playbook.
- [OSINT Framework](https://osintframework.com/) — categorised tool index.
- [DEFCON 23 — How Do I Web](https://media.defcon.org/DEF%20CON%2023/DEF%20CON%2023%20presentations/DEF%20CON%2023%20-%20Jason-Haddix-How-Do-I-shot-Web.pdf) — classic recon-pivoting talk.
