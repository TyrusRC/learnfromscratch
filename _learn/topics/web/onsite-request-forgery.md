---
title: On-site Request Forgery (OSRF)
slug: onsite-request-forgery
---

> **TL;DR:** Stored HTML triggers same-origin requests on every viewer's behalf — like CSRF but already past the origin check.

## What it is
A stored HTML/image-tag injection (often in a profile, comment, message, or admin-visible field) causes any user who renders the page to issue requests to the same origin while authenticated. Because the request is **same-origin**, `SameSite`, `Origin` checks, and most anti-CSRF tokens cookied to the session do not block it. It is CSRF that bypasses CSRF defences by living on the target itself.

## Preconditions / where it applies
- Stored sink that emits HTML — `<img>`, `<script>` not required; `<img src>` / `<iframe>` / form auto-submit is enough
- State-changing GET endpoints, or endpoints where the CSRF token can be fetched from another same-origin URL
- Authenticated viewers (often privileged users — support, admin, moderator)

## Technique
1. Find a stored sink that allows at minimum an `<img src>`-like tag (image BBCode, markdown image, profile avatar URL field, signature, support-ticket body).
2. **GET state change** — point it at the target endpoint:
   ```html
   <img src="/admin/users/42/promote">
   ```
   Any admin who views your ticket promotes user 42.
3. **POST via auto-submit form** — if `<script>` is allowed (incomplete sanitiser), or via injected `<iframe srcdoc>` with a form + onload submit.
4. **CSRF-token bypass** — fetch the token from `/profile` same-origin via injected `<img onerror>` or JS, then post with it. The double-submit cookie pattern fails because the cookie is set and readable in the same origin.
5. **Privilege escalation through admin views** — moderators visiting reported content trigger the action; classic Stored-XSS-style victims are higher-privileged than the attacker.
6. **Pivot via email rendering** — stored content emailed to other users; many email clients fetch remote images by default, executing the SSRF/OSRF against the webmail origin.
7. **Combine with [[ssrf]]** — OSRF to an internal endpoint accessible only via the app server.

## Detection and defence
- Treat all state-changing endpoints as **POST + token + same-site cookie + Origin check**; reject GET state changes outright.
- Sanitise stored HTML — strip `<img>`/`<iframe>`/`<form>` to allowlisted attributes; rewrite `src` to a CDN proxy that only fetches whitelisted hosts.
- For admin/support panels, render user content sandboxed (`<iframe sandbox srcdoc>` with empty allowlist) — no requests fire on render.
- Log requests where Referer matches a known stored-content view and target is sensitive; alert.
- Related: [[csrf]], [[cross-site-scripting]], [[clickjacking]], [[ssrf]].

## References
- [PortSwigger — exploiting XSS to perform CSRF](https://portswigger.net/web-security/cross-site-scripting/exploiting) — same primitive, stored vector
- [HackTricks — XSS](https://book.hacktricks.wiki/en/pentesting-web/xss-cross-site-scripting/index.html) — sinks usable for OSRF
- [OWASP — CSRF cheat sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html) — why same-site defences fail here
