---
title: Remember-me cookie flaws
slug: remember-me-flaws
---

> **TL;DR:** Persistent-login cookie holds attacker-targetable identity — predictable, replayable across logout, leaked in logs.

## What it is
"Remember me" lets a user skip the next login by storing a long-lived credential — usually a separate cookie distinct from the short session cookie. Implementations vary: some store an opaque random token mapped server-side; many store identity directly (username, base64 password, signed claim). Bad designs are predictable, replayable, untied to the session, or leak in places normal session cookies don't (long-term storage, sync clients, log aggregators).

## Preconditions / where it applies
- App offers persistent login with checkbox
- Cookie set with long `Max-Age` (weeks / months) and frequently without `HttpOnly` or `Secure`
- Server validates the cookie without checking session validity, IP, or device fingerprint

## Technique
Inspect the cookie format first. Common bad patterns:

```
RememberMe = base64(username:md5(password))      # Spring Security default pre-3.0
auth      = base64({"u":"alice","r":"admin"})    # signed? often not
persist   = <hex>                                 # predictable counter / time
```

Tests:

1. **Decode.** Base64 + JSON / colon-split. If identity is plain inside, you can forge for any known user.
2. **Predictability.** Capture several across accounts/times. PRNG outputs, monotonic counters, predictable timestamps fail Burp Sequencer entropy check.
3. **Replay after logout.** Log in, capture cookie, log out — does the cookie still authenticate? Single-cookie designs often invalidate only the session cookie, not the remember-me token.
4. **Password change non-invalidation.** Change password; old remember-me should die. Many don't.
5. **Concurrent device limit.** Issue multiple remember-me cookies for the same user — server should track them per-device.
6. **Identifier collision / forgery.** If the cookie is a signed JWT, see [[jwt]] for algorithm-confusion and key-confusion attacks.
7. **Leakage.** Check whether it goes to subdomains via `Domain=.target.com` — XSS on any subdomain lifts it. Check `HttpOnly`, `Secure`, `SameSite`. Check whether request logs include the cookie header.

Better-known broken cases include Spring Security's first-gen `TokenBasedRememberMeServices` (username + expiry + signature with shared key — secret leak = forge for anyone) and CMS plugins that store base64(login:pass).

Related: [[session-fixation]], [[session-token-analysis]], [[2fa-bypass]] (some apps skip 2FA on remember-me).

## Detection and defence
- Opaque random ≥128 bits, server-side lookup, single-use rotation on each use (Barry Jaspan's series-token design)
- Invalidate all tokens on password change, role change, and explicit logout
- Bind token to device fingerprint and short-lived session — never act on remember-me alone for sensitive actions; re-prompt for password
- `HttpOnly; Secure; SameSite=Lax`; do not log raw cookie values
- Still require 2FA on first session resume from a new device

## References
- [Barry Jaspan — Improved persistent login cookie best practice](https://www.jaspan.com/improved_persistent_login_cookie_best_practice) — series tokens
- [OWASP Cheat Sheet — Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) — persistent token guidance
- [PortSwigger — Authentication vulnerabilities](https://portswigger.net/web-security/authentication) — labs touching remember-me
