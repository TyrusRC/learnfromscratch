---
title: AWS Organisations abuse
slug: aws-organisations-abuse
---

> **TL;DR:** From the management account or a delegated admin you can pivot into every member account via `OrganizationAccountAccessRole`, weaken SCPs, and pin service-side trust into your own account.

## What it is
AWS Organizations centralises billing and policy across many accounts. The management account holds an implicit god role: any account created through Organizations gets an `OrganizationAccountAccessRole` whose trust policy allows the org root to `AssumeRole` with no MFA. Service Control Policies (SCPs) bound to OUs cap the effective permissions of all principals beneath, but leave the management account itself untouched and can be edited from there. Delegated administrator features (for GuardDuty, Config, IAM Identity Center, etc.) expand the blast radius beyond just the management account.

## Preconditions / where it applies
- Compromise of the org management account or a principal trusted by an OU admin.
- Or: compromise of a delegated administrator for a service that grants cross-account read/write (Identity Center, Security Hub, Config).
- Knowledge of member account IDs (visible via `organizations:ListAccounts`).

## Technique
1. Enumerate the org tree and SCPs.
2. Assume into a member account via the default cross-account role.
3. Modify SCPs, attach malicious permissions, or create a new delegated administrator that you control.

```bash
aws organizations describe-organization
aws organizations list-accounts --query 'Accounts[].[Id,Name,Status]' --output table
aws organizations list-policies --filter SERVICE_CONTROL_POLICY
aws organizations list-targets-for-policy --policy-id p-xxxxx
```

```bash
# Jump to a member account
aws sts assume-role \
  --role-arn arn:aws:iam::111122223333:role/OrganizationAccountAccessRole \
  --role-session-name pivot
```

```bash
# Weaken / remove an SCP from an OU
aws organizations detach-policy --policy-id p-allowlist --target-id ou-xxxx-yyyy
# Or attach a permissive one
aws organizations create-policy --name allow-all --type SERVICE_CONTROL_POLICY \
  --content '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}'
```

Backdoor avenues that survive cred rotation: register your own account as `DelegatedAdministrator` for IAM Identity Center, then mint permission sets across the whole org; or create a member-account role whose trust policy points to your external account.

## Detection and defence
- CloudTrail in the management account: alert on `organizations:DetachPolicy`, `RegisterDelegatedAdministrator`, `CreatePolicy`, and `AssumeRole` into `OrganizationAccountAccessRole`.
- Rename or delete the default access role and replace it with a least-privilege, MFA-gated equivalent.
- Lock management account access behind hardware MFA, isolate from day-to-day workloads.
- Related: [[aws-iam-enum]], [[aws-sso-device-code-phishing]].

## References
- [HackingTheCloud — AWS Organizations](https://hackingthe.cloud/aws/post_exploitation/cross_account_enumeration/) — cross-account pivot recipes.
- [AWS — Managing the OrganizationAccountAccessRole](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_access.html) — canonical doc on the default cross-account role and its trust policy.
