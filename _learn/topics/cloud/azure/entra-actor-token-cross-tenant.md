---
title: Entra Actor token cross-tenant impersonation
slug: entra-actor-token-cross-tenant
---

> **TL;DR:** CVE-2025-55241 — an undocumented "Actor" token issued for service-to-service Graph calls was accepted by the legacy Azure AD Graph endpoint as any user in any tenant, including Global Admin, with no logging in the target.

## What it is
Microsoft uses "Actor tokens" internally so first-party services can prove they're calling on behalf of a user without going through the normal user auth flow. Dirk-jan Mollema (Outsider Security / ROADtools) discovered that legacy Azure AD Graph (`graph.windows.net`) would validate the Actor token's signature against Microsoft's signing keys but never check that the impersonated `tid` (tenant ID) matched the token's issuing tenant. An attacker could request an Actor token from their own tenant, then craft an impersonation token claiming any objectId/tid pair and use it against AAD Graph as that user — including Global Administrators — in any tenant on the planet. Microsoft patched it in September 2025 and assigned CVE-2025-55241.

## Preconditions / where it applies
- (Historical) any Entra tenant the attacker controlled — Actor tokens could be requested with normal app permissions.
- Target tenant: any tenant where AAD Graph was reachable (the entire planet pre-fix).
- Knowledge of a target user's `objectId` and tenant `tid` (both trivially discoverable).
- No longer exploitable post-patch; useful as a historical case study and a model for what to hunt for.

## Technique
1. Mint an Actor token from the attacker tenant via the `S2S` endpoint.
2. Forge an impersonation header claiming a target tenant + user objectId.
3. Call AAD Graph (`graph.windows.net/<targettid>/...?api-version=1.6`) — every call executes as the impersonated identity, no MFA, no Conditional Access, no sign-in log in the target tenant.

```text
POST https://login.microsoftonline.com/<attacker_tid>/oauth2/token
client_id=<first-party-app>
grant_type=client_credentials
resource=00000002-0000-0000-c000-000000000000  # AAD Graph
# Receives an Actor token

# Forge impersonation envelope claiming target tenant + GA objectId
GET https://graph.windows.net/<target_tid>/users?api-version=1.6
Authorization: Bearer <forged_token>
```

Mollema's `roadoidc` / `roadtx` tooling demonstrated the issuance flow. Calls landed in the *attacker's* M365 audit log only — the victim tenant had no record of the actions.

## Detection and defence
- Microsoft fixed the validation gap server-side in September 2025; no customer action is required for the underlying flaw.
- Retire any remaining reliance on AAD Graph (`graph.windows.net`) — moved to deprecated status; use Microsoft Graph.
- For historical hunting: review Microsoft Graph audit / unified audit logs for AAD Graph reads in 2024–2025, especially across tenant boundaries.
- Treat any undocumented token type with the same suspicion: signature ≠ authorisation; the issuer's intended tenant scope must be enforced separately.
- Related: [[entra-device-code-prt-pivot]], [[app-registration-abuse]], [[entra-connect-exploitation-2025]].

## References
- [Dirk-jan Mollema — Unauthenticated tenant takeover with Actor tokens](https://dirkjanm.io/obtaining-global-admin-in-every-entra-id-tenant-with-actor-tokens/) — full write-up of CVE-2025-55241.
- [MSRC — CVE-2025-55241](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2025-55241) — vendor advisory and timeline.
