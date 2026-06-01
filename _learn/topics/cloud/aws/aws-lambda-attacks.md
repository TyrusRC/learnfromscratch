---
title: Lambda attacks
slug: aws-lambda-attacks
---

> **TL;DR:** A Lambda function inherits its execution role's credentials from a private metadata endpoint; RCE in the handler, malicious dependency, or write access to function code converts directly to those credentials and any over-broad IAM rights they hold.

## What it is
Each Lambda invocation runs in a microVM that exposes the execution role's STS credentials at `http://169.254.79.129/2018-06-01/runtime/invocation/...` or the `AWS_CONTAINER_CREDENTIALS_FULL_URI` env var, and mirrors them into `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN`. Any code that runs inside the function — handler RCE via injection, malicious npm/PyPI dependency, attacker-supplied layer, or rewritten function code via `UpdateFunctionCode` — can read those creds and use them outside the function for the lifetime of the session.

## Preconditions / where it applies
- Lambda handler with an input-controlled sink (SSRF, command injection, deserialisation) — or you can call `lambda:UpdateFunctionCode`, `lambda:UpdateFunctionConfiguration` (env vars / layers), or `lambda:PublishLayerVersion` + attach.
- Or: dependency-confusion pathway into the function's build.
- Execution role with rights worth stealing (S3, DynamoDB, KMS, STS chains).

## Technique
**Credential exfil from a compromised handler:**

```python
import os, urllib.request, json
print(os.environ["AWS_ACCESS_KEY_ID"], os.environ["AWS_SECRET_ACCESS_KEY"], os.environ["AWS_SESSION_TOKEN"])
# or from the runtime API for the per-invocation creds
```

Exfil to your own endpoint, then use the keys locally — they're valid until the session expires (typically 12h).

**Role takeover via `UpdateFunctionCode`:** if your foothold principal has `lambda:UpdateFunctionCode` on a higher-privileged function, overwrite the zip with a one-liner that POSTs the env to you, then invoke (or wait for a trigger). The next execution runs as the target role.

```bash
zip -j x.zip handler.py
aws lambda update-function-code --function-name target --zip-file fileb://x.zip
aws lambda invoke --function-name target /dev/null
```

**Env-var secret loot:** many teams stuff DB passwords / API keys into `Environment.Variables`. `lambda:GetFunctionConfiguration` returns them in cleartext.

**Layer poisoning:** publish a layer that shadows a common module (e.g. `requests`), attach to a target function, and exfil on import.

Chains: handler RCE → STS creds → [[aws-iam-enum]] → [[aws-sts-assume-role]] hops → [[aws-secrets-manager]] dump.

## Detection and defence
- CloudTrail: alert on `UpdateFunctionCode`, `UpdateFunctionConfiguration`, `PublishLayerVersion` outside CI principals.
- Use Lambda code-signing (Signer) to reject unsigned zips.
- Scope execution roles narrowly — no `*` resource on S3/DynamoDB; one role per function.
- Move secrets from env vars into Secrets Manager / Parameter Store with KMS, fetched at runtime.
- GuardDuty `CredentialAccess:IAMUser/AnomalousBehavior` fires on Lambda role keys used outside Lambda VPC ranges.
- Enable VPC egress controls so a compromised function cannot reach attacker-controlled endpoints.

## References
- [AWS — Lambda execution role](https://docs.aws.amazon.com/lambda/latest/dg/lambda-intro-execution-role.html) — credential delivery model
- [HackTricks Cloud — AWS Lambda privesc](https://cloud.hacktricks.wiki/en/pentesting-cloud/aws-security/aws-services/aws-lambda-enum/index.html) — known privesc paths
- [Rhino Security — Lambda persistence](https://rhinosecuritylabs.com/aws/aws-iam-privilege-escalation-methods/) — UpdateFunctionCode chains
