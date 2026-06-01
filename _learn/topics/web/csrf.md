---
title: Cross-site request forgery
slug: csrf
---

> **TL;DR:** Attacker-controlled site causes the victim's browser to issue an authenticated state-changing request.

## What it is
The browser attaches ambient credentials (cookies, HTTP Basic, NTLM, client certs) to any request to a target origin, regardless of which site initiated it. A state-changing endpoint that authenticates via cookies and has no anti-CSRF check can be invoked by any other site the victim happens to load.

## Preconditions / where it applies
- Target action authenticated by ambient creds (session cookie without `SameSite=Strict/Lax`-restrictive value, Basic auth, mTLS)
- Endpoint changes state with a request shape forgeable cross-origin (GET, simple POST `application/x-www-form-urlencoded`/`multipart/form-data`/`text/plain`)
- No anti-CSRF token, no Origin/Referer check, no re-auth/captcha

## Technique
1. Identify a state-changing endpoint and its required parameters from an authenticated session.
2. Forge a cross-origin trigger. For form-encoded POST:
   ```html
   <form action="https://target.tld/account/email" method="POST">
     <input name="email" value="attacker@evil.tld">
   </form>
   <script>document.forms[0].submit()</script>
   ```
3. JSON endpoints — usually safe due to preflight, but bypass if server accepts `text/plain`:
   ```html
   <form action="https://target.tld/api/transfer" method="POST" enctype="text/plain">
     <input name='{"to":"attacker","amount":1000,"x":"' value='y"}'>
   </form>
   ```
4. **Token-extraction CSRF** — if the CSRF token is per-session but not bound to user, attacker fetches their own token and reuses it. If token is in a cookie and reflected into header (double-submit), but cookie is settable via subdomain XSS, defeat it that way.
5. **Method override** — Rails / Symfony accept `_method=DELETE` in POST body. Servers honouring `X-HTTP-Method-Override` let GET become POST.
6. **CSRF + `SameSite=Lax`** — top-level GET still attaches the cookie. If a state-changing GET exists, or a top-level form-POST navigation triggers within ~2 min of cookie set, Lax does not save you (Chrome's 2-min Lax-by-default window).
7. **Login CSRF** — log victim into attacker's account, victim's later activity (saved cards, search history) leaks to attacker.
8. **CSWSH** — WebSocket handshake is a regular HTTP request with cookies but no preflight; if the server only checks cookie auth, attacker page opens a WS to target and reads bidirectional. See [[websocket-attacks]].

## Detection and defence
- Set session cookies `SameSite=Lax` minimum, `Strict` where UX allows; `Secure; HttpOnly`.
- Synchronizer token: per-session random, sent in header or hidden field, validated server-side; rotate on auth change.
- Double-submit cookie + custom request header (browsers block custom headers cross-origin without CORS preflight).
- Validate `Origin` and `Referer` for state-changing requests.
- Require re-auth / WebAuthn step-up for critical actions ([[webauthn-api-hijacking-downgrade]]).
- Related: [[onsite-request-forgery]], [[cors-misconfig]], [[clickjacking]], [[websocket-attacks]].

## References
- [PortSwigger — CSRF](https://portswigger.net/web-security/csrf) — labs and lab solutions
- [OWASP — CSRF prevention cheat sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html) — defence patterns
- [Chrome — SameSite-Lax-by-default](https://web.dev/articles/samesite-cookies-explained) — modern cookie defaults
