---
title: Third-party recon
slug: third-party-recon
---

> **TL;DR:** Vendor SaaS hosted under the target's apex — chat widgets, status pages, BI dashboards, CRM portals, error trackers — extend attack surface in ways the program rarely realises. Map them and probe with vendor-specific known issues.

## What it is
A modern company's subdomains aren't all theirs. `status.example.com` may be Statuspage, `help.example.com` may be Zendesk, `chat.example.com` may be Intercom, `bi.example.com` may be a Tableau or Looker instance, `monitoring.example.com` may be Datadog or Sentry. Each is a third-party SaaS configured with company branding. Misconfigurations in those tenants — public dashboards, exposed admin, leaked tokens — count as the company's bugs when discovered via their subdomain.

## Preconditions / where it applies
- Wildcard scope (`*.example.com`) — typically includes vendor-fronted subdomains unless explicitly excluded
- Target uses third-party SaaS at scale (most >100-employee orgs do)
- Vendor allows tenant misconfig (most do — it's the customer's responsibility to lock down)

## Technique
1. Identify the vendor behind each subdomain. CNAME records and HTTP response fingerprints are the tells:

```
dig +short help.example.com CNAME
# -> zendesk.com  -> Zendesk

dig +short status.example.com CNAME
# -> *.statuspage.io
```

HTTP fingerprints: `X-Served-By: zendesk`, distinct favicon hashes, vendor-specific paths (`/hc/`, `/_assets/`, `/incidents/`).
2. Common vendors and their misconfig classes:
   - **Statuspage** — public components leak internal service names; SSO bypass on private status pages
   - **Zendesk** — open enrollment, email spoofing, ticket field leaks via API
   - **Intercom / Drift / chat widgets** — JWT in JS reveals workspace ID; spoofed user identity if HMAC missing
   - **Sentry / Rollbar** — public DSN allows submission of fake events (low impact) but admin panel access if cred-stuffed (high)
   - **GitBook / Notion / Confluence Cloud** — accidentally public internal docs
   - **Salesforce Communities / Lightning** — IDOR and aura controller exposure (a recurring high-impact bug class)
3. Vendor-specific dorks. Most vendors expose tenant IDs in URLs — Google `site:*.zendesk.com "example"` to find adjacent tenants.
4. Subdomain takeover. Vendor CNAME pointing to a deleted vendor tenant (`somesub.example.com → ghost.cloudapp.net`) lets an attacker register the tenant and serve content under the target's brand. `nuclei -t takeovers/` and `subjack` automate detection.
5. Check the program rules. Some programs explicitly exclude third-party SaaS bugs even when on their subdomain; others reward them. Many will accept the bug but report it to the vendor and not pay — read the policy first.

## Detection and defence
- Maintain an inventory of every CNAME pointing to a third-party. When the tenant is decommissioned, remove the CNAME *first*
- For each vendor, document the hardening baseline (Statuspage: SSO required; Zendesk: anonymous tickets off; Salesforce: aura controller audit) and run a quarterly conformance check
- Subdomain takeover monitoring as a continuous job; the time-to-claim once a CNAME goes orphan can be minutes
- Heavy probing of vendor subdomains may trigger the vendor's WAF, not yours — coordinate with the vendor or skip the asset

## References
- [HackTricks — Subdomain takeover](https://book.hacktricks.wiki/en/pentesting-web/domain-subdomain-takeover.html) — CNAME pointer abuse
- [can-i-take-over-xyz](https://github.com/EdOverflow/can-i-take-over-xyz) — fingerprints per vendor
- [HackerOne disclosure — Salesforce community misconfig](https://hackerone.com/reports?keyword=salesforce) — example reports
- [Detectify Labs — third-party SaaS recon](https://labs.detectify.com/) — research writeups
