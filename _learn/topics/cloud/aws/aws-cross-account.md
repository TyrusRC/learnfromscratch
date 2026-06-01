---
title: AWS cross-account
slug: aws-cross-account
---

> **TL;DR:** Trust policies that name external account IDs or `*` principals, plus RAM-shared resources, let a foothold in account A pivot into account B through `sts:AssumeRole` or shared subnets/keys.

## What it is
Cross-account access in AWS lives in a role's trust policy (`AssumeRolePolicyDocument`). When that policy lists an external account, an external role, or `"Principal": {"AWS": "*"}` without a hardening condition, identities outside the owning account can call `sts:AssumeRole` and obtain temporary credentials. AWS RAM (Resource Access Manager) adds a second pivot path: shared subnets, transit gateways, KMS keys, and license-manager configs let an attacker in the consumer account influence producer-account assets.

## Preconditions / where it applies
- You can enumerate target roles (e.g. via [[aws-iam-enum]] or `iam:GetRole` from a partner account).
- The trust policy lists your account, lists `*`, or lists a third-party SaaS pattern you can spoof.
- No `sts:ExternalId` condition, or the ExternalId is leaked/guessable.
- Or: RAM share grants you network adjacency / KMS-decrypt against another account's resources.

## Technique
Enumerate roles and grep their trust documents for cross-account principals:

```bash
aws iam list-roles --query 'Roles[].[RoleName,AssumeRolePolicyDocument]' --output json \
  | jq '.[] | select(.[1].Statement[].Principal.AWS | tostring | test("arn:aws:iam::(?!OWNER_ID)"))'
```

From a controlled account, attempt the cross-account assume:

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::TARGET_ID:role/PartnerIntegration \
  --role-session-name pivot \
  --external-id "$LEAKED_EXTERNAL_ID"
```

Common patterns that work:
1. **Wildcard principal** — `"Principal": {"AWS": "*"}` with no condition. Any account assumes it.
2. **Confused-deputy SaaS roles** — vendor template includes ExternalId but customers paste the example value verbatim.
3. **Org-wide trust** — `aws:PrincipalOrgID` set, but the attacker already has a foothold in the same org.
4. **RAM-shared KMS keys** — consumer account uses the shared key to decrypt producer-owned ciphertext (S3 objects, Secrets Manager).
5. **RAM-shared subnets** — workloads in shared VPC subnets can reach producer-account services and metadata.

Once assumed, chain into [[aws-sts-assume-role]] role hops or look for [[aws-iam-eventual-consistency-persistence]].

## Detection and defence
- CloudTrail `AssumeRole` events with `sourceIPAddress` outside expected ranges or `userIdentity.accountId` not on an allow-list.
- Set `aws:SourceAccount` and `aws:SourceArn` on SaaS integration roles to block confused-deputy.
- Always require a high-entropy `sts:ExternalId` for third-party trust; never the example value.
- Use IAM Access Analyzer external-access findings to inventory cross-account exposure (including RAM shares).
- SCPs to deny role creation with wildcard principals (`aws:PrincipalAccount` deny when outside org).

## References
- [AWS — Cross-account access using IAM roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html) — official mechanics
- [AWS — Confused deputy problem](https://docs.aws.amazon.com/IAM/latest/UserGuide/confused-deputy.html) — ExternalId rationale
- [HackTricks Cloud — AWS IAM privesc](https://cloud.hacktricks.wiki/en/pentesting-cloud/aws-security/aws-privilege-escalation/aws-iam-privesc/index.html) — assume-role chains
