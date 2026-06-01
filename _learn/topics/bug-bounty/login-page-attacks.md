---
title: Login-page attacks
slug: login-page-attacks
---

> **TL;DR:** Login forms expose default creds, common-password susceptibility, user-enumeration via differential responses, timing oracles, and lockout-vs-IP-rotation tradeoffs. Test all five before assuming the login is solid.

## What it is
The login endpoint is the entry door to the rest of the application; weaknesses here unlock everything else. Beyond brute-force, modern login bugs include username enumeration (knowing which accounts exist enables targeted phishing), error-timing oracles, and bypass via auxiliary endpoints (forgot-password, OAuth callbacks, mobile-app login routes).

## Preconditions / where it applies
- A public login endpoint within scope (web, API, mobile backend)
- Program rules allow credential testing — many programs prohibit brute force at any rate; read carefully
- You have a baseline of "known invalid" and "known valid" responses (often via your own test account)

## Technique
1. Default and weak credentials. Vendor appliances, admin panels, and dev environments often retain stock creds:

```
admin:admin, root:root, admin:password, test:test
```

Don't dictionary-attack production users; do test a curated list of vendor defaults on admin / staging login surfaces.
2. User-enumeration via response differential. Send `valid_user:wrong_pw` and `invalid_user:wrong_pw` and compare:
   - Status code
   - Body length
   - Error message text ("user not found" vs "incorrect password")
   - Set-Cookie behaviour
   - Response time (if check-user-then-check-pw, valid users take longer)
3. Adjacent enumeration surfaces — even when login itself is hardened:
   - Forgot-password: "if this email exists we'll send you a link" vs "user not found"
   - Registration: "username already taken" is enumeration
   - OAuth: error messages distinguishing linked vs unlinked accounts
4. Brute-force gating analysis. Test:
   - Lockout per username, per IP, per both?
   - Does the lockout reset on a successful login?
   - Does a different `X-Forwarded-For` header bypass IP-based gating?
   - Does the API endpoint (`/api/login`) lack the rate limit that the HTML form has?
5. Mass credential testing only when program allows. Spray with one password across many usernames (credential stuffing pattern) is often more effective than vertical brute-force.

```
# Burp Intruder / ffuf example for credential pair testing
ffuf -w pairs.txt:USER:PASS -X POST -d 'u=USER&p=PASS' \
     -u https://target.tld/login -fr 'invalid'
```

6. Auxiliary bypasses. Old mobile API versions, partner SSO endpoints, embedded admin routes — each may skip controls the main login enforces ([[expanding-attack-surface]]).

## Detection and defence
- Generic error messages — never distinguish "user exists" from "wrong password" in any response or timing
- Rate-limit per username AND per source IP; constant-time bcrypt verification dampens timing oracles
- Enforce MFA universally; brute-force vs MFA-enabled accounts is wasted effort
- WAF: alert on >N login attempts/minute from a single IP, but also on >N distinct usernames across a /24 (credential stuffing pattern)
- Block login attempts with known-breached passwords (`Have I Been Pwned` API) at the registration / change-password gate

## References
- [PortSwigger — Authentication](https://portswigger.net/web-security/authentication) — login flaw taxonomy
- [OWASP WSTG — Authentication Testing](https://owasp.org/www-project-web-security-testing-guide/stable/4-Web_Application_Security_Testing/04-Authentication_Testing/) — full checklist
- [PayloadsAllTheThings — Login Bypass](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Login%20Bypass) — payloads + tricks
