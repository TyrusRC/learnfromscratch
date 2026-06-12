---
title: CIEM — Cloud Infrastructure Entitlement Management
slug: ciem-cloud-entitlement-management
---

> **TL;DR:** CIEM tools analyse cloud IAM permissions across AWS, Azure, GCP, K8s to find effective (not just configured) over-privilege. Where CSPM asks "is the bucket public?", CIEM asks "which 47 humans + 312 service accounts can read the bucket, and which actually do?". Right-sizing entitlements is the most under-addressed cloud control; CIEM is the operational tool.

## What it is
Cloud IAM is staggeringly complex: AWS has 14,000+ actions across 300+ services; Azure has thousands of role definitions; GCP has 9,000+ predefined permissions. Multi-cloud orgs face combinatorial complexity. Most cloud breaches involve over-privileged identities — IAM is the primary attack surface.

CIEM tools:
- **Map effective permissions** — what can each identity actually do, including indirect (assume role chains, group memberships, federated identities)?
- **Measure usage** — which permissions are actually exercised vs theoretical
- **Recommend reductions** — least-privilege policies generated from observed usage
- **Detect anomalies** — sudden expansion of permissions or first-use of unusual permission
- **Track shadow admins** — identities with effective admin via subtle paths

## Preconditions / where it applies
- Multi-account or multi-cloud environment with non-trivial IAM
- Existing CSPM may have basic IAM findings; CIEM goes deeper
- Compliance contexts requiring least-privilege evidence (SOC 2, ISO 27001, PCI)

## Market landscape (2025)

| Vendor | Coverage | Strength |
|---|---|---|
| **Wiz** | AWS, Azure, GCP, OCI, K8s | CNAPP with strong CIEM; graph-based |
| **Microsoft Defender for Cloud (CIEM)** | Multi-cloud (Azure-first) | Bundled with Defender, Entra-native |
| **Sonrai Security** | AWS, Azure, GCP, identity graph | Identity-focused; cross-resource graph |
| **Permiso** | Multi-cloud + SaaS | Identity behaviour analytics |
| **CyberArk Conjur Cloud / Secureworks** | Multi-cloud | Identity governance focus |
| **Ermetic** (now Tenable Cloud Security) | Multi-cloud | Tenable-integrated |
| **Britive** | Multi-cloud JIT | Just-in-time access focus |
| **Saviynt Cloud PAM** | Multi-cloud | IGA-extended CIEM |
| **AWS IAM Access Analyzer** | AWS only | Native + free; policy-level findings |
| **GCP Policy Intelligence / IAM Recommender** | GCP only | Native + free |

CSPM tools (Prisma Cloud, Lacework, Orca) include CIEM modules; sometimes adequate, sometimes deeper specialty tool needed.

## Core concepts

### Configured vs effective permissions
**Configured** — what IAM policy text says.
**Effective** — what the identity can actually do after evaluating all policies, group memberships, role chains, SCPs, deny boundaries.

CIEM computes effective by simulating policy evaluation across the entire identity graph.

### Direct vs indirect privileges
**Direct** — identity has policy granting `s3:GetObject` on bucket.
**Indirect** — identity can assume role X which can assume role Y which has `s3:GetObject`. Same outcome.

CIEM follows the assume-role chain.

### Toxic combinations
Permissions individually fine, but combined enable escalation:
- `iam:CreateAccessKey` + `iam:ListUsers` = can create keys for any user
- `iam:PassRole` + `lambda:CreateFunction` = can run code as any role
- `s3:PutObject` on `*` + `s3:GetObjectAcl` on `*` = data exfil + tampering
- Service-linked role abuse (CVE-class for many services)

### Unused permissions
Over a 90-day window, what fraction of granted permissions did the identity actually exercise? Typical results: 5-15% used. CIEM proposes right-sized policy based on usage.

### Shadow admin
Identity with effective admin via paths the human owner doesn't realise:
- Member of group with `*` on `*`
- Can assume role with elevated privileges
- Cross-account trust path

## Tradecraft

### Step 1 — Onboard cloud accounts to CIEM
- Read-only IAM role per cloud account
- Connection to CloudTrail / Activity Logs / Audit Logs
- Inventory of identities (users, groups, roles, service accounts)

### Step 2 — Discover identity graph
CIEM ingests:
- Identities (humans + machine)
- Groups + memberships
- Roles + trust policies
- Permission boundaries / SCPs
- Resource policies (bucket policies, etc.)

Builds graph: identity → permissions → resources.

### Step 3 — Compute effective permissions
For each identity, simulate IAM evaluation; produce effective permission set.

### Step 4 — Observe usage
Ingest CloudTrail / Activity / Audit logs over 30-90 days. Mark each granted permission as "used" or "unused".

### Step 5 — Recommend right-sized policy
CIEM generates least-privilege policy preserving used permissions, removing unused.

