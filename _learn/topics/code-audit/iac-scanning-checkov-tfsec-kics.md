---
title: IaC scanning — Checkov, tfsec, KICS, Trivy config
slug: iac-scanning-checkov-tfsec-kics
---

> **TL;DR:** Infrastructure-as-Code scanners statically analyse Terraform, CloudFormation, Kubernetes, Helm, ARM, and Dockerfiles for misconfigurations. Standard layered defence: pre-commit hook (developer feedback) + PR gate (CI block on critical) + nightly drift scan (deployed-state vs scanned-state). Picking the right tool depends on IaC language coverage and noise/depth tradeoffs.

## What it is
Common scanners (2025):

| Tool | Owner | Coverage | Strength |
|---|---|---|---|
| **Checkov** | Prisma Cloud (Palo Alto) | Terraform, CFN, K8s, Helm, ARM, Dockerfile, Bicep, Ansible, Serverless | Broadest coverage, large policy library, custom YAML/Python policies |
| **tfsec** | Aqua Security (merged into Trivy) | Terraform only | Fast, Terraform-deep, AWS-IAM policy emulation |
| **KICS** | Checkmarx | 35+ IaC languages | Broad with strong Kubernetes coverage |
| **Trivy config** | Aqua Security | Terraform, K8s, Helm, Dockerfile, CFN | Bundles with image/SBOM scanning |
| **terrascan** | Tenable | Terraform, K8s, Helm, ARM, Kustomize | Open-policy-agent based, custom Rego |
| **Snyk IaC** | Snyk (commercial) | Terraform, K8s, CFN, ARM | Commercial; dev-focused UX |
| **cnspec / cnquery** | Mondoo | IaC + runtime | Cross-resource queries |

Most orgs adopt Checkov + Trivy as the primary stack; tfsec deprecated but maintained patterns persist in Trivy.

## Preconditions / where it applies
- IaC repos with Terraform / CloudFormation / Helm / k8s manifests / ARM / Bicep
- CI/CD pipeline able to run pre-commit / PR check
- Platform team owning baseline policy
- Optionally: feedback loop from production CSPM findings into IaC scanner policy

## Tradecraft

### Pre-commit hook (developer feedback)

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/bridgecrewio/checkov.git
    rev: '3.2.x'
    hooks:
      - id: checkov
        args: [--quiet, --compact, --skip-check, "CKV_AWS_8"]
  - repo: https://github.com/aquasecurity/trivy
    rev: v0.50.0
    hooks:
      - id: trivy
        args: [config, .]
```

Runs in 5-15s on typical commit; catches obvious findings before push.

### PR gate (block on critical)

```yaml
# .github/workflows/iac-scan.yml
jobs:
  iac-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Checkov on Terraform + K8s + Helm
      - name: Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: .
          framework: terraform,kubernetes,helm,dockerfile
          soft_fail: false       # PR fails on findings
          output_format: sarif
          output_file: checkov.sarif
          skip_check: CKV_AWS_111  # justified suppression
      - uses: github/codeql-action/upload-sarif@v3
        with: {sarif_file: checkov.sarif}

      # Trivy config
      - run: trivy config --severity HIGH,CRITICAL --exit-code 1 .
```

### Nightly drift scan
Compare scanned state (IaC repo) with deployed state (CSPM / cloud config):

```bash
# Terraform: re-scan after `terraform plan`
terraform plan -out plan.tfplan
terraform show -json plan.tfplan > plan.json
checkov -f plan.json --framework terraform_plan
```

Differences between IaC scan results and CSPM findings reveal drift: someone changed cloud state outside IaC.

## Checkov — practitioner detail

```bash
# Scan a directory recursively
checkov --directory ./infra --framework terraform

# Specific frameworks
checkov -d . --framework helm
checkov -d . --framework kubernetes
checkov -d . --framework dockerfile
checkov -f Dockerfile

# Output formats
checkov -d . -o sarif -o cli -o json --output-file-path reports
```

### Custom policies (Python)

```python
# custom_checks/check_s3_logging.py
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
from checkov.common.models.enums import CheckResult, CheckCategories

class S3LoggingEnabled(BaseResourceCheck):
    def __init__(self):
        super().__init__(
            name="Ensure S3 bucket has server access logging enabled",
            id="CKV_CUSTOM_1",
            categories=[CheckCategories.LOGGING],
            supported_resources=['aws_s3_bucket'])

    def scan_resource_conf(self, conf):
        if conf.get('logging'):
            return CheckResult.PASSED
        return CheckResult.FAILED

check = S3LoggingEnabled()
```

```bash
checkov -d . --external-checks-dir ./custom_checks
```

### Custom policies (YAML / no code)

```yaml
metadata:
  name: "S3 bucket must enforce SSL"
  id: "CKV_CUSTOM_2"
  category: "ENCRYPTION"
  severity: "HIGH"
