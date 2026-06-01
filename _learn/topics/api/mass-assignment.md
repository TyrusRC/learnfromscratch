---
title: Mass assignment
slug: mass-assignment
---

> **TL;DR:** The handler deserialises the request body straight onto a model object, so any field the model exposes — `is_admin`, `verified`, `tenant_id`, `price` — can be set by the caller.

## What it is
Frameworks like Rails (`update_attributes`), Django (`__dict__.update`), Spring (`@ModelAttribute`), Laravel (`fill`), and Express + Mongoose (`Object.assign`) make it trivial to map a JSON body to model fields in one call. Without an explicit allowlist of permitted fields, attributes never shown in the UI are still writable. This sits under API Top 10 #3 (2023, "Broken Object Property Level Authorization").

## Preconditions / where it applies
- A `POST`/`PUT`/`PATCH` endpoint that binds JSON to an ORM/ODM model
- Model contains sensitive fields the API surface does not intend to expose
- No `strong_parameters`, `serializer` allowlist, or DTO layer between transport and persistence

## Technique
1. Find an object-shaped endpoint. `GET /api/v1/users/{id}` reveals the model shape:

   ```json
   {"id":42,"email":"u@x","displayName":"u","role":"user","emailVerified":false,"tenantId":"t1"}
   ```

2. Replay `PATCH` (or whichever update verb) and append the interesting fields:

   ```http
   PATCH /api/v1/users/42 HTTP/1.1
   Authorization: Bearer T
   Content-Type: application/json

   {"displayName":"x","role":"admin","emailVerified":true,"tenantId":"t-victim"}
   ```

3. If you don't have a GET that returns the shape, guess common names: `role`, `isAdmin`, `is_staff`, `permissions`, `price`, `discount`, `balance`, `verified`, `enabled`, `owner_id`.
4. Try nested objects: `{"user":{"role":"admin"}}`, arrays for relationship overwrites, and JSON-pointer-style traversal in GraphQL.
5. Type-juggle: send `"role": ["admin"]` or `"role": {"$set":"admin"}` against NoSQL backends.
6. On registration endpoints, ship the privileged field at create-time — many apps only allowlist on update.

## Detection and defence
- Use explicit DTOs / serializers with an allowlist of accepted fields; reject unknowns rather than silently dropping them
- Frameworks: Rails `strong_parameters`, Django REST Framework `Meta.fields`, Spring `@JsonView` or dedicated request classes, Mongoose `select: false` + manual assignment
- Separate read and write schemas so sensitive fields are write-only-by-admin
- Log unexpected fields per endpoint and alert; legitimate clients send a fixed shape
- Pair with [[bola]] and [[bfla]] testing — mass assignment becomes catastrophic when combined with weak object/function checks

## References
- [HackTricks: mass assignment](https://book.hacktricks.wiki/en/pentesting-web/mass-assignment.html) — payload patterns
- [OWASP API #3 BOPLA (2023)](https://owasp.org/API-Security/editions/2023/en/0xa3-broken-object-property-level-authorization/) — definition and prevention
- [PortSwigger: server-side parameter pollution](https://portswigger.net/web-security/api-testing/server-side-parameter-pollution) — adjacent class, parameter-level abuse
