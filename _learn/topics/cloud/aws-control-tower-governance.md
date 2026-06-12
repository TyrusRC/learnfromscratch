---
title: AWS Control Tower — multi-account governance
slug: aws-control-tower-governance
---

> **TL;DR:** AWS Control Tower is the managed multi-account governance layer on top of AWS Organizations. It provisions a Landing Zone with mandatory guardrails (Service Control Policies + AWS Config rules + CloudTrail org trail), the Account Factory for self-service account creation, and SSO via IAM Identity Center. Standard starting point for any org running 5+ AWS accounts.

## What it is
Control Tower sits above AWS Organizations and pre-configures:
- **OU structure** — Foundational OUs (Security, Sandbox); Additional OUs created per workload
- **Log Archive account** — central CloudTrail + Config bucket
- **Audit account** — read-only cross-account access for security
- **Guardrails** — preventive (SCP) and detective (Config rules)
- **Account Factory** — Service Catalog product for self-service account creation
- **IAM Identity Center** — SSO with permission sets (see [[aws-iam-identity-center-internal-abuse]])

It's NOT free — Config rules and CloudTrail across accounts cost real money, often $1000s/month for large orgs.

## Preconditions / where it applies
- AWS Organizations enabled
- Single home region for Control Tower (us-east-1 most common); guardrails extend to opted-in regions
- No conflicting existing CloudTrail / Config / SCP setup (Control Tower will refuse to deploy on top of conflicting state)
- Greenfield orgs: deploy Day 1. Brownfield: significant migration effort

## OU / account architecture

```
Root
├── Security OU (mandatory)
│   ├── Log Archive
│   └── Audit
├── Sandbox OU (optional)
│   └── Dev playgrounds
├── Workload OUs (you create)
│   ├── Production
│   │   ├── app1-prod
│   │   ├── app2-prod
│   │   └── ...
│   ├── Non-production
│   │   ├── app1-staging
│   │   ├── app1-dev
│   │   └── ...
│   └── Shared Services
│       ├── networking
│       ├── shared-tools
│       └── ...
└── Suspended OU (for decommission)
```

OU = policy boundary. Accounts inside an OU inherit OU-level SCPs and Config rules.

## Guardrails

Guardrails come in two flavors:

### Preventive (Service Control Policies)
Block actions before they happen. Examples (selected):
- `Disallow Changes to AWS Config Aggregator`
- `Disallow Changes to CloudTrail`
- `Disallow Public Read Access to S3`
- `Disallow Internet Connections via IGW`

Mandatory guardrails enable automatically on Landing Zone. Optional guardrails toggle per OU.

### Detective (AWS Config rules)
Detect non-compliant resources. Examples:
- `Detect Public Write Access to S3 buckets`
- `Detect MFA on IAM root user`
- `Detect untagged resources`
- `Detect publicly accessible EBS snapshots`

Detective guardrails generate Config findings; don't block.

### Proactive (CloudFormation hooks)
Newer category (2023+): block CloudFormation deployment if the template would violate rule. Earlier in CI than runtime detective.

## Tradecraft — deployment

### Phase 1 — Plan OU structure (Week 1-2)
- Map workloads to OUs based on policy similarity
- Decide environment hierarchy (per-environment OUs vs per-workload-OU-with-env-subaccounts)
- Identify accounts that must NOT be enrolled (legacy, compliance-isolated)

### Phase 2 — Enable Control Tower (Week 2-3)
- Designate home region
- Create Log Archive + Audit accounts (Control Tower creates)
- Verify CloudTrail org trail flows
- Verify Config aggregator collects

### Phase 3 — Enroll existing accounts (Weeks 3-8)
Brownfield only. Per-account:
- Verify no conflicting CloudTrail / Config
- Use AWS Account Factory for Terraform (AFT) — IaC-based account enrollment
- Or self-service portal for one-off enrollment
- Move account into target OU
- Guardrails apply

### Phase 4 — Account Factory rollout (Ongoing)
Enable team self-service:
- Account requests through Service Catalog product
- Auto-creates account, applies guardrails, configures SSO permission sets
- Reduces ticket queue for platform team

### Phase 5 — Customize with AFT (Ongoing)
Account Factory for Terraform provides:
- Per-account Terraform baseline (network, IAM roles, monitoring)
- Per-account customizations
- GitOps workflow via CodeCommit / GitHub
- Reproducible account configuration

## Common patterns

### Hub-and-spoke networking
- Networking account holds Transit Gateway, central VPN endpoints, central NAT, DNS resolver
- Workload accounts attach to Transit Gateway via Resource Access Manager (RAM)
- No internet egress from workload accounts directly

