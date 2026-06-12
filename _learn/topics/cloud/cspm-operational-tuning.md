---
title: CSPM operational tuning — Wiz, Defender, Lacework, Prisma
slug: cspm-operational-tuning
---

> **TL;DR:** Cloud Security Posture Management (CSPM) tools generate thousands of findings on average enterprises. Operationally tuning CSPM is the difference between a wall of red noise the team ignores, and a working detection program. The skill is suppression discipline, priority scoring, ownership routing, and feedback loops between findings and IaC scanners. Companion to [[cspm-cnapp-dspm-landscape]] for taxonomy; this note is for operators.

## What it is
CSPM tools continuously evaluate cloud config (AWS / Azure / GCP / OCI / Kubernetes) against best-practice or compliance frameworks (CIS, NIST, PCI, ISO). Findings:
- Public S3 bucket
- Missing MFA on IAM user
- Overly-permissive security group
- Unencrypted EBS volume
- VM with public IP and SSH from 0.0.0.0/0
- Database with public access

The list runs to 10,000+ findings on a fresh deployment of a moderate-size AWS org. Operational reality: most never get fixed; some don't even need to be.

## Preconditions / where it applies
- CSPM tool deployed (Wiz, Microsoft Defender for Cloud, Lacework, Prisma Cloud / Palo Alto XSOAR, Orca, CrowdStrike Falcon Cloud Security, Trend Micro Cloud One, Cyngular, etc.)
- Cloud accounts onboarded
- Initial inventory + finding baseline complete
- Now facing the "what do we do with all these findings" question

## Vendor landscape (selected, 2025)

| Vendor | Coverage | Strength | Note |
|---|---|---|---|
| **Wiz** | AWS, Azure, GCP, OCI, Alibaba, K8s | CNAPP; graph-based; rapid ascent | Premium pricing |
| **Microsoft Defender for Cloud** | Azure-strong, AWS/GCP via connectors | Bundled with Defender; CIEM included | Azure-native preferred |
| **Lacework FortiCNAPP** | AWS, Azure, GCP, K8s | ML-driven, fewer rules to tune | Acquired by Fortinet |
| **Prisma Cloud (Palo Alto)** | Broad multi-cloud + K8s | Largest rule library | Complex UI |
| **Orca Security** | AWS, Azure, GCP, OCI, K8s | Sidescanner approach (no agents) | Agentless wins ops |
| **CrowdStrike Falcon Cloud Security** | Multi-cloud + workload | Integrated with EDR | EDR-strong |
| **Sysdig Secure** | K8s, runtime + posture | Runtime + CSPM combined | Falco lineage |
| **Aqua Security CSPM** | Multi-cloud + K8s | Container-strong | Container-first heritage |
| **Tenable Cloud Security** (Ermetic) | Multi-cloud | CIEM-strong | IGA depth |
| **AWS Security Hub / Azure Defender / GCP SCC** | Native cloud | Free-tier; vendor-native | Single cloud limit |

Native cloud CSPMs (Security Hub, Defender, Security Command Center) often suffice for single-cloud orgs; commercial CNAPPs for multi-cloud.

## Operational tradecraft

### Step 1 — Stop generating findings you can't act on

Triage at onboarding:
- Disable rules that don't apply to your architecture (e.g., on-prem VPN findings if you don't use VPN)
- Disable framework-wide compliance packs you're not subject to (don't enable HIPAA if not in healthcare)
- Adjust resource scope (only prod accounts vs sandbox)
- Set finding age policy: surface ages, dismiss stale

Goal: cut Day-0 finding count by 60-80% before anyone looks.

### Step 2 — Prioritise by exploitability + impact

CSPM tools generally provide severity. Treat with skepticism — vendor severity is conservative. Build your own scoring:

| Factor | Weight |
|---|---|
| Internet-exposed | × 3 |
| Holds sensitive data (PII, PCI, secrets) | × 3 |
| Permits credential access | × 2 |
| Has known exploit / exposed to internet | × 5 |
| Production environment | × 2 |
| Dev / sandbox environment | × 0.3 |
| Already mitigated by other control (WAF, network segmentation) | × 0.5 |

Combine into a numeric priority. Top 5% findings get tickets; rest go into trend tracking.

### Step 3 — Routing and ownership

Findings without owners die. Owner resolution:
- Tag-based: resource tag `owner=team-platform` → ticket to team-platform
- Account-based: account ID → owner team via internal map
- Catalog-based: resource → Backstage entity → owner
- Default: cloud central security team for triage / escalation

Auto-create Jira / ServiceNow tickets for top-priority findings; do NOT auto-ticket low-priority (drowns the queue).

### Step 4 — Suppression discipline

Not every finding should be fixed:
- Risk-accepted with documented justification
- Compensating control in place (WAF in front, network ACL blocking)
- Resource scheduled for decommission
- False positive due to scanner limitation

Suppression must:
- Cite a reason
- Reference an approver
- Have an expiration date (review in 6 / 12 months)
- Be tracked in CSPM tool's exception process

Periodically audit suppressions: stale, unreviewed, or with disappearing context.

### Step 5 — Feedback into IaC

CSPM finds production drift; IaC scanners ([[iac-scanning-checkov-tfsec-kics]]) find issues at build time. Closed-loop:
- CSPM finding in prod → root cause analysis → was IaC scanner blind to it?
- Add custom IaC rule preventing recurrence
- Track "preventable in IaC" findings as platform-team OKR

