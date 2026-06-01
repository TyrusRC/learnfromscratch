---
title: Entra ID enumeration
slug: entra-id-enum
---

> **TL;DR:** Any authenticated user can read most of an Entra directory through MS Graph; combine it with unauthenticated endpoints (OpenID config, GetUserRealm, autodiscover) to map users, groups, roles, apps, devices, and CA posture before touching the target.

## What it is
Entra ID exposes directory data through MS Graph (`graph.microsoft.com`), the legacy AzureAD Graph (`graph.windows.net`, retiring), and a handful of unauthenticated endpoints. Default permissions grant authenticated members read of users, groups, applications, service principals, devices, and directory roles — enough to plan a privesc path. Even unauthenticated probes leak tenant ID, domain federation type, named users (via `GetCredentialType`), and whether MFA is enforced.

## Preconditions / where it applies
- Unauthenticated phase: only target tenant domain.
- Authenticated phase: any valid tenant user (member or guest depending on guest-access policy).
- Network egress to `*.microsoftonline.com`, `graph.microsoft.com`, `login.microsoftonline.com`.

## Technique
**Unauthenticated tenant fingerprint:**

```bash
curl -s https://login.microsoftonline.com/<tenant>/.well-known/openid-configuration | jq .
curl -s "https://login.microsoftonline.com/getuserrealm.srf?login=user@tenant.com&xml=1"
# tenantID + federation type + branding info
```

User validity check (good for password-spray target-list pruning):

```bash
curl -s -X POST https://login.microsoftonline.com/common/GetCredentialType \
  -H 'Content-Type: application/json' \
  -d '{"Username":"target@tenant.com"}' | jq .IfExistsResult
# 0 = exists, 1 = does not, 5 = throttled
```

**Authenticated enumeration — ROADtools (Dirk-jan Mollema):**

```bash
roadrecon auth -u victim@tenant -p 'Password1'
roadrecon gather                     # dumps entire directory to roadrecon.db
roadrecon gui                        # browse users/groups/apps/CA policies
```

**Authenticated via Graph directly:**

```bash
# all users
curl -H "Authorization: Bearer $T" \
  'https://graph.microsoft.com/v1.0/users?$select=userPrincipalName,id,accountEnabled,onPremisesSyncEnabled'
# directory role members
curl -H "Authorization: Bearer $T" 'https://graph.microsoft.com/v1.0/directoryRoles?$expand=members'
# app registrations and their secrets/cert thumbprints
curl -H "Authorization: Bearer $T" 'https://graph.microsoft.com/v1.0/applications'
# Conditional Access (needs Policy.Read.All — sometimes granted)
curl -H "Authorization: Bearer $T" 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies'
```

**Useful pivots from enum data:**
- `applications` + `servicePrincipals` → find `passwordCredentials` not yet expired ([[app-registration-abuse]], [[service-principal-abuse]]).
- `directoryRoles` → who is Global Admin / Privileged Role Admin / Application Admin.
- `devices` + `users.deviceKeys` → hybrid-join targets for [[entra-device-code-prt-pivot]].
- `groups` with `groupTypes: ['DynamicMembership']` → set your attribute to land in a privileged group.

Tooling: `AzureHound` produces BloodHound-compatible graph data over the same Graph API calls.

## Detection and defence
- Restrict directory read for guests (`Guest user access restrictions = Most restrictive`).
- Disable user/group default read with `Restrict access to Azure AD administration portal` and `Restrict non-admin users from creating tenants` — partial mitigation only.
- Alert on Graph API call patterns indicative of bulk enumeration (high RPS, broad `$select`) via Microsoft Sentinel `Graph activity logs`.
- Conditional Access: require compliant device for Graph access from non-managed clients.
- Treat `Policy.Read.All` and `Application.Read.All` consent as sensitive — review consented apps.

## References
- [ROADtools](https://github.com/dirkjanm/ROADtools) — primary Entra enumeration toolkit
- [AzureHound](https://github.com/SpecterOps/AzureHound) — BloodHound data collector
- [Microsoft Graph API reference](https://learn.microsoft.com/en-us/graph/api/overview) — endpoint list
