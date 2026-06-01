---
title: BFLA — Broken Function Level Authorization
slug: bfla
---

> **TL;DR:** A lower-privilege caller invokes an endpoint or HTTP method that should be reserved for a higher role — typically because authorisation is enforced in the UI, not the server.

## What it is
Broken Function Level Authorization (API Top 10 #5, 2023) happens when the server trusts that only admins know about admin endpoints, or that only admins use the admin UI. The vulnerability lives in the gap between "hidden in the client" and "blocked by the server". Compared to [[bola]] (wrong object), BFLA is about the wrong action: deletion, role change, configuration write, impersonation.

## Preconditions / where it applies
- An authenticated low-privilege account
- Knowledge of higher-privilege endpoints (from admin user JS, spec leak, or guessable patterns like `/admin/`, `/internal/`, `/v1/users/{id}/role`)
- Server that authenticates the caller but does not re-check role per function

## Technique
1. Enumerate admin/manager surfaces. Diff the JS bundle a privileged user loads against the one a regular user loads — extra routes are usually admin endpoints. Check [[swagger-discovery]] for hidden tags like `x-admin: true`.
2. Replay each admin call with a low-privilege token:

   ```http
   PATCH /api/v1/users/42 HTTP/1.1
   Authorization: Bearer <low-priv-token>
   Content-Type: application/json

   {"role":"admin"}
   ```

3. Verb-swap. A `GET /api/admin/reports` may be blocked while `POST` or `PUT` against the same path is not. Try every method including `HEAD`, `OPTIONS`, `PATCH`.
4. Path-tier tricks. Some gateways only enforce auth on exact prefixes — try `/api/v1/Admin/...`, `/api/v1//admin/`, `/api/v1/admin/../admin/users`.
5. Version downgrade. If `/v2/admin/users` is locked, `/v1/admin/users` may have shipped before auth middleware existed.
6. Look for client-side gates: a UI that hides a button but still ships the JS for the call is a strong signal the server never re-checks.

## Detection and defence
- Log and alert on calls to admin-tagged endpoints by non-admin principals
- Enforce role-required decorators centrally (middleware, policy engine) rather than ad-hoc per handler
- Default-deny on new endpoints; require an explicit `@requires_role` annotation
- Treat HTTP method as part of the authorisation decision — do not share role checks across verbs
- Penetration-test with at least two roles and two tenants every release

## References
- [OWASP API #5 BFLA (2023)](https://owasp.org/API-Security/editions/2023/en/0xa5-broken-function-level-authorization/) — definition and examples
- [PortSwigger: access control](https://portswigger.net/web-security/access-control) — function-level vs object-level
- [HackTricks: authentication bypass](https://book.hacktricks.wiki/en/pentesting-web/login-bypass/index.html) — adjacent verb/path bypasses
