---
title: Auth bypass from source review
slug: auth-bypass-from-source-review
aliases: [whitebox-auth-bypass, source-review-authz]
---

{% raw %}

> **TL;DR:** Most auth bypasses readable from source come from one of seven shapes: type juggling, signature/MAC weakness, missing middleware on a specific route, role enum gap, password-reset token reuse, OAuth state/PKCE absence, and parser differential. Audit each route for which shape it's most susceptible to.

## The seven shapes

### 1. Type juggling / loose comparison
- PHP `==`, Ruby `==` on mixed types, JS `==` with implicit coerce.
- Sinks: token comparison, password compare, ID comparison.
- Look for: `if ($token == $expected)` — `0e123` style hash collisions, `0 == "abc"` on old PHP.
- Fix: strict equality + constant-time compare.

### 2. Signature/MAC weakness
- JWT `none` allowed (no `algorithms` whitelist on verify).
- JWT key confusion: HS256 signed with RSA public key.
- ViewState without MAC.
- Cookie signed with weak/leaked `secret_key_base` / `APP_KEY` / `machineKey`.
- Look for: `jwt.verify(t, key)` without 3rd arg; `secret` checked into git.
- Fix: explicit algorithm list, key rotation, secret manager.

### 3. Missing middleware on a specific route
- Framework-level auth attached per-route or per-class. One route missed = full bypass.
- Look for: route table, count routes vs auth annotations.
- Spring: count `@PreAuthorize` vs `@RequestMapping` per controller class.
- NestJS: count `@UseGuards` vs `@Get/@Post`.
- Rails: every controller should inherit `ApplicationController` with `before_action :authenticate_user!`.
- Express: middleware order in `app.use` + route registration order.
- Fix: default-deny at framework level; routes opt-out, not opt-in.

### 4. Role enum gap
- Role check uses ordinal/integer, gap allows attacker role to slip into a privileged range.
- `if (user.role > Role.USER) { adminOnly() }` — but `Role.GUEST = 0, USER = 1, MOD = 2, ADMIN = 3`. Attacker registers with role 2.
- Look for: role storage in DB without enum constraint; registration form that accepts `role` field.
- Fix: explicit equality checks; role can only be set by privileged code path.

### 5. Password-reset token reuse / weak token
- Token not invalidated after use.
- Token derived from time + user id (predictable).
- Token issued without rate limit (brute-forceable).
- Reset link emailed to attacker-controlled address via host-header injection ([[host-header-injection]]).
- Look for: `password_reset_tokens` table schema; the `consume`/`invalidate` step after `verify`.
- Fix: single-use, expire on use, 128-bit random, bind to user's current password hash.

### 6. OAuth state/PKCE absence
- `state` parameter not generated, not stored in session, not validated on callback → CSRF on auth flow → account takeover.
- PKCE absent for public clients (mobile, SPA) → authorization code injection ([[oauth-authorization-code-injection]]).
- `redirect_uri` not strictly validated (substring match, regex) → token leak.
- Look for: `state` generation point, session-side storage, callback verify.
- See [[pkce-downgrade-and-bypass]].

### 7. Parser differential
- Two parsers see the same input differently — XML SAML signed by one parser, role read by another ([[parser-differential-saml-ruby]]).
- HTTP request smuggling between frontend and backend ([[http-request-smuggling]]).
- JSON: comments allowed by one parser, not another, with trailing `}` confusion.
- Look for: any boundary where data is parsed twice (e.g., signature verifier vs business-logic deserializer).
- Fix: re-canonicalise input before each use; single source of truth for parsed form.

## Audit workflow
1. **Route ↔ auth map.** Make a table: each route, what middleware/guard/annotation enforces auth, what enforces authorization (resource ownership), what enforces role.
2. **Look for asymmetry.** A route with auth but no resource check is IDOR; a route with role check but no resource check is BFLA ([[bfla]]).
3. **Diff the seven shapes.** For each route, ask "could shape N apply here?" — not all shapes apply everywhere, but the ones that do are quick reads.
4. **Trace the session.** Where is the session created? Where is it validated? Where is it invalidated? Mismatches between these three are auth bugs.
5. **Test the bypass on the live instance.** A source-only finding is a hypothesis; confirmed by curl is a bug.

## Common false-positive traps
- Reverse-proxy / load-balancer level auth not visible in source (nginx auth_request, oauth2-proxy sidecar). Find deployment config; otherwise you'll report bypasses that are blocked at L7.
- Service mesh mTLS — internal endpoints assume mTLS not visible in app code.
- Feature flag gates — code path appears reachable but flag is off.

## References
- [PortSwigger — Authentication](https://portswigger.net/web-security/authentication)
- [OWASP ASVS — V2 (Authentication) and V4 (Access Control)](https://owasp.org/www-project-application-security-verification-standard/)
- [OAuth 2.0 Security Best Current Practice (RFC 9700)](https://datatracker.ietf.org/doc/html/rfc9700)
- See also: [[whitebox-to-exploit-methodology]], [[broken-access-control]], [[jwt]], [[oauth-flows]]

{% endraw %}
