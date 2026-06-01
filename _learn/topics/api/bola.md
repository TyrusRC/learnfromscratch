---
title: BOLA — Broken Object Level Authorization
slug: bola
---

> **TL;DR:** An endpoint accepts an object ID and returns or mutates the object without verifying the caller owns it. IDOR for APIs — and the most-reported class in the API Top 10.

## What it is
Broken Object Level Authorization (API Top 10 #1, 2023) is the failure to check, for each request, that the authenticated principal is allowed to act on the specific object identified by the request. Server authenticates the user, looks up the object by the supplied ID, and skips the ownership check. Severity scales with the verb: read leaks data, write tampers, delete destroys.

## Preconditions / where it applies
- An endpoint with an object identifier in the path, query, or body (`/orders/123`, `/users/{id}`, `{"accountId": "..."}`)
- At least one authenticated identity (BOLA without auth is just an unauthenticated dump)
- Predictable IDs help (integers, sequential UUIDs) but opaque IDs still fall to leak-then-replay across tenants

## Technique
1. Build two accounts in two tenants. Capture every authenticated request from account A.
2. Replay each request using account B's token but A's IDs. Diff responses:

   ```http
   GET /api/v1/orders/10001 HTTP/1.1
   Authorization: Bearer <token-B>
   ```

   `200` with A's data is the bug. `403`/`404` means the check works for this verb.

3. Test every verb on the same path. Read might be checked, update/delete frequently are not.
4. Look in non-obvious places: webhook callbacks, export jobs, search filters (`?accountId=A`), GraphQL node IDs, and second-order references in nested JSON.
5. Try ID smuggling: send both IDs (`/orders/A?accountId=B`), array forms (`{"id":[A,B]}`), and casing/encoding (`%32%30` vs `20`). Some middlewares authorise on one form while the handler reads the other.
6. Auto-discover with `autorize` (Burp extension) or `IDOR-Hunter`-style replay frameworks.

## Detection and defence
- Centralise object lookup in a function that requires `(principal, action, object)` and refuses if the policy says no — never hand-write checks per handler
- Audit logs: alert on cross-tenant access patterns (one principal reading many distinct tenant IDs)
- Prefer scoped queries: `Order.where(user_id=current_user.id, id=requested_id)` rather than `Order.find(requested_id)` then check
- Treat opaque IDs as defence in depth, not authorisation — they slow down enumeration but do not stop leak-then-replay
- Related: [[bfla]] for the action-level twin

## References
- [OWASP API #1 BOLA (2023)](https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/) — canonical definition
- [PortSwigger: IDOR](https://portswigger.net/web-security/access-control/idor) — same class, web framing
- [HackTricks: IDOR](https://book.hacktricks.wiki/en/pentesting-web/idor.html) — variants and bypasses
