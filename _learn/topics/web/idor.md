---
title: Insecure direct object reference (IDOR)
slug: idor
---

> **TL;DR:** Object identifier in the request maps directly to a resource without an authorisation check.

## What it is
The endpoint trusts the client to pick the object it operates on (`GET /api/invoice/4711`, `POST /user/{uid}/email`). The server authenticates the caller but never verifies the caller owns or has rights to that object. Swap the id, get someone else's data — or modify it. This is the bulk of access-control bugs in real apps.

## Preconditions / where it applies
- Authenticated endpoint that takes an object id from path / query / body / header
- No tenant/owner check ties the id back to the caller's principal
- Predictable / enumerable ids (sequential integers, short UUIDs, base64 of int)

## Technique
1. **Map ids** — proxy your own session, label every numeric/uuid/slug in requests as `MY_*`. Look for: user id, account id, order id, doc id, message id, tenant id, file id.
2. **Swap horizontally** — replace `MY_USER_ID` with `OTHER_USER_ID` (create a second test account). 200 OK + other user's data == IDOR.
3. **Swap vertically** — replace with an admin-owned id (small numbers like 1/2/3 often reach admins). Or hit `/admin/users/{id}` as a normal user.
4. **Method confusion** — IDOR may only exist on certain verbs. Try GET → PUT → DELETE → PATCH on the same path.
5. **Parameter pollution** — duplicate the id parameter (`?id=mine&id=theirs`) — server picks one for authz, another for query ([[http-parameter-pollution]]).
6. **Mass assignment** — set extra fields like `"role":"admin"` or `"userId":42` in a JSON body to a self-update endpoint.
7. **Bypass with encoding** — `1` vs `1.0` vs `01` vs `1%00` vs `1/` vs `[1]` vs JSON array — different parsers, different authz outcomes.
8. **Indirect references** — even UUIDs leak via referers, emails, public URLs, JSON responses from other endpoints. Hunt UUIDs in any unauthenticated response.
9. **GraphQL IDOR** — `node(id:"…")` global object fetcher, or `user(id:…)` field that ignores caller; introspect to find every id-taking field ([[graphql-attacks]]).
10. **File / blob URLs** — `s3://bucket/avatar/{uid}.png`, predictable signed-URL parameters.

## Detection and defence
- Authorise by **principal + action + object** on every request; never trust client-supplied owner ids.
- Use indirect references where feasible (session-scoped tokens map server-side to real ids).
- Add ABAC/RBAC checks in middleware, not per-endpoint — easier to audit.
- Test in CI: for every endpoint, send request as user B with user A's id, assert 403.
- Log + alert on cross-tenant id access patterns.
- Related: [[broken-access-control]], [[graphql-attacks]], [[application-logic-flaws]], [[mass-assignment]] (if present), [[http-parameter-pollution]].

## References
- [PortSwigger — IDOR](https://portswigger.net/web-security/access-control/idor) — labs and theory
- [OWASP — access control cheat sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html) — defensive patterns
- [HackerOne — IDOR write-ups](https://hackerone.com/hacktivity?searchTerm=idor) — real reports
