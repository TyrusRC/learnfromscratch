---
title: Cloud asset recon
slug: cloud-asset-recon
---

> **TL;DR:** Permute cloud storage bucket names from brand and product names, pivot CDN-fronted hostnames to origin servers, and crawl cloud-provider IP ranges for HTTPS SAN names. Cloud surfaces sit just outside the apex DNS view and often outside the asset inventory.

## What it is
Targets push static assets into S3 / GCS / Azure Blob, host APIs on Lambda / Functions / Cloud Run, and front everything with CloudFront / Akamai / Cloudflare. Each of these surfaces leaks identifying information — bucket names, function URLs, certificate SANs, IP-range ownership — that DNS-only recon misses.

## Preconditions / where it applies
- Scope language includes "cloud assets owned by the company" or wildcards on apex domains; pure-host scopes exclude bucket-only finds
- Target uses public cloud (almost always true today)
- You have lists of brand names, internal product codenames (often visible in [[js-recon]]), and acquired entity names ([[acquisitions-recon]])

## Technique
1. Bucket permutation. Generate candidates from a seed list of brand tokens; check existence per provider:

```
# AWS S3 — HEAD on the virtual-host URL
curl -sI https://example-backup.s3.amazonaws.com/ | head -1

# GCS
curl -sI https://storage.googleapis.com/example-backup/
```

Tools: `cloud_enum`, `s3scanner`, `gobuster` with the s3 mode, `kiterunner`. Seed wordlists with `-dev`, `-prod`, `-staging`, `-backup`, `-uploads`, `-assets`, brand codenames.
2. Cert-SAN sweep on cloud provider IP ranges. AWS publishes `ip-ranges.json`, GCP publishes `cloud.json`, Azure has weekly JSON downloads. For high-value regions, mass-fetch certs on 443 and grep SANs for target brand strings.
3. CDN origin pivot. CloudFront / Akamai hostnames look generic (`d111111abcdef8.cloudfront.net`); the origin is often a same-name S3 bucket or an unprotected ALB. Look for:
   - `Server: AmazonS3` on CDN responses → origin is S3, name often derivable
   - Errors that leak origin: `x-amz-bucket-region`, S3 XML error bodies
   - Heuristic origin search by analytics-tag / favicon hash on Shodan / Censys (see [[analytics-tag-correlation]])
4. Function URLs. Lambda `*.lambda-url.<region>.on.aws`, Cloud Run `*.run.app`, Azure Functions `*.azurewebsites.net`. These rarely appear in DNS but can be discovered via [[github-recon]] and [[js-endpoint-extraction]].
5. Cloud IAM principal recon. Public buckets often allow `s3:GetBucketAcl` anonymously, revealing the canonical user ID and sometimes account ID. AWS account IDs are pivotable — `aws sts get-caller-identity-pivot` style attacks.

```
aws s3api get-bucket-acl --bucket example-backup --no-sign-request
```

## Detection and defence
- AWS GuardDuty and CloudTrail flag anonymous bucket access and enumeration patterns; tune alerting on `BucketAnonymousAccessGranted` and bursts of `ListBuckets` 4xx errors
- Block public S3 at the account level (`s3:BlockPublicAccess`) and use AWS Config rules to detect drift
- Never name buckets after your brand+environment — use random suffixes so permutation lists don't hit
- Front everything with a deny-by-default origin policy; CloudFront → S3 should require an Origin Access Identity, not direct public access

## References
- [hackingthe.cloud — AWS recon](https://hackingthe.cloud/aws/general-knowledge/aws-account-enumeration/) — account-ID and bucket recon
- [HackTricks Cloud — Pentesting cloud methodology](https://cloud.hacktricks.wiki/en/pentesting-cloud/pentesting-cloud-methodology.html) — multi-provider workflow
- [cloud_enum on GitHub](https://github.com/initstring/cloud_enum) — multi-cloud bucket / app permutation
