---
title: API threat modeling
slug: api-threat-modeling
---

> **TL;DR:** Before fuzzing, map the API: trust boundaries, identity classes, object ownership, and data sinks. This produces a test matrix that beats blind scanning every time.

## What it is
A short pre-engagement exercise that turns an opaque API into a structured target. The output is a list of endpoints annotated with: who can call them, what objects they touch, what side effects they cause, and which Top-10 classes are plausible. The matrix becomes the test plan.

## Preconditions / where it applies
- At least partial knowledge of the API (spec, captured traffic, or client app)
- Two test identities minimum (low-privilege + high-privilege) in two tenants — required for [[bola]] / [[bfla]]
- Time budget — modelling is cheap compared to fuzzing time saved

## Technique
1. **Inventory endpoints.** Pull the spec ([[swagger-discovery]]), spider the SPA, capture mobile traffic. Normalise to `METHOD path params`.
2. **Classify by verb.** Reads (GET), creations (POST), updates (PUT/PATCH), deletions (DELETE), actions (POST `/foo/{id}/action`). Each verb maps to a different abuse class.
3. **Identify objects.** For every path parameter, ask: is this an opaque ID? A UUID? A tenant ID? Predictable IDs feed [[bola]] tests; opaque IDs need leak-then-replay.
4. **Identify identities and roles.** Owner, member, viewer, admin, service account, anonymous. Build a 2D matrix: roles x endpoints. Cells where a low role unexpectedly works are [[bfla]] findings.
5. **Mark excessive-data sinks.** Endpoints that return whole objects (`GET /users/{id}`) are candidates for excessive data exposure; endpoints that accept whole objects (`PUT /users/{id}`) are candidates for [[mass-assignment]].
6. **Flag rate-sensitive paths.** Login, password reset, payment, OTP — every one needs [[rate-limit-bypass]] testing.
7. **Note trust boundaries.** Calls from public clients vs internal services vs partners — each boundary is a place where auth might be missing or differ.

The deliverable is a CSV or sheet keyed by endpoint with columns for each Top-10 class, marked plan/skip/done.

## Detection and defence
- Engineering teams should run the same exercise — design-time threat modelling catches most issues before code ships
- Tag every endpoint in code with its required scope/role; gateways then enforce uniformly
- Document object-ownership rules per resource type and assert them in middleware, not per-handler
- Maintain a living inventory; orphaned endpoints are a leading cause of [[bola]] and [[bfla]] in real audits

## References
- [OWASP API Security Top 10 2023](https://owasp.org/API-Security/editions/2023/en/) — class list to populate the matrix
- [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/) — methodology backbone
- [Hacking APIs (No Starch Press)](https://nostarch.com/hacking-apis) — chapter on test planning
