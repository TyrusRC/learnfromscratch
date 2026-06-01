---
title: CAPTCHA bypass
slug: captcha-bypass
---

> **TL;DR:** Skip, replay, or solve the challenge cheaply so rate-limit and bot controls collapse and you can brute, scrape, or stuff credentials.

## What it is
A CAPTCHA gates an action behind proof of humanity. Bypasses target the verification, not the puzzle: the server might never validate the token, accept a stale token, or be reachable via a path that does not gate at all. Where validation is correct, solver economics often defeat the control anyway.

## Preconditions / where it applies
- Login, registration, password-reset, comment, or contact-form endpoints with a CAPTCHA gate.
- reCAPTCHA v2/v3, hCaptcha, Turnstile, image OCR, audio, or custom puzzle.
- An attacker goal that needs many requests (credential stuffing, enumeration, spam).

## Technique
1. **Remove the token client-side.** Strip `g-recaptcha-response` from the POST body. Many back-ends fail-open when the field is missing.
2. **Token replay.** Solve once, then reuse the same token across many requests. Server must check `success` and that the token has not been seen before — many don't.
3. **Cross-action / cross-site token.** A reCAPTCHA v3 token from the public homepage often works on the login endpoint because the action name or site key is not bound.
4. **Skip the gated path.** UI-only gate: the JS adds the captcha to `/login` but `/api/login` accepts the same credentials with no CAPTCHA. Browse the API tier directly.
5. **Bypass via mobile/legacy endpoint.** `/mobile/login`, `/v1/auth`, or partner API routes often skip the control entirely.
6. **Response tampering.** Some apps validate server-side then return a JSON flag (`captcha_passed:true`) that the front-end forwards on the next call; flip it.
7. **Audio channel weakness.** Older image CAPTCHAs ship an audio alternative for accessibility; pipe it through a free speech-to-text API.
8. **Solver economics.** 2Captcha / Anti-Captcha and similar farms solve reCAPTCHA v2 in seconds for fractions of a cent. For credential stuffing this is part of the standard pipeline.
9. **Headless reCAPTCHA v3 score gaming.** Warm a browser fingerprint by visiting the site through residential proxies before scripting the target action.

   ```python
   # outline only — token reuse check
   token = solve_captcha(site_key, page_url)
   for cred in creds:
       r = requests.post(login, data={**cred, "g-recaptcha-response": token})
   ```

## Detection and defence
- Validate the token server-side on every gated endpoint; reject missing or empty fields. Bind to action name (v3) and remote IP.
- One-shot tokens: store seen tokens for their TTL, deny replays.
- Mirror gating across every entry point (web, mobile, partner API). Single chokepoint at the auth service is best.
- Add behavioural and velocity controls (per-IP, per-account, per-ASN) — CAPTCHA alone is not rate limiting.
- Detection: high success rate of token validation from a single IP/ASN, repeated identical tokens, login attempts where the CAPTCHA field is absent.

## References
- [Google — reCAPTCHA verify response](https://developers.google.com/recaptcha/docs/verify) — required server-side validation.
- [PortSwigger — Bypassing rate-limit defences](https://portswigger.net/web-security/authentication/password-based) — overlap with CAPTCHA evasion.
- [HackTricks — CAPTCHA bypass](https://book.hacktricks.wiki/en/pentesting-web/captcha-bypass.html) — checklist.
