---
title: Terraform and IaC — source audit
slug: terraform-and-iac-source-audit
aliases: [terraform-audit, iac-source-audit]
---

{% raw %}

> **TL;DR:** Terraform (and CloudFormation, Bicep, Pulumi) declarations *are* your cloud security boundary. Audit risks: overly broad IAM policies, secrets in state, modules from untrusted sources, `count` / `for_each` blowups, plain-HTTP buckets, public ingress on management ports, and provider versions pinned mutably. The state file is often the highest-value secret in the entire codebase. Companion to [[terraform-state-extraction]] and [[github-actions-workflow-source-audit]].

## Inputs to audit

```bash
find . -name '*.tf' -o -name '*.tfvars' -o -name 'terragrunt.hcl'
find . -name 'cloudformation*.yml' -o -name 'cloudformation*.yaml' -o -name '*.cfn.yaml'
find . -name 'main.bicep' -o -name '*.bicep'
find . -name 'Pulumi.yaml' -o -name '*.ts' -path '*/pulumi/*'
```

## Bug class 1 — wildcards in IAM

```hcl
# BAD
resource "aws_iam_policy" "dev_full" {
  policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Action = "*"            # ← any action
      Resource = "*"           # ← any resource
    }]
  })
}
```

Grep:
```bash
grep -rnE '"Action"\s*:\s*"\*"' .
grep -rnE '"Resource"\s*:\s*"\*"' .
grep -rnE '"Principal"\s*:\s*"\*"' .   # publicly assumable role
grep -rnE 'NotAction|NotResource'       # negation = effectively wide
```

Quick mental model:
- `Action: "s3:*"` — bad on a write-capable role; OK on a read-only role limited to one bucket.
- `Resource: "*"` — bad on anything outside management/audit roles.
- `Principal: "*"` — public; only on truly public resources (CloudFront, etc.).

## Bug class 2 — assume-role trust too loose

```hcl
# BAD
resource "aws_iam_role" "ci" {
  assume_role_policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }    # any EC2 in the account
    }]
  })
}
```

For GitHub OIDC trust ([[gha-oidc-sub-claim-wildcards]]):
```hcl
# BAD
Condition = {
  StringLike = {
    "token.actions.githubusercontent.com:sub" = "repo:my-org/*:*"
  }
}

# GOOD
StringEquals = {
  "token.actions.githubusercontent.com:sub" = "repo:my-org/my-repo:ref:refs/heads/main"
}
```

## Bug class 3 — secrets in state

Terraform state stores resource arguments verbatim — including passwords, API keys, private keys.

```hcl
resource "aws_db_instance" "db" {
  password = var.db_password     # this value ends up in state, plaintext
}
```

State file is therefore equivalent to the full secret inventory. Audit:
- Where is state stored? S3 with SSE? KMS-encrypted? Versioning?
- Who can read state? `aws_s3_bucket_policy` on the state bucket.
- Is state behind `aws_dynamodb_table` for locking? (DoS surface if not.)

Greppable:
```bash
grep -rnE 'password\s*=|secret\s*=|api_key\s*=|private_key\s*=' .
grep -rn 'backend\s*"s3"' .
```

For any secret in state: use AWS Secrets Manager / Parameter Store reference instead, or ephemeral resources with `sensitive = true` + provider-side fetch.

## Bug class 4 — secrets in `*.tfvars`

```hcl
# secrets.tfvars
db_password = "Hunter2-Production"
```

Greppable:
```bash
grep -rn '\.tfvars$' .
grep -rn 'password\s*=' *.tfvars 2>/dev/null
```

`.tfvars` files often end up committed to git. Search `git log -p -- '*.tfvars'`.

## Bug class 5 — third-party modules from untrusted sources

```hcl
module "vpc" {
  source = "github.com/some-author/terraform-aws-vpc"     # no version pin
}
```

Without a `?ref=` pinning to commit SHA or signed tag, the module can be swapped under you.

Fix:
```hcl
module "vpc" {
  source = "git::https://github.com/some-author/terraform-aws-vpc.git?ref=a1b2c3d4..."
}
```

For Terraform Registry modules: `version = "1.2.3"` with `tfsec`/`checkov` policy that enforces "no `~>` constraints on third-party modules".

## Bug class 6 — public ingress on management

```hcl
resource "aws_security_group_rule" "ssh" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]            # BAD: SSH from the world
}
```

