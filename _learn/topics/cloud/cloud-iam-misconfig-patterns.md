---
title: IAM misconfig patterns
slug: cloud-iam-misconfig-patterns
---

> **TL;DR:** Cross-provider, the same handful of IAM mistakes recur — confused-deputy, wildcards, transitive trust, action-resource mismatch, dangling permissions — and one mental checklist catches them in AWS, Azure, and GCP alike.

## What it is
Identity-and-access misconfigurations across AWS, Azure, and GCP cluster into a small set of structural patterns. The cloud surface keeps changing but the failure modes don't, because they're all variants of "policy admits a principal the author didn't intend to admit." Recognising the pattern in one provider transfers directly to others — the syntax differs, the bug doesn't. See [[cloud-identity-mental-model]] for the underlying primitives.

## Preconditions / where it applies
- Read access to policy documents (trust policies, IAM role definitions, RBAC role assignments, service-account bindings).
- Or: black-box probing rights to call assume/impersonate APIs and observe success.

## Technique
**Pattern 1 — Confused deputy.** A service that acts on behalf of multiple customers but doesn't constrain *which* customer it's currently acting for. AWS fixed this with `aws:SourceAccount` + `sts:ExternalId`; Azure and GCP have analogous `aud`/`sub` constraints. Bug: trust policy omits the constraint, so any customer of the deputy can impersonate any other.

**Pattern 2 — Wildcard principal.** `"Principal": {"AWS": "*"}` (AWS), `"members": ["allUsers"]` (GCP), `Principal: "*"` on a Key Vault access policy (Azure). Always followed by a (often missing) condition that was supposed to narrow it.

**Pattern 3 — Wildcard resource.** Identity policy says `"Resource": "*"` for `secretsmanager:GetSecretValue`, `kms:Decrypt`, `iam:PassRole`. Effective scope: everything. See [[aws-secrets-manager]] for the dump pattern.

**Pattern 4 — Transitive trust.** Role A trusts user U; role B trusts role A. U → A → B, and B has the real privilege. Audit trails show U assuming A; B's privesc is one hop away. See [[aws-sts-assume-role]] chaining.

**Pattern 5 — Action-resource mismatch.** Policy grants `iam:PassRole` on `*` but the calling action (`ec2:RunInstances`) is constrained — still a privesc, because PassRole governs which role can be passed, not which compute service can be launched.

**Pattern 6 — Dangling permissions.** Group, role, or SP that's no longer used but still holds grants. Owner left; group membership inherited; no one notices the path. See [[aws-iam-eventual-consistency-persistence]] for the temporal variant.

**Pattern 7 — Wildcard action.** `"Action": "iam:*"`, `"Action": "secretsmanager:*"`. Includes destructive and write APIs the author didn't mean to grant.

**Pattern 8 — Service-linked confusion.** Service-linked roles (AWS SLR, GCP service agents) appear "owned by AWS/GCP" but their permissions still flow to whoever can invoke the service. Treat as ordinary privesc surface.

Quick hunt commands (AWS example):

```bash
# wildcard principals
aws iam list-roles --query 'Roles[].[RoleName,AssumeRolePolicyDocument]' --output json \
  | jq '.[] | select(.[1].Statement[].Principal == "*" or .[1].Statement[].Principal.AWS == "*")'
# wildcard resources on sensitive actions
aws iam list-policies --scope Local --query 'Policies[].Arn' --output text \
  | xargs -I{} aws iam get-policy-version --policy-arn {} --version-id v1 \
  | jq '.PolicyVersion.Document.Statement[] | select(.Resource=="*" and (.Action|tostring|test("iam:Pass|secretsmanager:Get|kms:Decrypt")))'
```

GCP equivalent: `gcloud asset search-all-iam-policies --scope=organizations/ORG_ID --query='policy:roles/owner'`.
Azure: `Get-AzRoleAssignment | where ObjectType -eq 'Unknown'` (orphaned principals).

## Detection and defence
- Run IAM Access Analyzer (AWS), Defender for Cloud (Azure), Policy Intelligence (GCP) — they flag exactly these patterns.
- Adopt least-privilege starter templates and require condition keys (`aws:SourceAccount`, `iam.googleapis.com/audience`).
- Block `iam:PassRole` on `*` and wildcard principals via SCPs / management-group policies.
- Tag service accounts with owner + purpose; auto-disable dangling ones after N days unused.
- CI-gate Terraform / Bicep with policy-as-code (cnspec, OPA, Checkov) so wildcards never merge.

## References
- [AWS — IAM Access Analyzer](https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html) — automated finding of these patterns
- [HackTricks Cloud — IAM privesc index](https://cloud.hacktricks.wiki/en/pentesting-cloud/aws-security/aws-privilege-escalation/aws-iam-privesc/index.html) — pattern catalog
- [SpecterOps — Identity Snowball](https://posts.specterops.io/) — transitive-trust write-ups
