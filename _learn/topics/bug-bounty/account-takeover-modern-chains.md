---
title: Account takeover — modern chains
slug: account-takeover-modern-chains
aliases: [ato-chains, account-takeover-modern]
---

{% raw %}

> **TL;DR:** Modern ATO bugs from public bug-bounty disclosures cluster around: (1) password-reset token bugs (predictable, leaked via host-header / referer, reused), (2) OAuth confusion across SSO providers, (3) email-change without verification on the new email, (4) phone-number-recycling abuse, (5) JWT signing-key tricks, (6) session-fixation in SaaS multi-tenant, (7) account merging on email-collision, (8) MFA-recovery bypass, (9) impersonation via API tokens. Companion to [[2fa-bypass-deep]] and [[oauth-modern-attacks]].

## Class 1 — password reset token bugs

The classic, still pays.

- **Predictable token**: `md5(email + timestamp)` or sequential integers. Generate the victim's token offline.
- **Token via host-header injection**: server uses `Host` header to build reset link; attacker sends a request with `Host: attacker.tld`; user clicks the link in their inbox; the token POSTs to attacker.
- **Token leaked via referer**: reset page loads an analytics/ad script; clicking it leaks the URL (which contains the token) in the Referer.
- **Reset token doesn't expire**: token from a year ago still works.
- **Token bound to email but not to user**: changing email field in the POST body with the same token resets a different account.
- **Reset confirms via GET**: attacker can prefetch/scan the link.

Test:
1. Submit "forgot password" for victim's email.
2. Inspect the reset link delivered (if you control an inbox).
3. Try the link with different parameters changed.

## Class 2 — OAuth + SSO confusion

Modern SaaS has multiple sign-in paths: native, Google, Microsoft, SAML SSO, magic link. Bugs:

- **Email-based identity merging**: attacker registers `victim@gmail.com` natively, then victim signs in via Google → backend merges accounts → attacker's password works on victim's account.
- **No email verification on Google SSO**: Google returns `email_verified: false` in some flows (Workspace policy); backend trusts it anyway.
- **SSO bypass via SAML XML signing**: see [[saml-xsw-attacks]].
- **OIDC `email` claim from untrusted IdP**: backend accepts emails from any registered IdP, even one the attacker controls.

See [[oauth-modern-attacks]].

## Class 3 — email-change abuse

Email is the recovery channel. Bugs:

- **Email-change without verifying the new email**: attacker changes victim's email to their own; subsequent password reset goes to attacker.
- **Email-change without re-authentication**: attacker with stolen session changes email; even if session is revoked later, account is theirs.
- **Email-change confirmation token reusable**: a confirmation link that's reused across users.
- **Race condition**: change email twice quickly; the second change verifies before the first invalidates session.

## Class 4 — phone-number recycling

Cellular numbers get recycled. Attacker buys victim's old number → SMS OTP delivered to attacker.

Defence:
- Don't rely on SMS for high-value accounts.
- Periodically re-verify phone ownership.
- Block changes near recycling-flag indicators (carrier APIs expose this).

## Class 5 — JWT signing-key tricks

JWT bugs that produce ATO:
- **`alg: none`**: signature verification skipped; attacker crafts a JWT with any user ID.
- **`alg: HS256`** when server expected RS256: HMAC verification uses the RS256 public key as the HMAC key; attacker computes HMAC with the public key.
- **`kid` injection**: `kid` field points to a SQL row / file path; attacker manipulates.
- **`jku`/`jwk` injection**: attacker URL hosts the key the JWT claims to use.

See [[jwt]], [[jwt-key-confusion]], [[jwt-jku-jwk-injection]].

## Class 6 — session fixation in SaaS

Multi-tenant SaaS often:
- Assigns a session token *before* login.
- Persists it across the login event.

If attacker can set a victim's session token (via subdomain cookie injection, XSS in a sibling app), the post-login session is the same token → attacker logged in as victim.

Defence: regenerate session ID on auth state change (RFC standard since 1999, still missed).

## Class 7 — account merging on collision

When a service supports multiple identity sources, "merge by email" is common. Bugs:
- Attacker registers `victim@gmail.com` natively (Google's `+` aliasing).
- Victim signs in with Google `victim+gmail.com`.
- Backend normalizes both to `victim@gmail.com` → merges.
- Attacker's credentials now reach victim's data.

Variants: dots in email (`v.ictim@gmail.com`), Unicode homoglyphs, case-sensitivity differences.

## Class 8 — API token impersonation

SaaS API tokens often have `impersonate_user_id` parameters for admin tooling. Bugs:
- API token issued to a normal user accepts the `impersonate` field.
- Internal API endpoint exposed externally honours `X-User-Id` header.
- "Switch organisation" endpoint accepts arbitrary org IDs.

## Class 9 — MFA recovery bypass

See [[2fa-bypass-deep]] § Class 7.

## Class 10 — IDOR on profile endpoints

```
PATCH /api/users/me { "email": "attacker@evil" }
```

vs.

```
PATCH /api/users/12345 { "email": "attacker@evil" }   # 12345 is victim's ID
```

If the API trusts the user ID in the URL without checking it matches the session: full ATO. Surprisingly common in older SaaS.

## Class 11 — third-party integration ATO

App connects to user's GitHub / Slack / Linear. Bugs:
- OAuth callback returns to a URL with code; attacker registers a similar workspace and tricks user into authorising.
- Webhook endpoint accepts events without verifying the signature.

## Reporting

For an ATO bug:
- Repro: stepwise; from "no access" to "account taken over".
- Impact: scope of access on the compromised account.
- Suggested fix: specific server-side change.

Bug-bounty payouts for ATO range from $500 (low-value SaaS) to $50,000+ (FAANG critical).

## Tools

- **Burp Suite** + Repeater / Intruder.
- **AuthMatrix** Burp extension — multi-user testing.
- **mitmproxy** — mobile app testing.
- Manual: register two accounts, attempt to use one to affect the other.

## Source audit

```bash
grep -rn 'password_reset\|forgot_password\|reset_token' src/
grep -rn 'email_change\|update_email\|set_email' src/
grep -rn 'merge_user\|merge_accounts' src/
grep -rn 'impersonate\|switch_user' src/
```

## References
- [HackerOne — disclosed ATO reports](https://hackerone.com/reports?filter%5Bweakness%5D=ATO)
- [PortSwigger — auth and ATO labs](https://portswigger.net/web-security/authentication)
- [Synack — research blog](https://www.synack.com/blog/)
- [Bugcrowd — VRT](https://bugcrowd.com/vulnerability-rating-taxonomy)
- See also: [[2fa-bypass-deep]], [[oauth-modern-attacks]], [[idor]], [[broken-access-control]], [[application-logic-flaws]]

{% endraw %}
