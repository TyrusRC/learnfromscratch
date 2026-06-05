---
title: Azure activity log + Entra audit IR
slug: cloud-ir-azure-activity-log
aliases: [azure-activity-log-ir, entra-audit-ir]
---

> **TL;DR:** Azure compromise responds across two logs: **Azure Activity Log** (subscription-level resource operations) and **Entra ID Audit / Sign-in logs** (identity operations). Practical IR flow: anchor on the alert, trace identity in Entra sign-in logs, trace resource impact in Activity Log, correlate via principal ID, and search for persistence in MSGraph activity. Companion to [[cloud-ir-aws-cloudtrail]] and [[entra-cross-tenant-sync-abuse]].

## What each log captures

### Entra ID

- **Sign-in logs** — every interactive and non-interactive auth. Has user, app, IP, conditional-access result, MFA method, risk score.
- **Audit logs** — directory operations: user/group creation, role assignments, policy changes, app registrations.
- **Microsoft Graph Activity Logs** (Preview/Premium) — every Graph API call. Crucial for IR; not enabled by default.
- **Provisioning logs** — Entra Connect sync events; relevant for hybrid IR.

### Azure subscription

- **Azure Activity Log** — control-plane operations (VM create, NSG modify, role assignment, role definition change). Per-subscription.
- **Resource logs** — service-specific data plane (Key Vault access, Storage account access). Per-service, opt-in.
- **Microsoft Defender for Cloud** — alerts + recommendations.

### Other

- **Microsoft Defender XDR** — threat-intel-enriched signals.
- **Microsoft Sentinel** — SIEM that ingests all the above plus custom.

## Investigation flow

### Step 1 — Anchor

The alert points at:
- A user / service principal.
- A time.
- An IP or app.
- An action.

Translate to:
- An Entra Sign-in log query (if identity-shaped).
- An Activity Log query (if resource-shaped).

### Step 2 — Identity tracing (Entra)

For a suspicious user / app:

- **Sign-in log** — every sign-in for the principal across the timeframe.
- **Risky sign-ins** — flagged by Identity Protection.
- **Audit log** — what the principal did in the directory.
- **Conditional Access result** — was the CA policy hit? Did it allow or block?
- **MFA method** — push? FIDO2? legacy?

Look for:
- New IP or geo for the user.
- Token validity stretching past expected session.
- AitM-shaped patterns (cookie use from new IP without recent MFA event).
- Device-code grant ([[oauth-device-code-phishing-m365]]).
- Cross-tenant guest from new tenant ([[entra-cross-tenant-sync-abuse]]).

### Step 3 — Resource tracing (Activity Log)

For the same principal ID, query Activity Log across all subscriptions:

- `Microsoft.Authorization/roleAssignments/write` — role assignments created.
- `Microsoft.Compute/virtualMachines/runCommand/action` — Run Command (interactive).
- `Microsoft.KeyVault/vaults/secrets/read` — secret access (requires resource logs).
- `Microsoft.Network/networkSecurityGroups/securityRules/write` — NSG changes.
- `Microsoft.Storage/storageAccounts/listKeys/action` — storage key listing.
- `Microsoft.Authorization/policyAssignments/write` — policy changes.
- `Microsoft.Resources/deployments/write` — ARM deployments.

### Step 4 — Persistence search

Common Entra persistence:
- New **service principal** registered.
- **Credential added** to existing service principal (`Add service principal credentials`).
- **Federated identity credential** added (OIDC trust to attacker tenant).
- **Application granted high-priv consent** (Mail.ReadWrite, Directory.ReadWrite.All).
- **PIM role activation** outside hours.
- **MFA method added** for the user (alternate phone, recovery email).
- **Cross-tenant access policy** modified ([[entra-cross-tenant-sync-abuse]]).

Common Azure persistence:
- **Custom role definition** with broad permissions.
- **Reader-role assignment** on root management group (gives wide enumeration).
- **Managed identity assigned** to attacker-controlled resource.
- **Automation Account / Logic App / Function** running with privileged identity.
- **Hybrid Worker** on attacker-controlled machine.

### Step 5 — Exfil signals

- Mass enumeration of Storage accounts / Key Vault / SQL DB / Cosmos DB.
- Snapshot creation + cross-tenant share.
- Bulk data export jobs in Synapse / Data Factory.
- Outbound from attacker-spawned VM to non-business endpoint.

## Identity correlation

Service principals make tracing tricky:
- The `objectId` is the principal in Entra.
- The `appId` is the application registration.
- An assertion may use the `appId` or the `objectId` depending on call path.

When chasing a service-principal incident: collect both IDs and search with both.

For users:
- `userPrincipalName` is human-readable but mutable.
- `objectId` is immutable; use for correlation.

## Tooling

- **KQL** (Kusto Query Language) — Azure's query language. Master KQL for Sentinel / Log Analytics queries.
- **Azure CLI** / **PowerShell** for live state.
- **`MicroBurst`** — recon (offence) but useful as IR teaching.
- **`Stormspotter`** / **`AzureHound`** — graph identity relationships.
- **`Sentinel`** detection rules — predefined IR detections.
- **`AzAuditLogReport`** / **`DART`** scripts — Microsoft's published IR scripts.

## Pitfalls

- **Sign-in log latency** — events can lag 5–10 minutes; correlate carefully.
- **Activity log retention** — 90 days default; many tenants haven't extended.
- **Resource-log opt-in** — Key Vault / Storage data plane access invisible unless enabled.
- **Service principal vs user** distinction — beginner queries miss SP events.
- **Cross-tenant guests** — appear as your tenant's identities; trace to home tenant via UPN suffix.
- **Hybrid identity** — Entra Connect-synced users have both on-prem and cloud auth surfaces.

## Workflow to study in a lab

1. Stand up a small Azure environment with Sentinel.
2. Use **Atomic Red Team** Azure tests to emulate compromise scenarios.
3. Write KQL queries to surface each scenario.
4. Practice the five-step investigation flow.

## Related

- [[cloud-ir-aws-cloudtrail]] — AWS analogue.
- [[cloud-ir-gcp-audit-logs]] — GCP analogue.
- [[entra-cross-tenant-sync-abuse]] — attacker pattern.
- [[oauth-device-code-phishing-m365]] — attacker pattern.
- [[conditional-access-bypass-modern]] — attacker pattern.
- [[m365-admin-attacks]] — broader attacker context.
- [[case-study-okta-2023-support-system]] — adjacent identity-vendor IR.

## References
- [Microsoft Learn — Azure Activity Log](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/activity-log)
- [Microsoft Learn — Entra ID audit/sign-in logs](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/concept-audit-logs)
- [Microsoft Sentinel](https://learn.microsoft.com/en-us/azure/sentinel/)
- [Stormspotter](https://github.com/Azure/Stormspotter)
- [Atomic Red Team Azure tests](https://github.com/redcanaryco/atomic-red-team)
- See also: [[cloud-ir-aws-cloudtrail]], [[cloud-ir-gcp-audit-logs]], [[cloud-ir-k8s-audit-logs]], [[entra-cross-tenant-sync-abuse]]
