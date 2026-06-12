---
title: Azure Landing Zones — enterprise-scale governance
slug: azure-landing-zones
---

> **TL;DR:** Azure Landing Zones is Microsoft's reference architecture for enterprise-scale Azure deployment. Built around Management Groups (the Azure equivalent of AWS OUs), Azure Policy (governance), Subscription Vending (account factory equivalent), and the Cloud Adoption Framework (CAF). Deployed via Azure Landing Zone Terraform / Bicep accelerators.

## What it is
Two flavours:
- **Azure Landing Zone (ALZ)** — reference architecture + accelerators; you deploy and own
- **Enterprise-Scale Landing Zone (ESLZ)** — older name for the same concept, now superseded

The ALZ pattern provides:
- **Management Group hierarchy** — policy boundaries
- **Subscription Vending** — self-service subscription creation (Azure Account Factory)
- **Policy as Code** — Azure Policy assignments + DeployIfNotExists remediation
- **Hub-and-spoke networking** — central virtual network, regional spokes
- **Identity & Access** — Entra ID + Privileged Identity Management
- **Centralised logging** — Log Analytics Workspace + Sentinel + Azure Monitor

## Preconditions / where it applies
- Azure tenant with Entra ID + Azure subscription(s)
- Plan to scale beyond 5-10 subscriptions
- Greenfield: deploy Day 1. Brownfield: ALZ migration accelerator helps

## Management Group hierarchy (canonical ALZ)

```
Tenant Root
└── Top-level MG (your org)
    ├── Platform MG
    │   ├── Management MG (Log Analytics, monitoring sub)
    │   ├── Identity MG (Entra Connect, identity infrastructure sub)
    │   └── Connectivity MG (hub vnet, ExpressRoute, firewall sub)
    ├── Landing Zones MG
    │   ├── Corp MG (line-of-business, internet-restricted)
    │   └── Online MG (internet-facing workloads)
    ├── Sandbox MG (developer experimentation)
    └── Decommissioned MG (sunsetted subscriptions)
```

Each MG is a policy assignment boundary. Subscriptions inherit MG-level policies.

## Azure Policy — the governance engine

Policy types:
- **Deny** — block resource creation (e.g., no public IPs in Corp)
- **Audit** — log non-compliant resources without blocking
- **Modify** — auto-tag, set defaults at creation
- **DeployIfNotExists** — auto-deploy resources if missing (e.g., diagnostic settings)
- **AuditIfNotExists** — flag if related resource missing
- **Disabled** — placeholder; policy exists but inactive

```bicep
// Example Policy assignment
resource denyPublicIp 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'deny-public-ip-corp'
  scope: managementGroup('alz-corp')
  properties: {
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/...'
    enforcementMode: 'Default'
    parameters: {
      effect: { value: 'Deny' }
    }
  }
}
```

ALZ ships with 100+ pre-configured Policy assignments matching common baselines (CIS, NIST, PCI).

## Initiative / PolicySetDefinition

Group policies into sets for one-click compliance baselines:
- Azure Security Benchmark
- ISO 27001
- NIST SP 800-53
- PCI DSS
- HIPAA HITRUST

Assign Initiative at MG; all enclosed policies activate.

## Subscription Vending

Self-service subscription provisioning:
1. Developer requests new subscription via portal / API
2. ALZ Vending solution creates subscription via EA / MCA agreement
3. Auto-assigns to correct MG based on metadata
4. Applies network configuration, RBAC, monitoring
5. Returns subscription to requester

Implementation: ALZ Subscription Vending Terraform / Bicep template.

## Hub-and-spoke networking

Standard ALZ topology:
- **Hub vnet** in Connectivity sub — Azure Firewall / Network Virtual Appliance, ExpressRoute Gateway, VPN Gateway, central DNS
- **Spoke vnets** in workload subscriptions — peered to hub
- **vWAN** alternative for multi-region with managed routing

Spokes inherit egress routing through hub firewall. Centralised logging at hub.

## Identity foundation

ALZ assumes Entra ID + the following:
- **PIM (Privileged Identity Management)** — JIT elevation for high-priv roles
- **Conditional Access** — phish-resistant MFA for admin
- **Entra ID Identity Protection** — risky-user / risky-sign-in detection
- **Custom roles** — beyond built-in (Owner, Contributor, Reader)

Cross-link: [[entra-id-enum]], [[entra-conditional-access-bypass]], [[conditional-access-bypass-modern]].

## Logging architecture

- **Log Analytics Workspace (LAW)** — central, ideally one per geo for sovereignty
- **Diagnostic settings policy** — auto-enabled on every resource via DeployIfNotExists
- **Microsoft Sentinel** — SIEM layered on LAW
- **Activity logs** at MG level — across all subs
- **Defender for Cloud** — CSPM + workload protection (see [[cspm-cnapp-dspm-landscape]])

## Cost management

