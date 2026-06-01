---
title: API key auth
slug: api-keys
---

> **TL;DR:** Static API keys are bearer credentials with no expiry, often no scope, and frequently over-authorised. They leak via repos, mobile apps, JS bundles, and request logs — and one leak owns the tenant.

## What it is
An API key is a long random string the client sends on every request (header, query string, or basic-auth password slot) and the server treats as proof of identity. Unlike OAuth tokens, keys usually have no expiry, no audience, and no per-call signature — possession equals authority. Many platforms attach billing and admin permissions to the same key class.

## Preconditions / where it applies
- Anywhere a client app calls a backend with `X-Api-Key`, `Authorization: Bearer <static>`, `?api_key=`, or `?token=`
- Public mobile apps, browser SPAs, CI pipelines, IoT firmware
- Server logs, exception trackers, and CDN access logs that capture query strings

## Technique
1. **Find them.** Mine GitHub, GitLab, npm, public Docker images, mobile APKs, and SPA bundles:

   ```bash
   trufflehog github --org=target --only-verified
   gitleaks detect -v --source .
   # APK
   apktool d target.apk -o out && grep -RIn -E '[A-Za-z0-9_\-]{32,}' out/
   ```

2. **Classify.** Identify the vendor by prefix: `AKIA*` (AWS), `ghp_*` (GitHub), `xoxb-*` (Slack), `sk_live_*` (Stripe). [keyhacks](https://github.com/streaak/keyhacks) lists validation endpoints per vendor.
3. **Probe scope.** Hit a low-impact authenticated endpoint first to confirm liveness, then enumerate scopes (`/me`, `/account`, `/users`, billing endpoints).
4. **Pivot.** Many keys also unlock admin APIs that the original client never used. Read the vendor docs and brute-test the routes the legitimate client did not exercise.

Query-string keys leak especially badly — referer headers, CDN logs, browser history, and proxy caches all capture them.

## Detection and defence
- Treat key presence in any logged URL or stack trace as a leak; rotate immediately
- Pre-commit secret scanning (`gitleaks`, `trufflehog`) and CI gating on every push
- Scope keys: per-environment, per-tenant, per-endpoint group; never reuse one key across read and write paths
- Prefer short-lived tokens (OAuth / JWT with `exp`) over static keys; if static keys are unavoidable, require them in headers only and bind them to source IP or mTLS

## References
- [HackTricks: API keys](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/api-keys.html) — vendor list and validation endpoints
- [keyhacks](https://github.com/streaak/keyhacks) — scope-probing snippets per key prefix
- [OWASP API Security Top 10 2023 — Broken Authentication](https://owasp.org/API-Security/editions/2023/en/0xa2-broken-authentication/) — bearer-credential pitfalls