This is the difference between reactive CSPM and proactive posture management.

### Step 6 — Measure what matters

Useful CSPM ops KPIs:
- Mean Time to Remediate (MTTR) by severity / cloud / team
- Findings open age distribution
- Finding recurrence rate (same issue appearing repeatedly = process problem)
- % findings resolved via IaC fix vs manual remediation
- Coverage: % of cloud accounts onboarded; % of resources tagged
- Suppression ratio + expired suppression count

Avoid vanity metric "total findings closed" — incentivises ignoring hard findings.

## Cloud-specific patterns

### AWS
- Native: AWS Security Hub aggregator + AWS Config + GuardDuty
- Common findings: S3 public, IAM unused permissions, missing CloudTrail in regions, EBS unencrypted
- Architectural: ensure Control Tower ([[aws-control-tower-governance]]) baselines aren't fighting CSPM
- See: [[aws-iam-enum]], [[cloud-iam-misconfig-patterns]]

### Azure
- Native: Microsoft Defender for Cloud + Microsoft Sentinel
- Common findings: storage public, NSG too permissive, missing diagnostic settings, KeyVault permissive
- Architectural: align with Azure Landing Zones ([[azure-landing-zones]])
- Hybrid considerations: Entra Connect, on-prem AD findings

### GCP
- Native: Security Command Center (Premium / Enterprise tiers)
- Common findings: bucket public, project owners over-privileged, default service accounts in use, organization policy violations
- Architectural: Organization Policy Service + Folder structure

### Kubernetes
- Common findings: privileged Pod, hostPath, RBAC overly broad, missing PSA labels
- CSPM here overlaps Kubernetes posture management; some tools specialise (Kubescape, Kyverno reports)
- See: [[helm-chart-security-audit]], [[k8s-manifest-source-audit]]

## CSPM vs CNAPP vs CWPP vs CIEM vs DSPM

| Acronym | Focus |
|---|---|
| **CSPM** | Cloud config posture |
| **CWPP** | Cloud workload protection (runtime EDR, vulnerability scanning) |
| **CIEM** | Entitlement / IAM right-sizing |
| **DSPM** | Data security posture (sensitive data inventory + flow) |
| **CNAPP** | Bundles CSPM + CWPP + CIEM + sometimes DSPM |

Most modern vendors converge on CNAPP. Specialty point tools (e.g., dedicated DSPM via BigID, Cyera) still relevant for specific use cases.

See [[cspm-cnapp-dspm-landscape]] for category overview.

## Common implementation pitfalls

- **CSPM at maximum coverage from Day 1** — drowns team; phase rollout
- **No owner routing** — findings pile up in central queue
- **Manual remediation only** — IaC drift continues, same findings reappear
- **Auto-remediation enabled without review** — accidentally breaks workloads
- **Compliance-driven only** — chase PCI checkmarks while real exposures ignored
- **Vendor lock-in via custom rules** — porting policies between CSPMs is painful
- **Findings without CMDB / catalog mapping** — can't route or prioritise

## Auto-remediation: when (and when not)

CSPMs can auto-remediate:
- Re-enable disabled CloudTrail
- Tag untagged resources with defaults
- Apply default encryption to unencrypted EBS
- Close public S3 ACLs

Safe auto-remediations:
- Reversible (you can undo)
- Low-risk (won't break workload)
- Well-tested (used by mature programs)

Risky auto-remediations:
- Block security groups (may cut off legitimate access)
- Disable IAM users (may break service accounts)
- Force resource deletion

Start conservative: notification only → ticket creation → manual approval → auto-remediation for known-safe cases.

## CSPM in compliance workflow

CSPM findings map to compliance frameworks (PCI, HIPAA, SOC 2, ISO 27001). Auditors increasingly accept CSPM evidence in lieu of manual checks.

Pattern:
- Annual audit: pull CSPM reports for relevant framework
- Evidence: CSPM compliance dashboard + finding remediation tickets
- Exceptions: documented suppressions reviewed by auditor

Reduces audit workload by 30-50% for cloud-heavy orgs.

## OPSEC for blue team

- CSPM API/SDK credentials = read-only IAM across all accounts; protect like Tier-0
- Audit logs of who muted / suppressed findings
- Watch for sudden disabling of rules / detectors (insider threat indicator)
- Cross-reference CSPM finding age with attacker dwell time stats — old internet-facing findings = high risk
- Monitor for new resources appearing without standard tags (catalog drift, shadow IT)

## References
- [Wiz cloud security blog](https://www.wiz.io/blog)
- [Microsoft Defender for Cloud docs](https://learn.microsoft.com/azure/defender-for-cloud/)
- [Cloud Security Alliance — CSPM definitions](https://cloudsecurityalliance.org/)
- [Gartner — Cloud Security Posture Management Market Guide](https://www.gartner.com/) — vendor evaluation
- [Open Policy Agent](https://www.openpolicyagent.org/) — policy logic primitive used by some CSPMs

See also: [[cspm-cnapp-dspm-landscape]], [[ciem-cloud-entitlement-management]], [[cloud-iam-misconfig-patterns]], [[iac-scanning-checkov-tfsec-kics]], [[aws-control-tower-governance]], [[azure-landing-zones]], [[zero-trust-architecture-practitioner]], [[cilium-tetragon-falco-runtime]], [[soc-runbook-design]], [[vulnerability-management-lifecycle]]
