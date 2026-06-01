---
title: AWS IAM enumeration
slug: aws-iam-enum
---

> **TL;DR:** Map identities, policies, and reachable actions from a stolen key — first with `iam:Get*`/`iam:List*`, then by brute-forcing actual API calls when read perms are denied.

## What it is
After obtaining AWS credentials the first job is to figure out who you are, what you can do, and what the surrounding account looks like. The IAM control plane exposes a dense set of read APIs (`get-caller-identity`, `list-attached-role-policies`, `simulate-principal-policy`) that, when permitted, give a precise picture. When those are blocked, brute-forcing real service calls and watching for `AccessDenied` vs success enumerates the effective permission set without ever touching IAM read APIs.

## Preconditions / where it applies
- Any AWS access key, session token, or instance role you can call STS with.
- Network reachability to AWS endpoints (most engagements: yes; air-gapped VPCs may need a proxy).
- Stealth concern: every `iam:List*` call lands in CloudTrail with your identity attached.

## Technique
1. Establish identity and obvious context.
2. Pull the policy graph if allowed; otherwise pivot to call-based enumeration.
3. Convert to a list of high-value actions (`iam:PassRole`, `sts:AssumeRole`, `lambda:UpdateFunctionCode`, `ssm:SendCommand`, …).

```bash
aws sts get-caller-identity
aws iam get-user                    # for IAM users
aws iam list-attached-user-policies --user-name "$U"
aws iam list-user-policies --user-name "$U"
aws iam get-account-authorization-details > authz.json   # full graph if allowed
```

```bash
# Permission discovery without iam:Simulate*
pacu                                  # whoami; run iam__enum_permissions
enumerate-iam --access-key AKIA... --secret-key ... # cycles calls, marks allowed
aws-iam-enumerator -p profile         # similar, uses ReadOnly-shaped probes
```

```bash
# Targeted: am I allowed to assume any roles in the account?
aws iam list-roles --query 'Roles[].[RoleName,AssumeRolePolicyDocument]' --output json \
  | jq -r '.[] | select(.[1] | tostring | contains("'"$(aws sts get-caller-identity --query Arn --output text)"'"))'
```

## Detection and defence
- CloudTrail rules on bursts of `iam:List*`, `iam:Get*`, or repeated `AccessDenied` from one principal.
- GuardDuty `Recon:IAMUser/*` and `Stealth:IAMUser/CloudTrailLoggingDisabled` findings.
- Apply `aws:RequestedRegion` / `aws:SourceIp` conditions on long-lived keys; rotate or replace with IAM Identity Center short-lived sessions.
- Related: [[aws-instance-metadata]], [[aws-organisations-abuse]], [[aws-cloudtrail-policy-size-evasion]].

## References
- [HackingTheCloud — AWS enumeration](https://hackingthe.cloud/aws/enumeration/) — curated enumeration recipes per service.
- [Pacu](https://github.com/RhinoSecurityLabs/pacu) — modular AWS exploitation framework with `iam__enum_*` modules.
- [enumerate-iam](https://github.com/andresriancho/enumerate-iam) — brute-force allowed actions without touching IAM read APIs.
