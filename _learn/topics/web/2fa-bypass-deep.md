---
title: 2FA bypass — deep dive
slug: 2fa-bypass-deep
aliases: [2fa-bypass-deep, mfa-bypass-deep]
---

{% raw %}

> **TL;DR:** 2FA bypass classes from real bug-bounty reports: (1) re-use of pre-2FA session token, (2) endpoint that completes login without checking 2FA, (3) response manipulation (status code, body field), (4) brute-force on OTP without rate limiting, (5) race condition between OTP generation and login, (6) backup-code abuse, (7) recovery-flow downgrade, (8) push-notification fatigue / MFA bombing, (9) SIM swapping (out-of-band). Companion to [[2fa-bypass]] and [[oauth-modern-attacks]].

## Class 1 — token re-use

Many apps issue a session token *before* 2FA challenge. Bugs:
- 2FA optional based on a header (`X-Skip-2FA: true`).
- Token gets full access without 2FA completion.
- API endpoints check token validity but not 2FA-completion flag.

Test:
1. Log in (password only).
2. Capture the pre-2FA session token.
3. Use it directly against `/api/account` or similar.
4. If response is 200 with user data — bypass.

## Class 2 — endpoint completion without 2FA

Some apps have multiple "login complete" paths:
- `/login/2fa-verify` (checks OTP, sets `mfa_completed=true`).
- `/login/sso/complete` (assumes SSO did the check).
- `/login/saml/acs` (SAML response trusted).

If any path sets the same authenticated session, attacker enumerates and uses one that skips OTP.

## Class 3 — response manipulation

Mobile apps and SPAs sometimes decide "did the OTP succeed" client-side.

Server response: `{"success": false, "remaining": 4}`. Burp intercept → change to `{"success": true}` → app proceeds. The next request includes the session that the server *did* establish on failure.

Audit:
- Server-side enforcement at every step.
- Session cookie not issued until 2FA actually passes.

## Class 4 — OTP brute force

A 6-digit TOTP has 1M possibilities. If no rate limit:
```bash
for i in $(seq 0 999999); do
  printf '%06d\n' $i | xargs -I{} curl -X POST https://app/2fa -d "otp={}" -b "sess=..."
done
```

Realistic apps lock after 5-10 failures. Bugs:
- Rate-limit per IP — attacker rotates IPs.
- Rate-limit per session — attacker generates new sessions.
- Rate-limit per user — but no rate-limit on the OTP-send endpoint → exhaust the small TOTP window with thousands of guesses.
- Rate-limit absent on the API tier (UI tier limits; API bypasses).

## Class 5 — race condition

```
Request 1: POST /login (password)        → server starts 2FA challenge
Request 2: POST /login/complete (no OTP) → server's check for "is 2FA complete" hasn't synced yet
```

Some apps store 2FA-required flag in cache with a race between login start and OTP check. Send both requests in parallel; sometimes the second wins before the first's flag is committed.

Burp Turbo Intruder is the tool of choice.

## Class 6 — backup-code abuse

Apps offer printable backup codes for 2FA recovery. Bugs:
- Backup codes don't expire.
- Backup codes shared across users (rare but seen).
- Backup-code generation endpoint reachable post-password-only (uses session that *was* 2FA-verified previously but the user changed their 2FA device).

## Class 7 — recovery flow downgrade

"Lost my phone" recovery often:
- Sends a link to email.
- Asks for a recovery key.
- Has a phone-call verification.

Bugs:
- Recovery skips 2FA on the new device (by design — but enables attacker who has password + email).
- Recovery email link doesn't include 2FA challenge.
- "Disable 2FA" requires only password (not current 2FA).

Test: trigger recovery; observe whether new session is 2FA-verified.

## Class 8 — MFA bombing / push notification fatigue

Attacker has the password; floods victim with push notifications. Victim eventually approves (by accident, frustration, or social-engineering call).

Defence: number-matching MFA (user must enter a code shown on the login screen).

Recent real-world breaches (Uber 2022, others) used this.

## Class 9 — SIM swap

Out-of-scope for application-layer bypass, but real attack: attacker convinces carrier to port victim's number; receives SMS OTPs.

Defence: don't use SMS OTP; use TOTP, push, or WebAuthn.

## Class 10 — WebAuthn / FIDO2 attacks

WebAuthn is the strongest 2FA but has misuse modes:
- Server accepts assertion for *any* registered credential, not just the user's → credential mixup.
- `userVerification: discouraged` requested when policy says "required".
- Origin not validated in assertion verification.
- `rpId` mismatch silently downgraded.

See [[webauthn-api-hijacking-downgrade]].

## Bug-bounty patterns (from public reports)

- Slack: 2FA bypass via SAML SSO path that skipped OTP — bounty paid.
- Twitter: TOTP brute-force due to missing rate limit on attempts endpoint.
- Multiple SaaS: pre-2FA session valid for full account access.
- M365: MFA bombing successful against admin accounts.

## Source audit

```bash
grep -rn '2fa\|two_factor\|mfa\|otp\|totp' src/ -i
grep -rn 'verify_otp\|check_2fa\|require_mfa' src/
grep -rn 'backup_code\|recovery_code' src/
```

For each login path, confirm the 2FA check runs at the gate, not after.

## Defence

- **One canonical login path** — all paths converge on the same "session-becomes-authenticated" function.
- **Rate-limit globally** per-user and per-IP and per-endpoint.
- **WebAuthn / FIDO2** as the default; SMS only as legacy.
- **Number-matching MFA** for push.
- **Backup codes single-use, expire on regeneration.**
- **Recovery flow requires 2FA on the new device.**

## References
- [PortSwigger — 2FA bypass labs](https://portswigger.net/web-security/authentication/multi-factor)
- [Microsoft — MFA bombing research](https://www.microsoft.com/en-us/security/blog/)
- [HackerOne reports on MFA bypass](https://hackerone.com/reports?filter%5Bweakness%5D=BYPASS_AUTHENTICATION)
- [PayloadsAllTheThings — 2FA bypass](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/2FA%20bypass)
- See also: [[2fa-bypass]], [[oauth-modern-attacks]], [[account-takeover-modern-chains]], [[webauthn-api-hijacking-downgrade]]

{% endraw %}