- **Budgets** per subscription
- **Cost Management exports** to storage account for analysis
- **Reservations and Savings Plans** at MG level
- **Tagging policy** enforced via Azure Policy (tag inheritance, required tags)
- **Cost allocation** by tags / MG / subscription

## Tradecraft — deployment

### Phase 1 — Plan (Weeks 1-2)
- Map current state: existing subscriptions, networking, identity
- Decide canonical MG hierarchy
- Identify sovereign regions / compliance scopes
- Pick deployment tool: Terraform accelerator vs Bicep accelerator vs ARM

### Phase 2 — Deploy ALZ accelerator (Weeks 2-4)
- Terraform: `terraform-azurerm-caf-enterprise-scale` module
- Bicep: ALZ Bicep accelerator from Microsoft repo
- ARM: legacy; not recommended for new deployments

The accelerator creates MGs, Policies, network hub, log workspace.

### Phase 3 — Migrate existing subscriptions (Weeks 4-12)
For each existing sub:
- Move into target MG
- Resolve policy violations triggered by inheritance
- Update RBAC to PIM-eligible
- Onboard to centralised logging

### Phase 4 — Enable Subscription Vending (Month 3+)
Self-service subscription creation for new workloads.

### Phase 5 — Continuous improvement (Ongoing)
- Add custom policies as new requirements emerge
- Tighten policies from Audit → Deny once compliance reached
- Update CAF Ready / Manage practices

## ALZ vs CAF Foundation vs Bicep accelerator

Confusion arises because Microsoft offers multiple branded patterns:
- **CAF (Cloud Adoption Framework)** — methodology / business framework (the "why" + "how")
- **CAF Foundation** — minimal landing zone for small adopters
- **CAF Enterprise-Scale / ALZ** — full ref architecture for enterprises
- **ALZ Accelerator** — IaC implementation of ALZ

All converge on the same architecture; pick implementation tool based on team skills.

## Hub vs distributed firewall

Two ALZ network patterns:
- **Hub firewall** — Azure Firewall in hub; spokes route through
- **Distributed firewall** — each spoke has its own NSG + optional NVA; lighter weight

Hub firewall preferred for regulated environments; distributed for cost-conscious.

## Multi-region

- ALZ supports multi-region; deploy LAW per region for sovereignty
- Each region: own hub vnet, peered intra-region
- Cross-region peering for limited workload patterns

## Common implementation pitfalls

- **Over-policied** — 200 Policy assignments overlapping; remediate slow
- **Tenant root scope** — assigning policies at tenant root affects EVERYTHING including Microsoft-internal subscriptions
- **Migrating before stabilising MG hierarchy** — re-organising MGs mid-migration thrashes
- **Forgetting "decommission" path** — old subscriptions accumulate; need formal sunset MG and process
- **Privileged Identity Management not enforced** — emergency-access permanent assignments creep
- **DeployIfNotExists without managed identity** — policy doesn't apply; silent failure
- **Hybrid identity (Entra Connect) skipped** — on-prem AD impacts ignored; ITDR ([[itdr-identity-threat-detection-response]]) blind to hybrid

## ALZ vs AWS Control Tower

| Aspect | Azure ALZ | AWS Control Tower |
|---|---|---|
| Hierarchy | Management Groups | Organizational Units |
| Policy | Azure Policy | SCPs (preventive) + Config rules (detective) |
| Centralised log | Log Analytics Workspace | S3 (Log Archive) |
| Identity | Entra ID + PIM | IAM Identity Center |
| Account factory | Subscription Vending | Account Factory / AFT |
| Self-service | Native portal + Vending | Service Catalog product |
| Cost | LAW ingestion + transactional | Config + CloudTrail S3 + KMS |
| Multi-cloud sibling | n/a | n/a |

Conceptually identical; tooling differs.

## OPSEC for blue team

- MG hierarchy changes: Tier-0 alert
- Policy assignment modification: alert (especially DENY → AUDIT downgrade)
- Subscription movement between MGs: audit
- PIM activation outside change window: review
- Cross-tenant: see [[entra-cross-tenant-sync-abuse]]

## References
- [Azure Landing Zone docs](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [Terraform ALZ module](https://github.com/Azure/terraform-azurerm-caf-enterprise-scale)
- [Bicep ALZ accelerator](https://github.com/Azure/ALZ-Bicep)
- [Azure Policy built-in](https://www.azadvertizer.net/) — community catalog
- [Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/)
- [Microsoft Defender for Cloud](https://learn.microsoft.com/azure/defender-for-cloud/)

See also: [[aws-control-tower-governance]], [[entra-id-enum]], [[entra-conditional-access-bypass]], [[entra-connect-exploitation-2025]], [[cspm-cnapp-dspm-landscape]], [[ciem-cloud-entitlement-management]], [[managed-identities]], [[cloud-iam-misconfig-patterns]], [[multi-cloud-pivoting]], [[zero-trust-architecture-practitioner]]
