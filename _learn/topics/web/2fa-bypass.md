---
title: 2FA bypass
slug: 2fa-bypass
---

> **TL;DR:** Skip, replay, brute, downgrade, or swap the second-factor check so a known password becomes a full takeover.

## What it is
Two-factor authentication adds a possession or biometric check on top of the password. A bypass keeps the password as the only real gate by attacking the verification step, the state machine that records that 2FA passed, or the fallback channels that exist for users who lose their device.

## Preconditions / where it applies
- Valid primary credentials (password from leak, [[credential-stuffing]], or [[application-logic-flaws]]).
- A login flow that splits primary auth and 2FA into separate requests, or one that exposes a "trust this device" or recovery path.
- TOTP, SMS, email-OTP, push, or backup-code-based factors.

## Technique
1. **Step skip.** After password POST you get a session cookie that already represents the user. Browse directly to `/account` or `/api/me`; the 2FA step was front-end only.
2. **Forced browsing of the post-2FA endpoint.** The POST that "enables" the session (e.g. `/auth/2fa/verify`) is reachable with a bogus body; the back-end only checks that you have a pre-2FA session.
3. **Response tampering.** Intercept the verify response — flip `success:false` to `success:true` or change a status code; the client trusts it and stores the final cookie.
4. **Brute on the OTP.** No throttling on `/verify`, or per-account throttling but no per-OTP throttling. Burp Intruder with the cluster-bomb of 000000-999999 against a 6-digit TOTP yields hits inside the 30-second window.

   ```http
   POST /auth/2fa/verify HTTP/1.1
   Cookie: pre2fa=...
   {"code":"§000000§"}
   ```

5. **OTP reuse / replay.** The same code is accepted twice, or the code from one user works for another because the server only checks "is this code currently valid for any user".
6. **Fallback abuse.** "Use recovery code" or "send to backup email" routes to an attacker-controlled or weaker channel. SMS swap, email account takeover, or knowledge-question reset.
7. **Remember-me + missing re-bind.** "Trust this browser" sets a cookie that survives password change and silently skips 2FA. See [[remember-me-flaws]].
8. **OAuth / SSO sidestep.** The app honours 2FA on its native login but a federated `/oauth/callback` path skips it.
9. **Race.** Concurrent requests during enrolment — see [[race-conditions]] — accept the password-only session before 2FA is enforced.

## Detection and defence
- Bind the post-2FA session to a fresh identifier; never let the pre-2FA cookie also serve authenticated requests.
- Throttle verify by IP, account, and code attempt; lock after 5 wrong attempts and alert.
- Invalidate OTPs on first use and on password change. Bind to user id server-side.
- Audit every login path (mobile, OAuth, recovery) for parity. Tests should hit each entry point with a 2FA-required account.
- Detection: spikes in `/2fa/verify` 401s from one IP, multiple sessions reaching `success` without a verify event, "trust device" cookies older than max-age.

## References
- [PortSwigger — 2FA bypasses](https://portswigger.net/web-security/authentication/multi-factor) — labs for skip, brute, reuse.
- [HackTricks — 2FA bypass](https://book.hacktricks.wiki/en/pentesting-web/2fa-bypass.html) — checklist of variants.
- [OWASP WSTG — Testing Multiple Factors Authentication](https://owasp.org/www-project-web-security-testing-guide/stable/4-Web_Application_Security_Testing/04-Authentication_Testing/11-Testing_Multiple_Factors_Authentication) — methodology.
