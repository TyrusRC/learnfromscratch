---
title: Case study — H1 top-disclosed 2024–2025
slug: case-study-h1-top-disclosed-2024-2025
aliases: [h1-top-disclosures-recent, h1-case-study-recent]
---

> **TL;DR:** A walk through the *shape* of high-bounty H1 disclosures from 2024–2025 — not the specific payloads, but the patterns that keep paying. Recurring themes: account-takeover chains via auth-adjacent endpoints, SSRF-to-cloud-metadata in modern multi-tenant SaaS, IDOR through GraphQL aliasing, OAuth flow misuse, and supply-chain via package or workflow. Use this as a pre-condition checklist on your next target. Companion to [[h1-disclosed-report-reading-method]] and [[account-takeover-modern-chains]].

## Pattern 1 — Account takeover via second-step IDOR

Repeating shape:

- Step 1: forgot-password / change-email / 2FA-enable starts and emits a token tied to userId-in-cookie.
- Step 2: a separate endpoint *consumes* the token — but takes the target email or userId from the request body, not the session.
- Hunter swaps the body field; victim email / userId is accepted.

Look for it whenever you see a two-step flow where the second step takes any identifier in its body. See [[account-takeover-modern-chains]], [[account-recovery-attacks]].

H1 examples to study: GitLab "merge train" CSRF chains, Shopify SSO-binding-via-email reports, several account-merge bugs across SaaS programs.

## Pattern 2 — SSRF to cloud metadata via image / PDF / preview / OG-card

Repeating shape:

- App takes a user-supplied URL for a thumbnail / OG image / PDF render / link preview.
- App fetches it server-side; either no filter, or filter that's bypassed by `0.0.0.0`, IPv6, DNS rebinding, redirect-chain.
- Internal endpoint hit: cloud metadata, Consul, internal admin, or a private API that trusts the source IP.

H1 examples: many on GitLab, GitHub, Lyft, Slack, several open-source SaaS programs. See [[ssrf-to-cloud-advanced-chains]].

## Pattern 3 — GraphQL aliasing / batching to amplify

Repeating shape:

- API rate-limits per request, not per operation.
- Hunter sends a single GraphQL query with 100 aliased copies of a mutation.
- 100x impact: 100 OTP guesses, 100 password resets, 100 followers.

H1 examples: numerous OTP-brute / promo-code abuse / vote-stuffing reports across SaaS programs. See [[graphql-batching-aliasing-abuse]] and [[rate-limit-bypass]].

## Pattern 4 — OAuth `redirect_uri` parsing flaw

Repeating shape:

- App allows OAuth flow with a `redirect_uri` matched by prefix, substring, or path-regex.
- Hunter finds a URL on the allowlisted domain that reflects or redirects (open redirect / postMessage / hash-fragment).
- Auth code or access token lands at attacker's listener.

Variations: literal substring matching of `redirect_uri=https://victim.com.attacker.com`, encoded fragments, path traversal in path-regex. See [[oauth-modern-attacks]] and [[oauth-token-theft]].

H1 examples: high-bounty reports across SaaS authn flows, including reports on PayPal-tier programs.

## Pattern 5 — Subdomain takeover via cloud product

Repeating shape:

- CNAME → freed cloud product (S3 bucket, Heroku app, GitHub Pages, Azure CDN, Netlify, Vercel).
- Hunter recreates with same name.
- Now they serve content on a trusted subdomain — credential theft, OAuth flow takeover, cookie scope abuse.

H1 examples: thousands of reports across all SaaS programs. The hard part is *which cloud-product* — see [[subdomain-takeover]].

## Pattern 6 — Auth bypass via path-prefix middleware

Repeating shape:

- App uses a path-prefix to gate admin endpoints (`/admin/*` requires admin role).
- Middleware checks the path *literal* before normalisation.
- Hunter sends `/admin/../admin/dashboard` or `//admin/dashboard` and bypasses.

H1 examples and CVEs: `next-auth` middleware issues, Fastify routing nuances, Express-mounted-app scoping bugs. Related: [[nextjs-middleware-cve-2025-29927]].

## Pattern 7 — IDOR through tenant-id in JWT

Repeating shape:

- Multi-tenant SaaS embeds `tenantId` in JWT.
- Backend trusts `tenantId` from the JWT, but some endpoints take `tenantId` in the path or body and use *that*.
- Hunter sends a path with another tenant's id; access granted.

H1 examples: pervasive across multi-tenant SaaS. The fix is to derive tenantId only from the JWT-bound session. See [[bola]], [[broken-access-control]].

## Pattern 8 — Self-XSS amplified via login CSRF

Repeating shape:

- App has self-XSS in user-controlled profile/notes/markdown.
- Login flow lacks CSRF protection.
- Attacker forces victim to log into attacker's account → triggers self-XSS in victim browser → steals victim's cookies for other apps (cross-domain via session sharing).

Self-XSS is "not a bug" only when there's no chain. With login CSRF, the chain pays. See [[onsite-request-forgery]] and [[cross-site-scripting]].

## Pattern 9 — Cache-key normalisation flaw

Repeating shape:

- Edge cache uses canonical path as key.
- App differs from edge in URL normalisation (`/path`, `/path/`, `/PATH`, `/path;param=`).
- Hunter poisons cache on a normalised key, victim hits the poisoned response.

Or the inverse — cache deception: store private response under a public key. See [[cache-poisoning-modern-chains]] and [[cache-deception]].

## Pattern 10 — Supply-chain via CI / workflow

Repeating shape:

- Public repo's CI workflow uses `pull_request_target` with checkout of PR HEAD.
- PR contributor edits the workflow itself or a script invoked by the workflow.
- CI runs the attacker code with secrets of the parent repo.

H1 / public examples: long string of `pull_request_target` advisories on major OSS repos. See [[github-actions-workflow-source-audit]], [[gha-oidc-sub-claim-wildcards]].

## How to use this list

When you start a target:

1. Map endpoints by **shape**: which look like step-2-of-flow? which take a URL parameter? which look like multi-tenant gate? which involve OAuth?
2. For each, run the **pattern probe**: a single test that confirms or rules out the pattern.
3. Spend time only on patterns the target plausibly has.

This is faster than running a full methodology on every endpoint.

## What the reports don't tell you

- The hunter's **dead ends**. They tested ten other endpoints before finding the bug. Their notes look organised in disclosure; they weren't during testing.
- The **dupe rate**. Many of these patterns are first-blood-takes-all. Repeating the same hunt elsewhere is often a lottery.
- The **chained signal**. The hunter found pattern N because they were already mid-chain on patterns N-1 and N-2. Single-bug hunters miss the chain.

See also: [[hacker-mindset-questioning]], [[expanding-attack-surface]].

## References
- [HackerOne hacktivity](https://hackerone.com/hacktivity)
- [GitLab disclosed reports](https://hackerone.com/gitlab/hacktivity)
- [Shopify disclosed reports](https://hackerone.com/shopify/hacktivity)
- [Pentesterland — writeups index](https://pentester.land/list-of-bug-bounty-writeups.html)
- See also: [[h1-disclosed-report-reading-method]], [[account-takeover-modern-chains]], [[ssrf-to-cloud-advanced-chains]], [[third-party-saas-misconfig-patterns]]
