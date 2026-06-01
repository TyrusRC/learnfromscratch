---
title: Cloud identity mental model
slug: cloud-identity-mental-model
---

> **TL;DR:** Every cloud bug reduces to four questions — *who is the principal, what policy attaches to it, who trusts it, and across what scope* — get fluent in these and provider differences become surface-level.

## What it is
Cloud IAM is not a single product but a recurring shape: a directed graph of **principals** (users, roles, service accounts, managed identities, workloads) with **policies** (lists of allowed/denied actions on resources) connected by **trust relationships** (who may impersonate or assume whom) inside a **scope** (account, project, subscription, tenant, organisation). Reasoning about an unfamiliar service or provider becomes tractable once you map its primitives back onto those four levers.

## Preconditions / where it applies
- Any cloud engagement (AWS, Azure, GCP, OCI, Kubernetes RBAC, SaaS like Okta/Auth0).
- Useful before [[cloud-iam-misconfig-patterns]] enumeration — you need vocabulary first.
- Required mental model for federation work ([[gha-oidc-sub-claim-wildcards]], [[multi-cloud-pivoting]]).

## Technique
Drill the four levers on every cloud object you touch:

1. **Principal** — what identity does the request run as? AWS: IAM user, IAM role (via STS), root account. Azure: user, service principal, managed identity (system- or user-assigned), workload identity. GCP: user, service account, workload identity pool subject. K8s: ServiceAccount, User, Group. Always answer: *who am I right now?* (`aws sts get-caller-identity`, `az account show`, `gcloud auth list`, `kubectl auth whoami`).

2. **Policy** — what is this principal allowed to do? Two flavours: **identity-based** (attached to the principal) and **resource-based** (attached to the resource, naming who may use it). AWS S3 bucket policies, KMS key policies, Lambda resource policies, Azure RBAC scopes, GCP IAM bindings at resource/project/folder/org level. The effective permission is the union (or intersection with SCPs / deny / condition keys).

3. **Trust** — who is allowed to *become* this principal? AWS role trust policy (`sts:AssumeRole`, `AssumeRoleWithWebIdentity`, `AssumeRoleWithSAML`). Azure federated credential. GCP workload identity binding. K8s `TokenRequest`. Trust is where federation lives, and where the highest-impact misconfigs hide.

4. **Scope** — where does the policy apply? AWS account vs organisation (SCPs, RCPs). Azure management group → subscription → resource group → resource. GCP organisation → folder → project → resource. K8s cluster vs namespace. A `*` resource at organisation scope is a different blast radius from `*` at resource scope.

```bash
# Mental drill on any unfamiliar role:
aws iam get-role --role-name X --query 'Role.AssumeRolePolicyDocument'  # trust
aws iam list-attached-role-policies --role-name X                       # identity policy
aws iam list-role-policies --role-name X                                # inline
aws organizations describe-policy --policy-id p-...                     # scope guardrails
```

## Detection and defence
- Catalogue every principal-creation path; alert on new federated credentials, new role trusts, new service accounts (CloudTrail `CreateRole`, Azure activity `Microsoft.ManagedIdentity/*`, GCP `iam.googleapis.com`).
- Enforce permission boundaries / SCPs / org policies as the upper bound of *scope* — defence-in-depth against runaway *policy*.
- Continuously diff trust policies; alert on `Principal: "*"` or wildcard `sub` claims (see [[gha-oidc-sub-claim-wildcards]]).
- Tag every principal with an owner; un-owned identities are the ones attackers persist on.

## References
- [AWS: IAM policy evaluation logic](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html) — formal model of identity vs resource vs SCP.
- [HackTricks Cloud](https://cloud.hacktricks.wiki/) — per-provider primitives catalogue.
- [SpecterOps — Cloud identity research](https://posts.specterops.io/) — attack-graph framing of trust and scope.
