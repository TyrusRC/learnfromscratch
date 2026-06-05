---
title: OAuth device-code phishing (Microsoft 365 / Entra)
slug: oauth-device-code-phishing-m365
aliases: [device-code-phish, oauth-device-flow-abuse, illicit-consent-device-code]
---

> **TL;DR:** The OAuth 2.0 device-authorisation grant is intended for input-constrained devices (TVs, CLIs) — user gets a code and types it into a web page on another device. Attackers initiate the device-code flow with a victim's tenant, then phish the victim into entering the code at `microsoft.com/devicelogin`. The user authenticates to *their* legitimate tenant login page (no AitM, no MFA bypass needed) but the resulting tokens land in attacker's hands. Used heavily by APT and CTI-tracked actors. Companion to [[aitm-evilginx-modern-phishing]] and [[oauth-modern-attacks]].

## Why this matters

- The login page is **legitimate Microsoft** — no lookalike domain. Vigilant users still get caught.
- **MFA completes** for the user; attacker still gets tokens.
- The phish doesn't need any infrastructure beyond an email + the code.
- Detection signals at the IdP are subtle — looks like a normal sign-in from the user's geo.
- Used by named threat groups (Storm-0381, Midnight Blizzard / NOBELIUM, others).

## The OAuth device flow recap

```
+--------+                                +---------------+
|        |--(A)-- Client Identifier ----->|               |
|        |                                |     Auth      |
|        |<-(B)-- Device + User Code -----| Server (Microsoft) |
| Device |                                |               |
|        |--(C)-- Polling (token endpoint)|               |
|        |                                |               |
|        |<-(D)-- Access Token  ----------|               |
+--------+                                +---------------+
       |
       v
  User enters User Code in browser somewhere else
  Browser authenticates user; user confirms device.
```

The flow is designed for "I'm at the TV, type this code at example.com/activate on your phone." But the device requesting the code can be *anywhere*.

## The phish

1. Attacker calls Microsoft's OAuth device-authorisation endpoint:
   ```
   POST https://login.microsoftonline.com/{tenant}/oauth2/v2.0/devicecode
   client_id={client_id of MS Graph / Teams / Office}
   scope=offline_access user.read mail.read
   ```
2. Microsoft returns a device_code + user_code (8-char string) + verification_uri (`microsoft.com/devicelogin`).
3. Attacker emails / DMs the victim:
   > Please verify your tenant by going to https://microsoft.com/devicelogin and entering code `ABC12345`. This is required for migration / compliance / etc.
4. Victim follows the link to the real Microsoft URL.
5. Victim logs in (legit page) and enters the code.
6. Microsoft prompts: "Allow `Microsoft Office` to access your account?" Victim confirms.
7. Attacker's polling thread receives `access_token`, `refresh_token` for the scopes requested.

## What the attacker can do with tokens

Depending on scopes requested:
- **Read all mail** — for executive accounts, weeks of mail in a compressed exfil.
- **Send mail as user** — internal phishing / business email compromise (BEC).
- **Read OneDrive / SharePoint files**.
- **Read Teams chat history**.
- **Manage Azure / Entra** — if a Cloud Application Administrator falls for it.

Refresh tokens are long-lived (default 90 days) unless Conditional Access enforces shorter.

## Pre-conditions

- User can be persuaded to enter a code.
- Tenant doesn't block the device-code flow via Conditional Access (most don't by default).
- `client_id` used is a recognised Microsoft first-party app (Office, Teams, Azure CLI) — these don't require consent prompts beyond the first time.

The attack works against most M365 tenants out of the box.

## Defensive baseline

For Entra ID:
- **Conditional Access** policy blocking the device-code flow except for whitelisted use cases. Microsoft published a template for this.
- **Reject device-code grants from external IPs** — restrict to managed devices on corporate network.
- **Block legacy / first-party app consents** to non-admin users via app-governance.
- **Continuous Access Evaluation (CAE)** — revoke session promptly on risk signal.

For users:
- **Never enter a device code** received in email / DM / phone call.
- **Verify any "compliance check" or "tenant migration"** request through a known internal channel first.

## Detection signals

- Sign-in events with **device-code authentication method** that don't match normal device-code use cases (CLI tools, IoT).
- Sign-in geo from user's normal location, but downstream API access from a different geo (the token leaves the device).
- Mass read of mail / files via Graph API from an unfamiliar IP.

Microsoft's identity protection has flagging for this class; surface and tune.

## Workflow to study in a lab

1. Create a test tenant with a benign user account.
2. Use the `requests` library or `azure-cli` to initiate device-code flow:
   ```
   az login --use-device-code --tenant {test-tenant}
   ```
3. Watch the output — you'll see the user code.
4. From a different browser, sign in to the test account and enter the code.
5. Examine the resulting token: scopes, expiry, refresh token.
6. Configure a Conditional Access policy blocking device-code grants; repeat; observe failure.

## Variants

- **Device-code with arbitrary tenant** — attacker requests code against `common` tenant; victim's tenant resolves at sign-in. Works against any tenant.
- **Combined with AitM** — if device-code is blocked, AitM is the fallback.
- **Combined with social engineering** — fake IT support flow.
- **Authentication-broker abuse** — using Azure PowerShell / `Microsoft.Identity.Client` SDK to script the flow.

## Related

- [[aitm-evilginx-modern-phishing]] — alternative path.
- [[oauth-modern-attacks]] — broader OAuth attack surface.
- [[conditional-access-bypass-modern]] — what to do post-token.
- [[m365-admin-attacks]] — what privileged tokens enable.
- [[mfa-fatigue-tradecraft]] — different bypass class.

## References
- [Microsoft — device code flow](https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-device-code)
- [Microsoft Defender for Cloud Apps — illicit consent](https://learn.microsoft.com/en-us/defender-cloud-apps/)
- [Mandiant — UNC4990 / device-code campaigns](https://cloud.google.com/blog/topics/threat-intelligence)
- [TrustedSec — device-code phishing](https://www.trustedsec.com/blog)
- See also: [[oauth-modern-attacks]], [[aitm-evilginx-modern-phishing]], [[m365-admin-attacks]], [[conditional-access-bypass-modern]]
