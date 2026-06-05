---
title: API bug bounty workflow
slug: api-bug-bounty-workflow
aliases: [api-bb-workflow, api-hunting-method]
---

> **TL;DR:** APIs leak more business logic than HTML pages do, and they often skip the access-control layer that wraps the web UI. A repeatable hunting workflow — discover specs, catalogue endpoints, model identities, then hammer each operation against the OWASP API Top 10 — converts that into payouts. This note ties together the depth-vs-breadth tradeoff from [[api-fuzzing-wide-vs-deep]] with object-level bugs from [[bola]], schema-level bugs from [[mass-assignment]], and the GraphQL-specific surface in [[graphql-attacks]].

## Why it matters

Modern programs ship features through APIs first: mobile apps, SPAs, partner integrations, and internal microservices all consume the same REST/GraphQL/gRPC backends. Triage teams have learned that **API findings tend to score higher** than equivalent web findings because:

- Auth/authz is often enforced inconsistently across versions (v1 vs v2 vs v3).
- Schemas expose fields the UI never renders, opening [[mass-assignment]] and [[bfla]] doors.
- Rate limiting frequently lives only at the gateway, not at sensitive operations.
- A single broken endpoint can affect every client (web + iOS + Android + partners) simultaneously, which inflates impact in [[demonstrating-impact]] writeups.

If you are coming from web hunting, treat API work as a force multiplier on the same skills — see [[api-security]] and [[web-application-security]] for the technical primers, and [[bug-bounty-methodology]] for the program-level framing.

## Classes and patterns

### Discovery surfaces

The first job is to enumerate the API. Programs rarely hand you an OpenAPI spec, so you scrape it together from:

- **Public docs and spec files** — `/swagger`, `/swagger.json`, `/openapi.yaml`, `/api-docs`, `/v3/api-docs`, `/graphql` (introspection), `/.well-known/`, and developer portals. Search GitHub for `org:target openapi` and `org:target swagger`.
- **JS bundles** — sourcemaps and minified bundles routinely embed full endpoint lists. Tools like `linkfinder`, `getallurls`, and `jsluice` extract them. Cross-reference with [[expanding-attack-surface]] and [[getting-feel-for-target]].
- **Mobile apps** — APKs and IPAs expose endpoint lists, secrets, and undocumented routes. See [[apk-reverse-tools]], [[android-source-review-methodology]], [[ios-source-review-methodology]], and [[ssl-pinning-bypass]] / [[frida-hook]] for runtime capture.
- **Postman / Insomnia collections** — search the Postman public workspace and GitHub for collections leaked by partners.
- **Subdomain sweeps** — `api.`, `api-v2.`, `gateway.`, `internal-api.`, `partners.`. Combine with [[continuous-recon-automation]].
- **gRPC reflection** — call the `grpc.reflection.v1alpha.ServerReflection` service with `grpcurl -plaintext host:port list` to dump services. Many gRPC gateways forget to disable reflection in production.

### Endpoint cataloguing

Once you have raw URLs, build a structured catalogue before testing:

| Field | Why |
|---|---|
| Method + path | Distinguishes `GET /orders/{id}` from `PATCH /orders/{id}` |
| Auth requirement | Anonymous, user token, admin token, service token |
| Parameters (path/query/body) | Inputs to fuzz; flags type-confusion candidates |
| Response schema | Hints at fields you can inject via [[mass-assignment]] |
| Version | v1/v2/v3 — older versions often skip newer authz checks |
| Consumer | Web only, mobile only, partner only — narrower consumers see less testing |

This matrix is what turns ad-hoc poking into a [[testing-methodology-checklists]]-style sweep.

### Per-endpoint test plan

For every endpoint, walk the OWASP API Top 10:

1. **Authentication** — token type, expiry, refresh flow, JWT alg confusion ([[jwt]], [[jwt-key-confusion]]), OAuth quirks ([[oauth-modern-attacks]], [[oauth-flows]]).
2. **Object-level authz (BOLA)** — swap IDs across tenants; see [[bola]] and [[idor]]. UUIDs are not protection.
3. **Function-level authz (BFLA)** — call admin endpoints with user tokens; see [[bfla]] and [[broken-access-control]].
4. **Mass assignment** — add fields like `isAdmin`, `roleId`, `tenantId`, `ownerId` to write requests; see [[mass-assignment]].
5. **Parameter pollution** — duplicate keys (`?id=1&id=2`), array vs scalar, nested JSON arrays.
6. **Type confusion** — send strings as objects, numbers as strings, arrays as objects. NoSQL injection (`{"$ne": null}`) and SQL casting bugs both surface here.
7. **SSRF in webhook / image / URL fields** — `url`, `callback`, `avatar`, `import_from`. Chain to [[ssrf]], [[ssrf-to-cloud]], [[ssrf-to-cloud-advanced-chains]], [[aws-imds-ssrf-pivot]].
8. **Rate-limit bypass** — see workflow below.
9. **Excessive data exposure** — diff what the UI shows vs what the API returns; the API is usually noisier.
10. **Business-logic abuse** — race conditions on `POST /transfer`, negative quantities, replayed signatures, [[account-takeover-modern-chains]].

### GraphQL specifics

GraphQL APIs need their own playbook — see [[graphql-attacks]] and [[graphql-source-review]] for depth. The bug-bounty essentials:

- **Introspection** — try `{ __schema { types { name fields { name } } } }`. If disabled, fuzz with `clairvoyance` or field-name wordlists.
- **Aliasing for rate-limit / brute-force bypass** — one HTTP request, hundreds of `login` mutations via aliases.
- **Batched queries** — POST a JSON array of queries; many WAFs only inspect the first.
- **Persisted queries** — APQ (`sha256Hash`) often allows arbitrary queries when `?query=` is also accepted; check both modes.
- **Directives** — `@skip(if:false)`, `@include`, `@defer`, `@stream` can bypass field-level authz.
- **Nested object resolution** — request a sibling object through a relationship to dodge a missing [[bfla]] check on the direct endpoint.

### gRPC specifics

- Probe `ServerReflection` first; if reflection is off, extract `.proto` files from the mobile app or partner SDK.
- Use `grpcurl`, `ghz`, or Burp's gRPC support. Many auth interceptors check metadata only on top-level RPCs, not on streaming sub-messages.
- Look for HTTP/JSON transcoding gateways (`/v1/...` mapped to gRPC). The HTTP path frequently lacks the authz interceptor the native gRPC call has.

### SOAP and legacy

- Pull WSDL from `?wsdl`; tools like `wsdler` enumerate operations.
- XXE and entity expansion still land in 2026 on insurance/healthcare/government targets.
- Legacy endpoints often coexist with REST/GraphQL on the same host — verify scope with [[program-scope-reading]].

### Rate-limit bypass approaches

- Header tricks: `X-Forwarded-For`, `X-Real-IP`, `X-Originating-IP`, `True-Client-IP`, `CF-Connecting-IP` rotation.
- Path mutation: trailing slash, case change, URL-encoded characters, `;jsessionid=...`, double-slash.
- HTTP method swap: `POST` vs `PUT` vs `PATCH`.
- HTTP/2 multiplexing: rapid-reset patterns and stream-prioritisation games.
- GraphQL aliasing (above) and batched queries.
- Region pivot: `api-us.target.com` vs `api-eu.target.com` may share auth but have separate counters.

### Versioning across v1/v2/v3

Older versions are the most reliable money-makers:

- A field removed from v3's response may still appear in v1.
- v2 may enforce BOLA while v1 trusts the client-supplied tenant ID.
- Admin endpoints "deprecated" in docs are often still live and unauthenticated.
- Compare schemas with `diff` or `oasdiff`; every removed/changed field is a hypothesis.

## Defensive baseline

If you write a defender's section into a report (it raises payout quality — see [[report-writing]]):

- Single source of truth for authz: a middleware or interceptor every route inherits.
- Schema-driven serialisation (allow-list output fields per role) to kill [[mass-assignment]] and excessive data exposure.
- Object-level authz check at the data-access layer, not the controller.
- Disable introspection in production GraphQL; require persisted queries from web/mobile clients.
- Disable gRPC reflection outside staging.
- Per-operation rate limits keyed on user + IP + token fingerprint, enforced beyond the gateway.
- Deprecate old API versions hard: return `410 Gone`, not silent forwarding.

## Workflow to study

A repeatable hunt per target:

1. **Scope and select** — [[program-scope-reading]], [[scope-vertical-vs-horizontal]], [[target-selection-heuristics]], [[program-selection-tactics]].
2. **Acquire identities** — at least two same-tier user accounts plus, if possible, an admin invite. Without two accounts you cannot demonstrate [[bola]] / [[bfla]].
3. **Map surface** — discovery sources above; produce a single endpoint catalogue.
4. **Decide depth vs breadth** — [[api-fuzzing-wide-vs-deep]]. Wide for fresh targets, deep for crowded programs to dodge dupes ([[dupe-mental-model]]).
5. **Test per-endpoint matrix** — the 10 classes above, recording results in the catalogue.
6. **Chain findings** — a low-severity info-leak plus a BOLA equals account takeover ([[account-takeover-patterns]]).
7. **Stabilise PoC** — minimal repro, two-account video, version pin.
8. **Write up** — [[report-writing-step-by-step]], [[demonstrating-impact]], [[disclosure-and-comms]].
9. **Automate the recon tail** — [[automation-and-rinse-repeat]], [[continuous-recon-automation]] for spec diffs and new endpoints.
10. **Read disclosed reports weekly** — [[h1-disclosed-report-reading-method]], [[reading-public-pocs-effectively]], [[case-study-h1-top-disclosed-2024-2025]].

## Related

- [[api-fuzzing-wide-vs-deep]]
- [[bola]]
- [[bfla]]
- [[mass-assignment]]
- [[graphql-attacks]]
- [[graphql-source-review]]
- [[api-security]]
- [[jwt]]
- [[jwt-key-confusion]]
- [[oauth-modern-attacks]]
- [[ssrf]]
- [[account-takeover-modern-chains]]
- [[testing-methodology-checklists]]
- [[bug-bounty-methodology]]
- [[expanding-attack-surface]]

## References

- OWASP API Security Top 10 (2023): https://owasp.org/API-Security/editions/2023/en/0x11-t10/
- PortSwigger Web Security Academy — API testing: https://portswigger.net/web-security/api-testing
- Inon Shkedy — 31 Days of API Security Tips: https://github.com/inonshk/31-days-of-API-Security-Tips
- HackTricks — Pentesting Web / API: https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/
- grpcurl project (reflection and probing): https://github.com/fullstorydev/grpcurl
- clairvoyance GraphQL field inference: https://github.com/nikitastupin/clairvoyance