scope:
  provider: "aws"
definition:
  cond_type: "attribute"
  resource_types: ["aws_s3_bucket_policy"]
  attribute: "policy"
  operator: "contains"
  value: "aws:SecureTransport"
```

### Suppression discipline

```hcl
# Suppress one check at a finding level
resource "aws_s3_bucket" "logs" {
  bucket = "logs-bucket"
  # checkov:skip=CKV_AWS_18:Logging bucket doesn't need access logging
}
```

PR review checks that suppressions cite a real reason; without reason → reject.

## Trivy — config + image + secret + license in one

```bash
# IaC scan
trivy config .

# Container scan + config + secret + license
trivy image --scanners vuln,config,secret,license ghcr.io/myorg/app:1.0.0

# Filesystem
trivy fs --scanners vuln,secret /path/to/repo

# Output
trivy config -f sarif -o trivy.sarif .
```

Compact, fast, well-maintained.

## tfsec → Trivy config

tfsec was the Terraform-specific Aqua tool. Aqua merged tfsec into Trivy config. Existing tfsec rules continue to work; new development happens in Trivy.

## Coverage matrix — what each catches

| Misconfig class | Checkov | Trivy | KICS |
|---|---|---|---|
| AWS IAM overly-permissive | ✅ | ✅ | ✅ |
| S3 bucket public ACL | ✅ | ✅ | ✅ |
| K8s privileged Pod | ✅ | ✅ | ✅ |
| Helm chart RBAC review | ✅ | partial | ✅ |
| Dockerfile root user | ✅ | ✅ | ✅ |
| Terraform sensitive output | ✅ | partial | ✅ |
| Cloud-Init user data secrets | ✅ | partial | partial |
| Custom policies | ✅ Python/YAML | ✅ Rego | ✅ Rego |
| Plan-aware (post-resolve) | ✅ | partial | ✅ |

For most orgs Checkov is the breadth play; Trivy fills container + secret scanning in the same workflow.

## Tier policy by environment

Practical defence:
- **Dev/feature branches** — warn on findings, don't block
- **Main / release branches** — block on HIGH/CRITICAL
- **Production deploy gates** — block on MEDIUM+ + manual approval for any exception
- **Drift scan** — quarterly review of suppressed findings to revoke stale exceptions

## Cloud-specific checks beyond IaC scanners

IaC scanners catch what's IN the IaC. Cloud-runtime patterns require:
- **CSPM** for live config (see [[cspm-cnapp-dspm-landscape]])
- **CIEM** for entitlement analysis (see [[ciem-cloud-entitlement-management]])
- **Runtime EDR** for behavioural detection

IaC scan is necessary but not sufficient.

## Common implementation pitfalls

- **"All findings = block"** — noisy, developers disable scanner. Tier by severity + suppression workflow
- **No baseline pass** — first scan on legacy repo returns 500 findings; treat with snapshot baseline (pass current state, block new findings only)
- **Multiple scanners with overlapping findings** — duplicate noise; pick primary, use second for differentiated coverage
- **Skipping plan-resolved scan** — variable values resolved at plan time matter; scan source AND plan
- **Custom policies copy-pasted** — when not reviewed, become noise; maintain custom policies as code with tests
- **Forgot to scan generated YAML** — Helm/Kustomize/etc render to YAML pre-apply; scan the rendered output, not just the chart

## OPSEC for blue team

- Track suppression ratio per repo — high suppression = scanner noise OR systematic risk acceptance worth reviewing
- Centralise policy in a shared "platform" repo; consume into individual repos
- Score repo IaC health: % checks passing, % critical findings, % suppressed
- Feed IaC scanner findings into CSPM for cross-reference

## References
- [Checkov](https://www.checkov.io/) — scanner + custom policies
- [Trivy config](https://trivy.dev/) — Aqua's IaC + container scanner
- [KICS](https://kics.io/) — Checkmarx multi-IaC scanner
- [tfsec docs (archived)](https://aquasecurity.github.io/tfsec/) — migration to Trivy
- [terrascan](https://runterrascan.io/) — Tenable's OPA-based scanner
- [OWASP IaC Security Top 10](https://owasp.org/www-project-infrastructure-as-code-security/) — taxonomy

See also: [[terraform-and-iac-source-audit]], [[k8s-manifest-source-audit]], [[helm-chart-security-audit]], [[sast-dast-ci-integration]], [[semgrep-custom-rule-development]], [[cspm-cnapp-dspm-landscape]], [[ciem-cloud-entitlement-management]], [[policy-as-code-opa-kyverno-defender]], [[devsecops-platform-engineering]], [[paved-road-pattern-platform]]
