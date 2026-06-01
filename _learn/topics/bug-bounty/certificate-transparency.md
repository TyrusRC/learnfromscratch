---
title: Certificate Transparency mining
slug: certificate-transparency
---

> **TL;DR:** Every public TLS cert is logged forever; query crt.sh / Censys / certspotter to pull a target's full historical hostname inventory without touching their infra.

## What it is
Certificate Transparency (CT) is an append-only public log of every certificate issued by participating CAs (which today is effectively all browser-trusted CAs). Each entry contains the issued cert, including its Common Name and all Subject Alternative Names. From a recon perspective, CT is the single best passive source of subdomains because the org cannot redact entries — once logged, the hostname is public for the cert's lifetime and beyond.

## Preconditions / where it applies
- Target uses public-CA-issued TLS (Let's Encrypt, DigiCert, GlobalSign, etc.). Internal-CA hosts will not appear.
- You need historical and current names — including dev/staging hosts engineers issued certs to once and forgot
- Always run at the start of [[subdomain-enumeration]] before active brute-force

## Technique
1. Hit crt.sh directly. The `%` wildcard matches subdomains; JSON output is easiest to pipe.
   ```
   curl -s 'https://crt.sh/?q=%25.target.tld&output=json' \
     | jq -r '.[].name_value' | tr '[:upper:]' '[:lower:]' \
     | tr ',\n' '\n' | sed 's/^\*\.//' | sort -u
   ```
2. Add Censys and certspotter for coverage (crt.sh occasionally drops large query results).
   ```
   curl -s 'https://api.certspotter.com/v1/issuances?domain=target.tld&include_subdomains=true&expand=dns_names' \
     | jq -r '.[].dns_names[]' | sort -u
   ```
3. Pivot on the organisation name in the cert subject (`O=`) — many orgs issue EV certs that share an `O=` value, and crt.sh lets you search that field. Useful for cross-brand discovery alongside [[reverse-whois]] and [[analytics-tag-correlation]].
4. Resolve everything with dnsx → httpx → screenshot. Expect a lot of stale `*-prod`, `*-staging`, `*-dr`, `*-blue/green` hostnames; the dead ones can still be valid for [[vhost-enumeration]] if the IP is reused.
5. For continuous monitoring, subscribe to CT firehose (certstream, Sectigo CertSentry, or your own pg_cron crt.sh query) and alert on every new `*.target.tld` cert. Acquired-company certs often appear here before any blog post.

## Detection and defence
- Defenders cannot remove entries; only mitigation is private CA / wildcard certs (which themselves signal "the entire `*.target.tld` namespace exists")
- Internal recon teams should mirror your CT monitor — same data, used to spot rogue or expired certs
- Hunters: be aware that wildcard certs hide the actual hostname; combine CT with passive DNS and active probing to enumerate behind a wildcard

## References
- [crt.sh](https://crt.sh/) — the canonical free CT search UI
- [CertSpotter API](https://sslmate.com/certspotter/api) — programmatic CT querying
- [HackTricks subdomain discovery](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — CT in the wider recon flow
