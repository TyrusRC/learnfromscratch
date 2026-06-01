---
title: Broken Access Control (BAC)
slug: broken-access-control
---

> **TL;DR:** Any request reaches a resource or action the caller should not be allowed to touch — the umbrella over [[idor]], vertical privilege escalation, method/route mismatches, and tenant crossing.

## What it is
Access control is the set of checks that decide whether the authenticated principal is allowed to perform this operation on this object. BAC is the family of failures where those checks are missing, inconsistent, or trusted to the client. It is consistently the largest single category of real-world vulnerabilities and bug-bounty payouts.

## Preconditions / where it applies
- A multi-user or multi-tenant app with resources scoped by id, slug, or path.
- Role separation (user / admin / support) or per-resource sharing (owner / editor / viewer).
- REST, GraphQL, RPC, or server-rendered apps — language and stack agnostic.

## Technique
Work systematically; BAC is found by comparing what one principal can do against what another principal should be allowed to do.

1. **Map the role matrix.** Enumerate roles (anonymous, low-priv, peer, admin) and resource types. Capture a full session per role with Burp.
2. **Horizontal — peer to peer.** Replay a request from user A with user B's session cookie. Change ids (numeric, UUID, slug, base64) one at a time. This is classic [[idor]]:

   ```http
   GET /api/orders/1042 HTTP/1.1
   Cookie: session=<userB>
   ```

3. **Vertical — low to admin.** Take admin URLs you observed (`/admin/users`, `/api/v2/internal/*`) and replay them with a low-priv cookie. Many apps hide admin links in the UI but never check on the server.
4. **Method swap.** `GET /api/user/42` is gated but `PUT /api/user/42` or `DELETE` is not. Repeat with `PATCH`, `OPTIONS`, custom verbs.
5. **Parameter pollution / mass assignment.** Add `role=admin`, `is_admin=true`, `tenantId=...` to a profile-update body. Frameworks that bind whole JSON blobs to model fields leak privilege.
6. **Path-segment tricks.** `..`, URL-encoded slashes, trailing dot, double slash, and matrix params often slip past front-end ACLs that string-match prefixes. See [[path-traversal]] and [[canonicalization-attacks]].
7. **Referer / origin trust.** Endpoints that gate on `Referer: /admin/` — spoof the header.
8. **Force-browse hidden routes.** Wordlists against `/api`, `/v1`, `/internal`, `/debug`. Read source maps and JS bundles for route tables.
9. **Workflow steps out of order.** Skip the approval step by calling the final endpoint directly (see [[application-logic-flaws]]).

## Detection and defence
- Centralise authorisation in middleware that runs for every route by default; deny unless the route explicitly opts in.
- Enforce object-level checks server-side using the authenticated subject, never an id supplied by the client.
- Use opaque, unguessable ids (UUIDv4) — defence in depth, not a primary control.
- Test: integration tests that loop every endpoint with every role and assert 403 where expected.
- Detection: 403 spikes on internal routes from authenticated low-priv users; cross-tenant id ratios in access logs.

## References
- [OWASP Top 10 — A01 Broken Access Control](https://owasp.org/Top10/A01_2021-Broken_Access_Control/) — taxonomy.
- [PortSwigger — Access control vulnerabilities](https://portswigger.net/web-security/access-control) — labs and patterns.
- [OWASP WSTG — Authorization Testing](https://owasp.org/www-project-web-security-testing-guide/stable/4-Web_Application_Security_Testing/05-Authorization_Testing/) — methodology.
