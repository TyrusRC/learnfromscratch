---
title: Session fixation
slug: session-fixation
---

> **TL;DR:** Attacker plants a known session ID before login; victim authenticates into it.

## What it is
A session-fixation flaw exists when the application keeps the same session identifier across the pre-authentication and post-authentication states. Attacker obtains a fresh session ID (just by visiting the site), tricks the victim into using that ID — via cookie injection on a sibling subdomain, URL parameter, or [[crlf-injection]] in a response header — and waits for the victim to log in. After authentication the attacker's pre-set ID is now associated with the victim's identity.

## Preconditions / where it applies
- App accepts a session ID supplied by the client and elevates that ID on login
- Channel to plant the cookie: open redirect with `Set-Cookie` header, XSS on a sibling subdomain that scopes `Domain=.target`, MITM on an HTTP page, URL-rewritten session IDs (`;jsessionid=…`)
- Login does not rotate the identifier

## Technique
1. Hit the login page anonymously, grab `SESSIONID=abc`.
2. Force the victim to use `abc`. Options:
   - Link with URL session param: `https://target.com/login;jsessionid=abc`
   - Subdomain XSS sets `document.cookie='SESSIONID=abc; Domain=.target.com; Path=/'`
   - Network attacker on plaintext HTTP injects `Set-Cookie: SESSIONID=abc` in any non-HTTPS response from the same registrable domain (cookie scope crosses HTTPS/HTTP)
   - CRLF in a redirect target on the app itself
3. Victim authenticates → server now associates `abc` with the victim's user.
4. Attacker hits any authenticated endpoint with `Cookie: SESSIONID=abc`.

Servlet containers historically defaulted to URL rewriting (`;jsessionid=`) which made this trivial — many also accepted the ID via query string.

Variants:

- **Pre-login cookie carried into login.** Frameworks that don't rotate on `request.session.regenerate()` — Django pre-1.x default behaviour, classic PHP without `session_regenerate_id(true)`.
- **CSRF-token fixation.** If the CSRF cookie is anchored before login and not rotated, an attacker plants their CSRF token and prepares pre-signed CSRF requests for the victim's authenticated session.

Closely related: [[session-token-analysis]] (predictable IDs), [[remember-me-flaws]], [[csrf]].

## Detection and defence
- Invalidate and reissue the session identifier on every privilege change — login, logout, role escalation, MFA completion
- Refuse client-supplied session IDs that don't already exist server-side
- Disable URL-based session IDs (`tomcat sessionTrackingModes="COOKIE"`)
- Set cookies `Secure; HttpOnly; SameSite=Lax`; scope `Domain` as tightly as possible
- Use `__Host-` cookie prefix to prevent subdomain overwrites
- HSTS to remove the HTTP cookie-injection channel

## References
- [OWASP — Session fixation](https://owasp.org/www-community/attacks/Session_fixation) — definition + variants
- [OWASP Cheat Sheet — Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) — required rotation rules
- [PortSwigger — Session management vulnerabilities](https://portswigger.net/kb/issues/00400500_session-fixation) — issue notes