### Centralised logging
- Log Archive account receives CloudTrail, Config, VPC Flow Logs, ALB logs, etc.
- Bucket policy enforces append-only writes
- Lifecycle to S3 Glacier for cost
- Separate SIEM (Sentinel, Splunk, Sumo) ingests from Log Archive

### Centralised security tools
- Security Hub aggregator in Audit account aggregates findings across org
- GuardDuty delegated admin in Audit account
- Inspector delegated admin
- Macie delegated admin (PII scanning)
- One IAM role across accounts for security team read access

### Cost management
- Cost Categories by OU for chargeback
- Budgets per workload account
- Cost anomaly detection at org level
- Compute Optimizer recommendations

## Guardrail customisation

Beyond the built-in guardrails, custom SCPs for org-specific policies:

```json
{
  "Sid": "DenyAllExceptListedActions",
  "Effect": "Deny",
  "NotAction": [
    "iam:Get*",
    "iam:List*",
    "iam:Pass*",
    "sts:AssumeRole",
    "s3:GetObject",
    ...
  ],
  "Resource": "*",
  "Condition": {
    "StringNotEquals": {"aws:PrincipalTag/environment": "production"}
  }
}
```

Attach custom SCP at OU level. Be cautious — overly broad Deny can lock out your own admin access.

## Drift detection
Control Tower detects "drift" when:
- Manual change to CloudTrail
- SCP modified outside Control Tower
- IAM Identity Center config altered
- Log Archive bucket policy weakened

Console + Console Notifications alert. Remediation via Control Tower "repair" or manual restoration.

## Multi-region considerations
- Control Tower opt-in per region; default deploys to home region only
- Guardrails extend to all governed regions
- Non-governed regions: no Config aggregation, no guardrails — useful for opt-out (sovereign region not in scope)
- Common pattern: govern us-east-1, us-west-2, eu-west-1, ap-southeast-1, others as needed

## AFT vs Landing Zone Accelerator (LZA)

Two AWS-blessed IaC patterns:
- **AFT (Account Factory for Terraform)** — Terraform-first, account-level customization
- **LZA (Landing Zone Accelerator)** — CloudFormation-first, org-wide reference architecture

LZA preferred for highly regulated workloads (FedRAMP, FSI, healthcare). AFT preferred for orgs already Terraform-heavy.

## Common implementation pitfalls

- **Skipping Account Factory** — every account becomes a snowflake; baseline drift
- **Modifying Log Archive bucket policy** — Control Tower will flag drift; resist "convenience" changes
- **Using root account for ongoing operations** — root should be reserved for break-glass; use IAM Identity Center
- **Conflicting CloudTrail** — disable per-account CloudTrails before enrollment; use org trail only
- **Service Control Policies blocking break-glass** — keep an admin path that survives even worst-case SCP
- **Region opt-in inconsistency** — workload in non-governed region escapes detective guardrails

## Brownfield migration realities

Migrating an existing AWS Org to Control Tower:
- 6-12 month engagement for medium org (50-200 accounts)
- Existing CloudTrail / Config must be aligned with Control Tower's model
- Per-account work to move into managed OUs
- IAM users → Identity Center migration
- SCP rationalization (existing SCPs vs Control Tower mandatory)
- Often: partial enrollment, not 100% — accept tradeoff for legacy accounts

## OPSEC for blue team

- Org trail tampering attempt: high-severity alert
- IAM Identity Center permission-set assignment outside CI/CD: alert (see [[aws-iam-identity-center-internal-abuse]])
- Drift detection notifications: triage as security event, not noise
- Account Factory request from non-CI source: alert
- Guardrail disable / detach: Tier-0 alert

## References
- [AWS Control Tower docs](https://docs.aws.amazon.com/controltower/)
- [AWS Multi-Account Strategy](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/organizing-your-aws-environment.html)
- [Account Factory for Terraform (AFT)](https://github.com/aws-ia/terraform-aws-control_tower_account_factory)
- [Landing Zone Accelerator](https://github.com/awslabs/landing-zone-accelerator-on-aws)
- [AWS Security Reference Architecture](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/welcome.html)

See also: [[azure-landing-zones]], [[aws-organisations-abuse]], [[aws-iam-identity-center-internal-abuse]], [[cloud-iam-misconfig-patterns]], [[cspm-cnapp-dspm-landscape]], [[ciem-cloud-entitlement-management]], [[aws-iam-enum]], [[multi-cloud-pivoting]], [[zero-trust-architecture-practitioner]]