Grep:
```bash
grep -rnB2 -A4 '0\.0\.0\.0/0' .
grep -rnB2 -A4 '::/0' .            # IPv6 any
```

For any `0.0.0.0/0` ingress: confirm it's on a public load-balancer port (80/443) only. SSH, RDP, DB ports, admin UIs — never.

## Bug class 7 — bucket / queue without encryption

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "my-data"
  # no server_side_encryption_configuration → SSE off
}
```

Modern AWS defaults SSE-S3 since 2023, but legacy IaC may still need explicit blocks. Audit:
```bash
grep -rn 'aws_s3_bucket' . | head
grep -rn 'server_side_encryption' .
grep -rn 'kms_key_id' .
```

Same for `aws_sqs_queue`, `aws_sns_topic`, `aws_rds_cluster` (`storage_encrypted`).

## Bug class 8 — public S3 buckets

```hcl
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = false   # BAD
  block_public_policy     = false   # BAD
  ignore_public_acls      = false   # BAD
  restrict_public_buckets = false   # BAD
}
```

These should all be `true` for non-public buckets. For genuinely public buckets (static site, CDN origin), the policy itself is more important than the block.

## Bug class 9 — `count` / `for_each` blowups

```hcl
resource "aws_instance" "fleet" {
  count = var.instance_count       # passed via tfvars
  ...
}
```

A misconfigured CI passing `instance_count = 10000` provisions a fleet of bills overnight. Bound:
```hcl
variable "instance_count" {
  type = number
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 50
    error_message = "instance_count must be 1-50"
  }
}
```

## Bug class 10 — Lambda / function code from URL

```hcl
resource "aws_lambda_function" "handler" {
  s3_bucket = "vendor-distribution"     # third-party
  s3_key    = "handler.zip"             # mutable
  ...
}
```

If the bucket is third-party-owned, you trust their object versioning to not be tampered with. Pin by `s3_object_version`, or build the zip in your own repo.

## Bug class 11 — provider version unpinned

```hcl
terraform {
  required_providers {
    aws = "~> 5"      # ranges accept new minor versions
  }
}
```

Lockfile (`.terraform.lock.hcl`) freezes versions for *your* runs but not for new contributors. Audit:
- `.terraform.lock.hcl` is committed.
- CI re-runs `terraform init -upgrade` only on explicit version bumps.

## Bug class 12 — KMS key policy

```hcl
resource "aws_kms_key" "data" {
  policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}
```

KMS keys are particularly dangerous to leave permissive. The `kms:*` action allows decryption of *anything* encrypted under that key by *anyone* who can call the API.

## CloudFormation parallels

Same patterns, different YAML:
- `!Sub` interpolation injection.
- `Fn::Sub` with attacker-controlled values.
- IAM PolicyDocument wildcards.
- `Capabilities: CAPABILITY_AUTO_EXPAND` for nested stacks — confirm the nested templates are trusted.

## Tools

- **tfsec / tflint** — Terraform-specific security linters.
- **checkov** — multi-format (TF + CFN + K8s + Helm + Dockerfile).
- **terrascan** — multi-format.
- **kics** — multi-format, OWASP-aligned.
- **OPA / Conftest** — policy-as-code with rego against parsed plans.

Use in CI to block on critical findings.

## Source-audit checklist

- [ ] No `*` in IAM `Action` / `Resource` / `Principal` outside well-justified roles.
- [ ] OIDC trust policies pin `sub` claim tightly.
- [ ] No secrets in `.tf` or `.tfvars`.
- [ ] State backend is encrypted, access-controlled, locked.
- [ ] Third-party modules pinned to commit SHA / signed version.
- [ ] No `0.0.0.0/0` on management ports.
- [ ] SSE/KMS on data resources.
- [ ] `aws_s3_bucket_public_access_block` defaults to true.
- [ ] `count` / `for_each` driven by validated variables.
- [ ] Provider versions locked.
- [ ] KMS key policies scoped.

## References
- [Terraform security best practices — HashiCorp](https://developer.hashicorp.com/terraform/cloud-docs/architectural-details/security-model)
- [tfsec](https://aquasecurity.github.io/tfsec/)
- [checkov](https://www.checkov.io/)
- [AWS — IAM least privilege](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- See also: [[terraform-state-extraction]], [[github-actions-workflow-source-audit]], [[k8s-manifest-source-audit]], [[cloud-iam-misconfig-patterns]]

{% endraw %}
