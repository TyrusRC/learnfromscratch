---
title: Third-party SaaS misconfig — bug bounty patterns
slug: third-party-saas-misconfig-patterns
aliases: [saas-misconfig-bug-bounty, third-party-misconfig]
---

{% raw %}

> **TL;DR:** Modern attack surfaces include the SaaS tools a target uses — Slack, Jira, Notion, GitHub, Trello, Asana, ChatGPT, Linear, Mixpanel, Datadog. Bug-bounty patterns: (1) public spaces with sensitive content, (2) OAuth integration scope creep, (3) webhook secret leaks, (4) magic-link / share-link enumeration, (5) embedded credentials in support tickets, (6) SAML / SCIM misconfig, (7) federated identity hijacking. Companion to [[third-party-recon]] and [[oauth-modern-attacks]].

## Class 1 — public / unlisted spaces

SaaS tools default to private but include "share publicly" features. Targets sometimes leave artefacts public:

- **Trello boards** — `https://trello.com/b/<board-id>/<slug>` discoverable via Google.
- **Notion pages** — `<workspace>.notion.site/...` — published pages indexed by search engines.
- **GitHub gists** — secret gists are accessible by URL knowledge alone.
- **Confluence** — anonymous-access spaces.
- **Google Docs / Drive** — "Anyone with the link" defaults.
- **Mixpanel / Amplitude dashboards** — public link option.

Recon:
```text
site:trello.com inurl:<target>
site:notion.site "company.tld"
inurl:atlassian.net "<target>"
```

Findings: roadmaps, credentials in comments, customer lists, internal hostnames.

## Class 2 — OAuth integration scope creep

Target connects Slack/GitHub/etc. via OAuth. The OAuth app the target installed requested broad scopes. If the OAuth app itself is compromised (vendor-side), the target's data is exposed.

Bug-bounty: if the *target* shipped an OAuth integration with over-broad scopes (their app reads more than needed), low-impact but reportable.

## Class 3 — webhook secret leakage

Webhooks include secrets in the URL or header:
```
https://api.example.com/webhook?token=secret123
```

Or in env files, configs, CI logs. Public GitHub repos sometimes leak.

Recon:
```text
site:github.com "webhook" "token=" "<target>"
```

## Class 4 — share-link enumeration

Many SaaS tools generate share links like:
```
https://app.tld/share/<random-id>
```

If the random ID space is small or sequential, attacker enumerates.

- Google Docs "anyone with link" — historically used 32-char random; now longer.
- Dropbox shared links — 15-char base62.
- Notion publish — slugged with random suffix; many slugs are guessable.

For each new SaaS the target uses, test the share-link ID space.

## Class 5 — credentials in support tickets

Customer support tools (Zendesk, Intercom, Help Scout) frequently contain:
- Screenshots with credentials visible.
- Pasted error messages including connection strings.
- File attachments with config dumps.

If you have legitimate access (employee, beta customer), audit your own org's support; for bug bounty, this is *only* in scope if explicitly allowed.

## Class 6 — SAML / SCIM misconfig

SaaS supports enterprise SAML SSO and SCIM provisioning. Bugs:

- **SCIM endpoint exposed without auth** — attacker creates new users in target's SaaS via SCIM, bypassing SSO.
- **SAML EntityID mismatch** — attacker registers their own IdP; backend doesn't check EntityID; auth succeeds.
- **SP-initiated SSO without forced enforcement** — users can still log in with passwords.
- **Just-in-time provisioning** — attacker IdP creates accounts with arbitrary email claims.

See [[saml-attacks]], [[saml-xsw-attacks]], [[parser-differential-saml-ruby]].

## Class 7 — federated identity hijacking

OIDC discovery / well-known endpoints:
```
https://app.tld/.well-known/openid-configuration
```

If the discovery document points at an attacker-controlled `issuer` (DNS takeover, subdomain hijack of the `iss` host), the attacker becomes the IdP for app.tld.

## Class 8 — magic links

Some SaaS use magic links (URL with token) for password-less login.

- **Token not single-use** — replayable.
- **Token in Referer** — Slack rich preview fetches the URL.
- **Token email-aliased**: link sent to victim's `+` aliased address (`user+slack@gmail.com`); attacker registers `user@gmail.com` first → owns both.

## Class 9 — SaaS in target's GitHub Actions

Target's repo CI/CD references SaaS APIs (Datadog, Slack notifications, deployment platforms). The OAuth tokens are GitHub Secrets. Bugs:

- **GitHub Secrets exfil** — see [[github-actions-workflow-source-audit]] for expression-injection paths.
- **OIDC trust policy allowing the target's repo to mint tokens for the SaaS** — over-broad.
- **Third-party action with attacker-injected steps** — tj-actions-style ([[tj-actions-tag-mutation]]).

## Class 10 — embedded analytics / chat widget keys

Target embeds a chat widget (Intercom, Drift) with a publishable API key. Bugs:
- The publishable key has more permissions than intended.
- The widget exposes internal customer attributes via JS objects.
- The widget posts to an analytics API; that API returns data of other customers.

Recon: open the target's site, view source, find `intercom`, `drift`, `mixpanel` keys. For each, check the vendor's docs for what the key can do.

## Class 11 — Mailgun / SendGrid / Postmark abuse

Target's outbound mail provider — if API keys leak:
- Attacker sends mail from target's domain.
- Reads mail logs (open/click events leak customer behaviour).
- Modifies templates that customers receive.

API keys often leak in mobile app reverse-engineering or in misconfigured client-side JS.

## Class 12 — feature-flag service mistakes

LaunchDarkly, Split.io, ConfigCat. If client-side SDK key leaks (often does — it's by design):
- Attacker reads all flag values, including pre-release feature names.
- Some flags' targeting rules leak user attributes (email patterns of beta cohort).

The bug-bounty report is usually "internal feature names + targeting attribute leak via client-side SDK key".

## Recon workflow

1. Enumerate the target's third-party SaaS — observe their site for embedded widgets, their LinkedIn jobs for tooling references, their GitHub for integration repos.
2. For each SaaS, list known unauthenticated endpoints.
3. Test default share-link patterns.
4. Test their OAuth callbacks.
5. Test SCIM if exposed.
6. Check vendor's public bug-bounty for known attack patterns.

## Reporting

- Identify the third-party clearly — bounty platforms often require evidence the bug is on the *target*'s configuration, not the vendor's product.
- Show data leaked.
- Recommend the config change.

## Defence

- Annual SaaS inventory.
- SSO + MFA on every SaaS, no password-only fallback.
- SCIM provisioning only.
- Webhook secrets rotated; verification mandatory.
- Public share-links audited for sensitive content.
- Vendor-risk reviews for each integration's scope.

## References
- [HackerOne reports — SaaS misconfig](https://hackerone.com/reports?filter%5Bweakness%5D=MISCONFIG)
- [Cloud Security Alliance — SaaS Risk](https://cloudsecurityalliance.org/research/)
- [Wiz — SaaS posture management](https://www.wiz.io/)
- [LearnNotion / Notion docs on publishing](https://www.notion.so/help)
- See also: [[third-party-recon]], [[oauth-modern-attacks]], [[github-actions-workflow-source-audit]], [[saml-attacks]]

{% endraw %}
