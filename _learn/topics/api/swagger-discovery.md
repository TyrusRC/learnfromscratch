---
title: Swagger / OpenAPI discovery
slug: swagger-discovery
---

> **TL;DR:** A published OpenAPI/Swagger spec hands you every endpoint, parameter type, required scope, and example payload. Step one of API testing is finding it.

## What it is
OpenAPI (formerly Swagger) is a machine-readable description of an HTTP API: paths, methods, parameters, request/response schemas, security requirements. Internal teams ship it for code generation and developer UX; many forget to lock it down in production. Once you have the spec, [[api-content-discovery]] is mostly done — feed the spec into a fuzzer ([[api-fuzzing-wide-vs-deep]]) and start hitting endpoints.

## Preconditions / where it applies
- An API that uses Swagger/OpenAPI internally (modern microservice stacks almost always do)
- Some entry point: the API base URL, the SPA that uses it, or a developer portal subdomain

## Technique
1. **Try canonical paths** — most servers leave them on:

   ```
   /swagger.json        /swagger.yaml
   /openapi.json        /openapi.yaml
   /v2/api-docs         /v3/api-docs          (Springfox / springdoc)
   /api-docs            /api/docs
   /swagger-ui.html     /swagger-ui/index.html
   /swagger/            /docs                 /redoc
   /.well-known/openapi
   ```

   Add `?format=openapi`, `?format=json`, `?spec=true`. Use `ffuf` or `kr scan` with a Swagger-specific wordlist.

2. **Hunt subdomains.** `developer.target.com`, `docs.target.com`, `api.target.com/docs`, `internal-api.target.com`. Many companies publish prod specs on dev portals.
3. **Mine JS bundles.** SPAs occasionally embed the spec or hit a `?_spec=1` endpoint. Grep for `"openapi"`, `"swagger"`, `"paths"`.
4. **Parse and weaponise:**

   ```bash
   curl -s https://target/openapi.json > spec.json
   # list endpoints
   jq -r '.paths | to_entries[] | "\(.key) \(.value | keys[])"' spec.json
   # generate requests
   schemathesis run --base-url=https://target spec.json --checks all
   ```

5. **Inspect security schemes.** The `securitySchemes` block tells you exactly which auth header to send. The `security` array per endpoint reveals which routes are public — those are the natural starting points.
6. **Look for excess detail.** Specs often expose internal-only routes, debug endpoints, and example payloads that include real-looking IDs and emails — useful for [[bola]] testing.

## Detection and defence
- Do not serve the spec in production unless required; gate `/openapi.json` and `/swagger-ui` behind auth or strip them from the prod build
- If exposed for partners, serve a redacted spec — strip internal tags (`x-internal`, `x-admin`), examples, and deprecated routes
- Log retrieval of spec endpoints and alert on bursts from new IPs
- Treat the spec as inventory: every endpoint it lists must have a current owner and an enforced auth policy ([[api-threat-modeling]])

## References
- [HackTricks: Swagger / OpenAPI](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/swagger-api.html) — discovery paths
- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html) — official spec
- [Schemathesis](https://schemathesis.readthedocs.io/) — turn a spec into a test suite immediately
