---
title: Account-recovery / forgotten-password flaws
slug: account-recovery-attacks
---

> **TL;DR:** Recovery flow re-uses weak channel, predictable token, host-header injected reset link, OTP brute, race-on-reset.

## What it is
Password-reset and account-recovery flows are an authentication side-door. They typically issue a one-time credential (token, OTP, magic-link) and trust it for high-privilege actions: reset password, change email, disable MFA. Anything weak in token generation, delivery, scoping, or validation can be turned into a full account takeover without ever knowing the original password.

## Preconditions / where it applies
- Public reset endpoint that accepts email/username and triggers a token
- Reset URL or OTP issued without rate-limit, with predictable entropy, or scoped to a recipient the attacker controls
- Secondary channels treated as equivalent (SMS, recovery email) but registered separately
- Apps that read `Host:` / `X-Forwarded-Host` to build absolute reset URLs

## Technique
1. **Host-header injection** — submit reset with a spoofed `Host:` so the link in the mail points at attacker.tld; victim clicks, token leaks to attacker.
   ```http
   POST /password/reset HTTP/1.1
   Host: attacker.tld
   X-Forwarded-Host: attacker.tld
   email=victim@corp.com
   ```
2. **Weak / guessable token** — tokens that are 4-6 digit numeric, monotonic, timestamp-seeded, or tied to user id (`md5(uid)`). Enumerate or brute the token endpoint.
3. **OTP brute** — 4-6 digit OTP with no lockout. Use parallel requests (race) or burp turbo intruder; sometimes the same OTP is valid against multiple endpoints (login, reset, MFA).
4. **Response-confusion** — the reset endpoint leaks `userId`/`email`/`tokenHash` in the response body or sets it on the redirect URL.
5. **Token re-use** — token issued for `victim@x.com` accepted when the JSON body switches the email to attacker's. Or token works on /reset and on /change-email.
6. **Race on reset** — submit two parallel reset finalizes with different new passwords; some apps process both, leaving the attacker's value last.
7. **Secondary-factor downgrade** — "lost your authenticator" flow that only requires recovery email; chain with email takeover or [[2fa-bypass]].
8. **Account-merge / lookup oracle** — different errors for "email exists" vs "no account" leak user enumeration that feeds the rest of the chain.

## Detection and defence
- Bind reset URL to a server-side configured canonical host; never trust `Host:`/`X-Forwarded-*` for URL building.
- Tokens: ≥128 bits CSPRNG, single use, short TTL (≤15 min), bound to user id server-side.
- Rate-limit OTP attempts per token and per account; lock after 5 fails; invalidate on success.
- Log "reset triggered" + "reset completed" with IP/UA; alert on new IP completing reset for high-value accounts.
- Require step-up (re-auth or MFA challenge) for changing email or disabling MFA — never let recovery alone unlock both.
- Related: [[2fa-bypass]], [[session-token-analysis]], [[remember-me-flaws]].

## References
- [PortSwigger — password reset poisoning](https://portswigger.net/web-security/host-header/exploiting/password-reset-poisoning) — host-header reset URL hijack
- [OWASP WSTG — forgot-password testing](https://owasp.org/www-project-web-security-testing-guide/stable/4-Web_Application_Security_Testing/04-Authentication_Testing/09-Testing_for_Weak_Password_Change_or_Reset_Functionalities) — review checklist
- [HackTricks — reset password](https://book.hacktricks.wiki/en/pentesting-web/reset-password.html) — case studies and tricks