```json
// Before: managed policy AmazonS3FullAccess
// After: CIEM recommendation
{
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ],
    "Resource": [
      "arn:aws:s3:::app-data-bucket",
      "arn:aws:s3:::app-data-bucket/*"
    ]
  }]
}
```

### Step 6 — Test + apply
- Apply policy to dev / staging first
- Monitor for AccessDenied errors over 1-2 weeks
- Promote to prod once stable

### Step 7 — Continuous monitoring
- New permissions granted: review
- Permissions expanded without business justification: alert
- First-time use of dormant permission: anomaly
- Identity drift: re-baseline quarterly

## Just-in-Time (JIT) access

CIEM + JIT is the modern privilege management pattern:
- Default-deny standing privileges
- Privileged actions require time-bound elevation
- Tools: Britive, Saviynt, Entra PIM, AWS IAM Identity Center session policies, Boundary, Teleport
- Audit trail of every elevation: who, what, when, why

## Cloud-specific patterns

### AWS
- IAM Access Analyzer for unused access finding (native, free)
- Service Control Policies (SCPs) as deny boundaries at OU level (Control Tower)
- Permission boundaries on roles
- Resource-based policies (S3, KMS, SNS, SQS) layered with identity-based
- Common shadow admin: `iam:PassRole` + service-linked roles

### Azure
- Entra ID built-in roles + custom roles
- Privileged Identity Management (PIM) for JIT
- Conditional Access for sign-in conditions
- Managed identities for resources
- Common shadow admin: service principal with `Application.ReadWrite.All`

### GCP
- IAM Recommender + Policy Intelligence
- Conditional IAM bindings
- Service account impersonation chains
- Hierarchical resource model
- Common shadow admin: `iam.serviceAccountTokenCreator` on broader scopes

### Kubernetes
- ClusterRoles + ClusterRoleBindings
- Service Accounts + tokens
- IRSA / Pod Identity for cross-cloud auth
- Common shadow admin: cluster-admin via dangerous CRD operator install

## Common implementation pitfalls

- **CIEM findings without remediation workflow** — discovery without action is shelf-ware
- **Mass right-sizing all at once** — breaks workloads; one team at a time, monitored rollout
- **Ignoring service principals** — humans audited, machine identities (often more numerous and privileged) ignored
- **CSPM-only without CIEM depth** — basic IAM rules miss indirect privilege paths
- **Standing privileges normalisation** — JIT installed but everyone has standing access "for emergencies"
- **Federated identity blind spots** — SAML/OIDC-federated users from external IdP appear differently than native identities

## Building CIEM without a commercial tool

For smaller orgs, free / OSS options:
- **AWS IAM Access Analyzer** — generate least-privilege policies (free)
- **GCP IAM Recommender** — usage-based recommendations (free)
- **Azure Defender for Cloud Entitlement** — included in Defender CSPM ($)
- **PMapper (NCC Group)** — open-source AWS IAM graph tool
- **Cloudsplaining (Salesforce)** — AWS IAM policy assessment
- **PolicySentry (Salesforce)** — least-privilege AWS policy generator
- **Crowbar / Khaos** — community AWS IAM right-sizing

Combine native cloud tools + OSS scripts for poor-man's CIEM. Doesn't scale to large multi-cloud but works for small environments.

## CIEM + ITDR (identity threat detection)

CIEM = right-sizing entitlements (proactive)
ITDR = detecting identity attacks in real time (reactive)

Pair both. See [[itdr-identity-threat-detection-response]].

## OPSEC for blue team

- Effective-permission expansion = high-fidelity attack signal
- New trust policy granting cross-account access: audit
- Service account credentials suddenly exercising dormant permissions: anomaly
- Federated identity from unusual IdP: alert
- CIEM tool itself = high-priv; protect its IAM role

## References
- [Wiz CIEM blog](https://www.wiz.io/blog) — practitioner research
- [Microsoft Defender CIEM](https://learn.microsoft.com/azure/defender-for-cloud/concept-permissions-management) — Entra Permissions Management
- [AWS IAM Access Analyzer](https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html)
- [GCP Policy Intelligence](https://cloud.google.com/policy-intelligence)
- [Salesforce PolicySentry](https://github.com/salesforce/policy_sentry)
- [PMapper](https://github.com/nccgroup/PMapper)
- [Cloudsplaining](https://github.com/salesforce/cloudsplaining)
- [CSA — CIEM definitions and use cases](https://cloudsecurityalliance.org/)

See also: [[cspm-cnapp-dspm-landscape]], [[cloud-iam-misconfig-patterns]], [[aws-iam-enum]], [[aws-assumerole-chains]], [[aws-iam-identity-center-internal-abuse]], [[azure-managed-identity-abuse]], [[gcp-workload-identity-federation-abuse]], [[entra-id-enum]], [[itdr-identity-threat-detection-response]], [[zero-trust-architecture-practitioner]], [[aws-control-tower-governance]], [[azure-landing-zones]]
