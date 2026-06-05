---
title: Case study — Snowflake customer-tenant breaches (2024)
slug: case-study-snowflake-2024
aliases: [snowflake-2024-incident, snowflake-tenant-breach]
---

> **TL;DR:** In 2024 a series of high-profile data breaches at Snowflake-using companies (Ticketmaster, Santander, AT&T, others) traced not to a Snowflake platform vulnerability but to **infostealer-harvested customer credentials** combined with Snowflake tenants that had not enforced MFA. The attacker logged in legitimately with valid passwords; Snowflake's auditing was clean. Defining incident for the "no MFA, no defence" SaaS-tenant model. Companion to [[case-study-3cx-supply-chain]] and [[case-study-okta-2023-support-system]].

## Why this matters

- It's the **largest 2024 breach cluster** by record count.
- The root cause is **operator MFA hygiene**, not vendor bug. The lesson generalises to every SaaS-tenant model.
- Infostealer ecosystems became operational risk: a developer's home PC running an infostealer surrendered enterprise SaaS access.
- Showed how SaaS tenants must enforce identity controls; default-optional MFA is now treated as a vendor failure.

## The chain

1. A user (developer, contractor, third-party) on a personal or contractor machine got infected by an infostealer (Lumma, RedLine, Vidar, others).
2. Infostealer captured all stored credentials — Snowflake logins included.
3. Stealer logs traded / sold on stealer-log marketplaces.
4. A threat actor (publicly tracked as "ShinyHunters") purchased / aggregated logs, searched for `*.snowflakecomputing.com` URLs.
5. For each matching credential, attempted login with the username/password.
6. For tenants without MFA enforced: success.
7. Bulk-exported customer data via Snowflake's standard query interfaces.

No exploits. No vulnerabilities. Just creds + missing MFA.

## Why MFA was missing

Snowflake at the time supported MFA but did not enforce it by default. Enterprise tenants needed to configure MFA per user, and many did not — particularly for contractor / service / pipeline accounts.

The blast radius for one missed account was the **entire data warehouse** that account had access to.

## Detection and post-incident posture

- Snowflake's audit log captured the logins, but they looked legitimate (correct password, normal endpoint).
- IOCs were geographic / IP-based (logins from threat-actor IPs) and behavioural (sudden bulk export).
- After-the-fact, Snowflake mandated MFA and added enforcement controls. Customers had to audit historical exports.

## What this teaches

- **Credentials are not a control surface** in a world with effective infostealers. Treat passwords as known.
- **Default-MFA, not default-optional.** Vendor failure when MFA is opt-in for a tenant.
- **Service accounts are humans-in-disguise** for stealer purposes — if any human can log in as the service, the human's stealer can.
- **Bulk-export rate limits / volume anomalies** should alert by default. Customer-controlled data warehouses had no volume gate.
- **Stealer-log monitoring** as a CTI capability — services like SpyCloud, Hudson Rock, Constella surface compromised credentials early.
- **Network egress filtering** on production accounts — bulk export to external IPs should trip controls.

## Where the responsibility lies

Public discussion settled on a shared model:
- **Vendor** must offer enforceable MFA, default-on, and tenant-admin policy controls.
- **Customer** must enforce MFA on every account including services.
- **Identity provider (IdP)** integration with SaaS via SSO short-circuits the password-as-control failure.

Snowflake updated tenant defaults in mid-2024 to push MFA enforcement.

## IR posture for similar incidents

If you suspect SaaS-tenant compromise via stealer-credential reuse:

1. **Identify scope.** Which user accounts have logged in from anomalous IPs.
2. **Reset and rotate.** Passwords, API tokens, OAuth-issued keys.
3. **Audit data export volumes.** Snowflake has query history; compare against the recent 90-day baseline.
4. **Notify** downstream customers / users whose data was in the exported tables.
5. **Force-enable MFA / move to SSO** as a precondition for restoring access.
6. **Hunt for persistence** — newly-created service accounts, modified roles, scheduled queries.
7. **Stealer-log subscription** for ongoing detection.

See also: [[ir-from-source-signals]].

## Detection use cases (SIEM)

Mapped into [[siem-detection-use-case-catalog]]:

- Login from an unrecognised geo for a user who hasn't travelled.
- Login from a residential ISP for a service account.
- Bulk export query exceeding the user's historical max by N×.
- Snowflake "create user / modify role" by a service identity.
- Snowflake user without MFA when policy requires it.

## Generalising the lesson

Every SaaS tenant model has this shape:

- Username + password authenticates from anywhere.
- Customer is responsible for MFA.
- Vendor logs are clean for legitimate logins.

The 2024 cluster popped Snowflake; the 2025+ analogues will be the next platform with the same defaults. Audit your **SaaS portfolio** for:

- Which tenants don't enforce MFA.
- Which service accounts are exempt.
- Whether the tenant supports SSO and you've enabled it.
- Whether the vendor's IP allowlist is in use.

## References
- [Mandiant — Snowflake-related incident report](https://cloud.google.com/blog/topics/threat-intelligence/unc5537-targets-snowflake-customer-instances)
- [CrowdStrike, Mandiant, Snowflake joint statement](https://www.snowflake.com/en/blog/detecting-mitigating-targeted-attacks/)
- [Snowflake post-incident customer guidance](https://community.snowflake.com/s/article/Snowflake-Customer-Investigation-Update)
- See also: [[case-study-3cx-supply-chain]], [[case-study-okta-2023-support-system]], [[third-party-saas-misconfig-patterns]], [[siem-detection-use-case-catalog]]
