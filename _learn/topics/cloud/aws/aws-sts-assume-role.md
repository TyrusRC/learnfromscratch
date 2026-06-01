---
title: STS AssumeRole
slug: aws-sts-assume-role
---

> **TL;DR:** `sts:AssumeRole` mints short-lived creds for any role whose trust policy accepts the caller; mis-scoped trust policies (missing ExternalId, wildcard principals, sloppy conditions) collapse the boundary and let attackers chain role hops.

## What it is
`sts:AssumeRole` is the single API behind nearly all AWS pivots. The caller presents an ARN; STS evaluates two things: (1) the caller's identity-based policy must allow `sts:AssumeRole` on that role, and (2) the role's trust policy (`AssumeRolePolicyDocument`) must allow the caller's principal. Trust policies are evaluated independently of org boundaries, so a wildcard or wrong condition is a global door. Once assumed, the returned session can itself assume further roles — role chaining — bounded only by STS's 1h chained-session limit.

## Preconditions / where it applies
- You hold credentials for some principal (user, role, federated identity).
- That principal's identity policy permits `sts:AssumeRole` on at least one target.
- The target's trust policy admits your principal — directly, via account-wildcard, via `aws:PrincipalOrgID`, or via web-identity/SAML.

## Technique
**Find every role you can assume:**

```bash
aws iam list-roles --query 'Roles[].[RoleName,AssumeRolePolicyDocument]' --output json > roles.json
jq -r '.[] | .[0] as $n | .[1].Statement[] | select(.Effect=="Allow") | "\($n)\t\(.Principal)\t\(.Condition // {})"' roles.json
```

**Assume:**

```bash
aws sts assume-role --role-arn arn:aws:iam::ACC:role/Target --role-session-name hop \
  --external-id "$EXT"   # if required
# export credentials, then enumerate again from inside
eval $(aws sts assume-role --role-arn ... \
  --role-session-name hop --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text | awk '{print "export AWS_ACCESS_KEY_ID="$1"\nexport AWS_SECRET_ACCESS_KEY="$2"\nexport AWS_SESSION_TOKEN="$3}')
```

**Common pivot patterns:**
1. **Wildcard principal** — `"Principal": {"AWS": "*"}` with no condition admits any AWS account. See [[aws-cross-account]].
2. **PassRole → AssumeRole** — you can pass a high-priv role to a service (EC2, Lambda, CodeBuild), trigger the service, then call STS from inside the service's runtime.
3. **Role chaining** — assume role A, then from A's session assume role B (B's trust must allow A). Chained sessions are capped at 1h regardless of `DurationSeconds` requested.
4. **Web-identity** — `sts:AssumeRoleWithWebIdentity` for OIDC; see [[gha-oidc-sub-claim-wildcards]] and [[aws-rogue-oidc-idp-persistence]].
5. **SAML** — `sts:AssumeRoleWithSAML` with stolen SAML assertions.

**ExternalId hygiene:** vendor SaaS integrations require `sts:ExternalId` to defeat the confused-deputy problem. If the customer pasted the vendor's example ExternalId verbatim (a known constant), any vendor-account principal can assume the role.

## Detection and defence
- CloudTrail `AssumeRole`, `AssumeRoleWithWebIdentity`, `AssumeRoleWithSAML` — alert on cross-account events to roles not on an allow-list.
- Enforce `aws:SourceAccount` + `aws:SourceArn` conditions on every SaaS trust policy.
- Use IAM Access Analyzer for external-access findings and unused-role findings.
- SCPs to deny `iam:UpdateAssumeRolePolicy` and `iam:PassRole` to broad principals.
- Set `MaxSessionDuration` low (1h) on admin roles to limit window of stolen sessions.

## References
- [AWS — AssumeRole API](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html) — parameters and limits
- [AWS — Role chaining](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_terms-and-concepts.html#iam-term-role-chaining) — 1h cap
- [HackTricks Cloud — AWS IAM privesc](https://cloud.hacktricks.wiki/en/pentesting-cloud/aws-security/aws-privilege-escalation/aws-iam-privesc/index.html) — assume-role chains
