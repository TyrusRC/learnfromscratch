---
title: Case study — Okta support-system breach (2023)
slug: case-study-okta-2023-support-system
aliases: [okta-2023-incident, okta-support-system-breach]
---

> **TL;DR:** A service-account credential was harvested from an Okta employee's personal Google account, where they had signed into their corporate Chrome profile and saved credentials. The attacker used the service account against Okta's customer-support system, downloaded session cookies and HAR-file uploads from customers, and used those to compromise downstream customer environments — including BeyondTrust, Cloudflare, and 1Password. The downstream customers' EDR / IR teams detected the activity and notified Okta. Companion to [[case-study-snowflake-2024]] and [[case-study-3cx-supply-chain]].

## Why this matters

- It's the **definitive case** of an identity vendor's compromise cascading into customers — Okta has thousands of high-value enterprise customers.
- The initial vector was **a personal account on a corporate browser**. Generic to almost every enterprise.
- The data exposed (HAR files) was a class many vendors store but few protect — **session cookies and bearer tokens** uploaded by customers for debugging.
- The detection chain was **customer → vendor**, not vendor self-detection.

## The chain

1. Okta employee signed into personal Google account in corporate Chrome profile.
2. Personal Google account also synced personal device password store.
3. Credential for a service account was saved in that store.
4. Personal account compromised (or accessed from a personal device).
5. Service-account credential extracted.
6. Service account had access to Okta's customer-support system (Salesforce or similar).
7. Attacker browsed customer support cases, downloading attached HAR files.
8. HAR files contained customer browser sessions including authenticated cookies for the customer's own Okta admin console.
9. Attacker replayed those sessions to enter customer admin consoles.
10. From customer admin console: read/modify identity policies, harvest more sessions.

## What HAR files contained

A HAR (HTTP Archive) is a JSON dump of a browser session — every HTTP request and response, headers and bodies inclusive. Customers uploaded HARs to Okta support so support could reproduce browser issues.

The HARs contained:
- Session cookies for the customer's Okta tenant (admin sessions).
- OAuth refresh tokens.
- Bearer tokens for integrations.
- Personal data of the customer's employees (form submissions during the recorded session).

## How the downstream customers detected

BeyondTrust first detected on **anomalous session use**: their EDR / SOC noticed the Okta admin session being used from an unrecognised IP and immediately blocked. Several other customers similarly detected and notified Okta. Okta's investigation traced backward to the support system access.

The lesson is unambiguous: **session anomaly detection works**. Customers who had it caught the incident; customers who didn't might never have known.

## What this teaches

- **Browser sync of corporate credentials** to personal accounts is a vector. Disable sync, or enforce profile separation.
- **Service accounts** should not store credentials in browsers. They should use SSO with hardware-bound device certificates.
- **Customer-uploaded debug artefacts** are credentialed. Vendors must sanitise HAR files at ingestion (strip cookies, tokens, headers). Customers must scrub before upload.
- **Support-system access** is privileged. Treat support tools with the same auditing as production.
- **Session anomaly detection** on the customer side is the highest-ROI control: it catches identity-vendor compromise too.

## IR lessons

- Okta's IR was **slow and multiple-revision**. Initial public statement underestimated scope; revisions came over weeks. This is a generic pattern — initial vendor statements often understate.
- **Customer-side hunt**: when a vendor announces breach, customers should hunt their own logs for session use from unfamiliar IPs and any admin operations during the exposure window.
- **Force credential rotation** at vendor advisory minimum; don't wait for vendor specifics.

## Detection use cases (SIEM / Okta-specific)

- Login from new ASN / geo for any administrator account.
- Use of a session cookie from multiple IPs concurrently.
- Admin operations (create user, modify group, change policy) by accounts that don't usually do that.
- Session cookies older than N hours used after a customer-support interaction.

## Generalising — vendor support data

Many SaaS vendors take customer-uploaded artefacts for support. The same risk applies to:

- HAR files (browser sessions).
- Configuration dumps (often containing credentials).
- Memory dumps / heap dumps.
- Diagnostic logs (sometimes with bearer tokens).
- Database snapshots.

Whatever your team sends to vendor support: assume it leaks.

Defensive baseline as customer:

- **Scrub** HARs / dumps before upload — strip `Cookie`, `Authorization`, `Set-Cookie`, sensitive form fields.
- **Use ephemeral test tenants** for reproductions, not production.
- **Audit what your team sends** to support — your customer success team is sometimes more lenient with sensitive data than security would be.
- **Vendor security review**: ask vendors what controls they have on support-tool access.

## Related identity-vendor incidents

- **Okta 2022** — Lapsus$ compromise via a third-party support contractor.
- **LastPass 2022** — developer workstation compromise leading to backup access.
- **CircleCI 2022** — engineer's laptop infostealer leading to environment compromise.

Pattern: **identity / secrets vendors**, **engineer or support endpoint**, **broad downstream blast radius**.

## References
- [Okta security incident official update](https://sec.okta.com/articles/2023/10/tracking-unauthorized-access-oktas-support-system)
- [BeyondTrust analysis](https://www.beyondtrust.com/blog/entry/okta-support-unit-breach)
- [Cloudflare blog — investigation](https://blog.cloudflare.com/how-cloudflare-mitigated-yet-another-okta-compromise/)
- [1Password incident response](https://blog.1password.com/files/okta-incident-report.pdf)
- See also: [[case-study-snowflake-2024]], [[case-study-3cx-supply-chain]], [[third-party-saas-misconfig-patterns]], [[siem-detection-use-case-catalog]]
