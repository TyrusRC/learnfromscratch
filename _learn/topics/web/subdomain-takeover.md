---
title: Subdomain takeover
slug: subdomain-takeover
---

> **TL;DR:** Dangling CNAME pointing at an unclaimed cloud resource — register it, serve attacker content from the trusted subdomain.

## What it is
Apps frequently point subdomains at third-party SaaS (`foo.target.tld → app.heroku.com`, `s3.amazonaws.com`, `azureedge.net`, `ghs.googlehosted.com`). When the SaaS resource is deleted but the CNAME is left in DNS, anyone who can claim a resource with that name at the SaaS captures the subdomain. The attacker now serves arbitrary content from a trusted origin — cookies, CSP allowlists, SSO redirects, password reset URLs all extend the impact.

## Preconditions / where it applies
- DNS CNAME / ALIAS pointing at a third-party service that allows attackers to register the dangling identifier
- Service does not verify ownership of the target hostname (or verification is bypassable)
- Optional: parent domain cookie scope, SSO trust, CSP allowlist, OAuth `redirect_uri` allowlist that includes the subdomain

## Technique
1. **Enumerate subdomains** — passive (crt.sh, Subfinder, Amass, Chaos), active brute-force (puredns + commonspeak/dns-words).
2. **Probe each subdomain** for a takeover fingerprint:
   ```bash
   subfinder -d target.tld -silent | dnsx -cname -resp \
     | nuclei -t http/takeovers/ -severity high
   ```
   Look at HTTP responses: "There isn't a Github Pages site here.", "NoSuchBucket", "Repository not found", "Heroku | No such app", "404 Web Site not found" (Azure).
3. **Match service** — the dangling-target list at `EdOverflow/can-i-take-over-xyz` documents each fingerprint, which SaaS, and how to claim.
4. **Claim the resource** — create the matching bucket/app/site name at the SaaS using a fresh account.
5. **Upload content / cert** — many SaaS issue TLS certs (Let's Encrypt) automatically for the claimed name; you now have HTTPS on `foo.target.tld`.
6. **Weaponise**:
   - Cookies scoped to `.target.tld` are sent to your origin (session theft).
   - Phishing under the trusted brand.
   - Bypass CSP `script-src foo.target.tld`.
   - Hijack OAuth `redirect_uri` that allow `*.target.tld` or include the subdomain.
   - Pixel-track every visitor.
7. **NS / DNS-zone takeover** — variant: `target.tld` delegates a zone to a nameserver provider account that lapsed; register the account, control the entire zone.
8. **MX takeover** — dangling MX to abandoned mail provider → receive mail (password resets, etc.).

## Detection and defence
- Inventory DNS records with `dnscontrol` / `octoDNS`; CI job that resolves every CNAME and verifies the target responds with an owned indicator.
- When deprovisioning a SaaS resource, delete the DNS record *first*, the resource second.
- Use ownership-verified subdomains where the SaaS supports it (Cloudflare Workers, Vercel custom-domain verification).
- Monitor cert transparency for new certs on your zones — attackers issuing for `foo.target.tld` show up immediately.
- Scope cookies narrowly (no `Domain=.target.tld` unless required); limit CSP/OAuth allowlists to specific subdomains.
- Related: [[dangling-dns-takeover]], [[cors-misconfig]], [[oauth-flows]], [[sso-attacks]].

## References
- [can-i-take-over-xyz](https://github.com/EdOverflow/can-i-take-over-xyz) — service-by-service fingerprint catalog
- [HackerOne — subdomain takeover writeups](https://hackerone.com/reports?searchTerm=subdomain+takeover) — real cases
- [Detectify — subdomain takeover](https://blog.detectify.com/best-practices/hostile-subdomain-takeover-using-heroku-github-desk-more/) — taxonomy
