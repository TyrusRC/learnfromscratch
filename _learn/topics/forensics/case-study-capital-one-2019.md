---
title: Case study — Capital One 2019 (SSRF → EC2 metadata)
slug: case-study-capital-one-2019
aliases: [capital-one-breach, capital-one-2019, paige-thompson]
---

> **TL;DR:** In 2019 a former AWS employee exploited a misconfigured WAF (ModSecurity on an EC2 instance) at Capital One to perform SSRF against AWS Instance Metadata Service v1, retrieved temporary credentials for an IAM role attached to the WAF instance, and used those credentials to enumerate and download 30+ S3 buckets containing 100M+ customer records. Defining incident for the SSRF-to-IMDSv1 class — directly led to AWS shipping IMDSv2. Companion to [[aws-imds-ssrf-pivot]] and [[ssrf-to-cloud]].

## Why this matters

- **Largest US financial-services breach by record count** at the time (later surpassed but still pivotal).
- The technical primitive — **SSRF into IMDSv1** — is generalisable to any cloud SSRF. The Capital One breach showed the real-world impact at scale.
- AWS's response (IMDSv2) is a direct security-product change attributable to this incident.
- The attacker, Paige Thompson (alias "erratic"), was a former AWS engineer with insider knowledge of metadata patterns. Insider-adjacent threat.

## The chain

### Step 1 — SSRF in a WAF

Capital One ran a ModSecurity WAF on EC2. The WAF was misconfigured such that requests sent to specific endpoints were proxied with user-controlled targets — a server-side request forgery primitive ([[ssrf]]).

The WAF was reachable from the public internet.

### Step 2 — Hit IMDSv1

EC2 Instance Metadata Service v1 is reachable from inside the instance at `169.254.169.254`. Any process on the instance can `curl` it; no auth, no tokens, no headers.

The attacker's SSRF target: `http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>`.

### Step 3 — Steal IAM role credentials

The WAF instance had an IAM role attached for legitimate operational reasons (logging, monitoring). The metadata endpoint returned temporary STS credentials (access key + secret + session token).

The role had broader permissions than necessary — including `s3:ListBucket`, `s3:GetObject` on Capital One's data buckets.

### Step 4 — Enumerate and download S3

The attacker used the stolen credentials with normal AWS APIs to:
- List buckets the role could see.
- Sync entire bucket contents to attacker storage.

This wasn't a particularly sophisticated step — standard `aws s3 sync`.

### Step 5 — Public boasting

The attacker posted screenshots on GitHub and Slack channels mentioning Capital One data. A community member alerted Capital One, who triggered the breach disclosure within days.

## What was exposed

- ~100M US individuals + ~6M Canadians.
- SSNs (~140k), bank-account numbers (~80k), credit-card application data, names, addresses, income.
- The S3 buckets were intended for credit-application data and had inadequate IAM scoping.

## What changed at AWS

### IMDSv2 (introduced post-incident)

IMDSv2 requires a **PUT** request to obtain a session token, then GET requests with the token:

```
PUT http://169.254.169.254/latest/api/token  (with TTL header)
→ returns session token
GET http://169.254.169.254/latest/meta-data/...  (with X-aws-ec2-metadata-token header)
```

SSRF that only supports GET (the common case) **cannot** call PUT → cannot obtain a token → cannot read metadata.

IMDSv2 also:
- Caps token TTL.
- Returns metadata only with the IP TTL of 1 by default (block multi-hop).
- Logged in CloudTrail (visibility into unusual metadata access).

AWS later announced IMDSv1 deprecation timeline. Many cloud services now require IMDSv2.

### Other AWS hardening

- **GuardDuty** added detections for credentials exfil and IMDS-pattern signals.
- **IAM Access Analyzer** to flag over-permissive policies.
- **S3 Block Public Access** account-wide setting.
- **VPC SC**-like primitives for cross-account / cross-region restrictions.

## What changed at Capital One

- WAF rebuilt with stricter SSRF protections.
- IAM roles reduced to minimum privilege.
- S3 bucket policies tightened.
- Network segmentation between WAF tier and data tier increased.
- Specific configuration changes published in incident analyses.

## What this teaches

- **SSRF + cloud metadata** is the single highest-impact web-app vulnerability class in cloud-native environments. See [[aws-imds-ssrf-pivot]], [[gcp-metadata-token-theft]].
- **IAM roles attached to internet-facing tier** should be **minimum privilege**. WAF doesn't need data-bucket access.
- **Insider-adjacent threat** is real — former employees know architecture quirks.
- **Default-deny S3** policies prevent over-share even when IAM is too broad.
- **Network segmentation** between presentation tier and data tier survives IAM mistakes.

## Detection lessons

After the fact, indicators existed:
- Unusual S3 list / get activity from the WAF instance's role.
- Volume of outbound to non-Capital One IPs.
- The role accessed buckets it had never accessed before.

CloudTrail volume anomaly + role-access-pattern anomaly + S3 access volume — three correlated signals that good baselining would have caught.

Modern detection should alert on:
- IAM role making S3 calls from an unexpected source.
- High-volume S3 get / list by a role that previously did neither.
- IMDSv1 token requests after IMDSv2 enforcement (sign of compatibility gap).

## How to teach the chain

For training, reproduce in a lab:
1. EC2 instance with a role granting S3 read on a test bucket.
2. SSRF endpoint on the instance.
3. Exploit SSRF to read IMDSv1.
4. Use stolen credentials to enumerate S3.
5. Enable IMDSv2; observe attack failing.
6. Tighten IAM; observe attack producing nothing useful.

## Related cases

- **Tesla Kubernetes cryptojacking 2018** — similar but used Kubernetes dashboard rather than SSRF; IAM role over-permissioned.
- **MOVEit 2023** — see [[case-study-moveit-2023]] — different vector, similar impact pattern.
- **Snowflake 2024** — see [[case-study-snowflake-2024]] — different vector, similar "missing control" theme.

## References
- [Capital One incident response statement](https://www.capitalone.com/digital/facts2019/)
- [Krebs on Security — Capital One breach](https://krebsonsecurity.com/2019/07/capital-one-data-theft-impacts-106m-people/)
- [Amazon — IMDSv2 announcement](https://aws.amazon.com/blogs/security/defense-in-depth-open-firewalls-reverse-proxies-ssrf-vulnerabilities-ec2-instance-metadata-service/)
- [US DoJ indictment](https://www.justice.gov/usao-wdwa/press-release/file/1188626/dl)
- See also: [[ssrf]], [[ssrf-to-cloud]], [[aws-imds-ssrf-pivot]], [[cloud-ir-aws-cloudtrail]]
