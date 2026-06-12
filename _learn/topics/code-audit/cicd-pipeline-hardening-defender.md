---
title: CI/CD pipeline hardening — defender playbook
slug: cicd-pipeline-hardening-defender
---

> **TL;DR:** CI/CD pipelines have become the most attractive target post-SolarWinds, Codecov, 3CX, tj-actions (March 2025). Defender goal: short-lived credentials only, least-privilege runners, immutable build environment, signed provenance, gating policy on every push, no human secrets in workflow files. This is the platform team's responsibility, not individual developers'.

## What it is
CI/CD pipeline = highest-privilege, lowest-supervision system in most orgs. It holds:
- Source code read/write
- Container registry push
- Production deployment access
- Cloud IAM credentials
- Long-lived secrets (frequently)

Compromise it once, deliver malware to every customer. Defender model: **assume a compromised contributor's PR could reach prod unless gates prevent it**.

## Preconditions / where it applies
- GitHub Actions, GitLab CI, Jenkins, Buildkite, CircleCI, Tekton, Argo Workflows
- Mature enough team to invest weeks in baseline hardening
- Existing secret store (Vault, AWS Secrets, GCP Secret Manager, Azure Key Vault)

## Threat model (the real attacks of 2022-2025)

| Incident | Attack | Defense that would have stopped it |
|---|---|---|
| SolarWinds (2020) | Trojaned build process injects backdoor | SLSA L3, reproducible builds, code signing |
| Codecov (2021) | Bash uploader compromised, leaked secrets | Pin actions by SHA, short-lived OIDC tokens |
| Argo CD CVE-2022-24348 | Path traversal → cluster compromise | Patch + network isolation + RBAC |
| PyTorch nightly (2022) | Dependency confusion via pip index priority | Internal index priority, namespace registration |
| GitHub Action tj-actions/changed-files (Mar 2025) | Tag mutation → injected payload | Pin actions by commit SHA, not tag |
| 3CX (2023) | Build server malware in dev's PC | Ephemeral runners, no developer-laptop builds |
| CircleCI (2022) | Engineer laptop malware → CircleCI session token | Short-lived tokens, MFA, anti-malware on dev endpoints |

## Hardening playbook

### 1. Pin every action by commit SHA, never by tag

```yaml
# BAD — mutable tag, vulnerable to tj-actions-style attacks
- uses: actions/checkout@v4

# GOOD — pinned commit SHA
- uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab  # v4.1.1
```

Automation: `dependabot` configured for `package-ecosystem: github-actions` auto-updates SHA pins with PR reviews. See [[tj-actions-tag-mutation]].

### 2. OIDC for cloud auth, NOT long-lived secrets

GitHub Actions / GitLab CI / Buildkite all support OIDC. Cloud providers trust the OIDC issuer + verify claims (repo, branch, environment).

```yaml
# GitHub Actions → AWS
permissions:
  id-token: write
  contents: read
steps:
  - uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502  # v4.0.2
    with:
      role-to-assume: arn:aws:iam::123:role/github-actions-deploy
      aws-region: us-east-1
      # no aws-access-key-id, no aws-secret-access-key
```

AWS trust policy validates GitHub OIDC claims:

```json
{
  "Effect": "Allow",
  "Principal": {"Federated": "arn:aws:iam::123:oidc-provider/token.actions.githubusercontent.com"},
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:myorg/myapp:ref:refs/heads/main"
    }
  }
}
```

Critical: the `sub` claim filter must be specific. See [[gha-oidc-sub-claim-wildcards]] for the wildcard attack.

### 3. Ephemeral, isolated runners

| Runner type | Isolation | Compromise blast radius |
|---|---|---|
| GitHub-hosted runner | Fresh VM per job | Single job |
| Self-hosted persistent | Shared host | Every workflow on that host |
| Self-hosted ephemeral (k8s job, ARC) | Fresh pod per job | Single job |
| Self-hosted persistent without ephemeral | DON'T |

Use GitHub Actions Runner Controller (ARC) on Kubernetes for self-hosted runners with k8s-managed lifecycle.

### 4. Least-privilege workflow permissions

```yaml
# Top-level — applies to every job unless overridden
permissions: read-all   # default-deny write everywhere

jobs:
  build:
    permissions:
      contents: read     # explicit
      id-token: write    # needed for OIDC
      packages: write    # needed for container registry push
```

`GITHUB_TOKEN` defaults can be tightened at org level: Settings → Actions → Workflow permissions → "Read repository contents and packages permissions" + "Allow GitHub Actions to create and approve pull requests" off.

### 5. Restrict allowed actions

Org-level allowlist:
- Allow only actions from selected orgs (e.g., `actions/*`, `myorg/*`, `aws-actions/*`)
- Block `marketplace` actions by default
- Curated set reviewed periodically

This stops `uses: random-attacker/install-malware@main` cold.

### 6. Branch protection
- Required PR review (≥1, ideally 2)
- Required status checks (CI must pass)
- Signed commits required for `main` and release branches
- No force push
- CODEOWNERS for `.github/workflows/**` (workflow file changes require security review)
- Linear history (no merge commits, no rebases hiding history)

### 7. Workflow-file change review
Workflow file changes are the highest-impact PR class. CODEOWNERS:

```
.github/workflows/* @myorg/platform-security
.github/workflows/release.yml @myorg/security-leads
```

Combine with branch protection requiring CODEOWNER review.

### 8. Secret management
- Secrets in Vault / AWS Secrets / cloud secret manager — never in repo, never in workflow files
- Use OIDC + IAM where possible (no secrets)
- Per-environment Environments (GitHub) gating; require manual approval for prod
- Rotate secrets quarterly; audit access logs
- Mask secrets in logs (CI providers do this automatically; verify)

### 9. Provenance and signing
- SLSA Level 3 builder workflows for release artifacts ([[slsa-supply-chain-framework]])
- Cosign keyless signing of every published container ([[sigstore-cosign-supply-chain-signing]])
- SBOM attestation per release ([[sbom-and-software-supply-chain-attestation]])
- Verification enforced at admission ([[policy-as-code-opa-kyverno-defender]])

### 10. Dependency hygiene
- Dependabot / Renovate keeping dependencies + actions current
- `npm ci` / `pip install --require-hashes` for lockfile enforcement
- Allowlist internal package index priority over public (prevents dependency confusion)
- Verify package signatures where supported (npm, PyPI Sigstore integration)
- See [[npm-postinstall-and-typosquat-audit]]

### 11. Build-time secret scanning
- TruffleHog / Gitleaks / Semgrep secrets in pre-commit
- Push-protection (GitHub Advanced Security) for secret scanning before commit lands
- For caught leaks: rotate immediately, don't just delete the commit

### 12. Logging and audit
- CI provider audit logs → SIEM (GitHub Audit Log → Splunk, Sentinel, etc.)
- Alert on:
  - New workflow file modified outside change window
  - OIDC role assumption from unexpected workflow path
  - PAT / SSH key created
  - Self-hosted runner registered
  - Repo visibility changed (private → public)

### 13. Self-hosted runner specifics

If you must run self-hosted runners:
- Ephemeral mode (`--ephemeral` flag) — runner exits after one job
- Network policy: outbound only to required hosts
- No long-lived AWS / GCP credentials on runner host — use OIDC
- Runner image scanned + signed; refresh image weekly
- Don't run runners on developer laptops, ever

### 14. Forks and pull_request_target
GitHub's `pull_request` from a fork has NO access to secrets — safe by default. BUT `pull_request_target` runs on the base repo with full secret access, even for fork PRs. This is the #1 GitHub Actions self-pwn vector.

```yaml
on:
  pull_request_target:    # DANGEROUS — runs with main branch's permissions on fork code
    types: [opened, synchronize]
jobs:
  test:
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}  # attacker-controlled
      - run: npm test    # arbitrary attacker code with secrets in env
```

Rule: NEVER check out untrusted code in `pull_request_target` workflows. Use it only for permission grants, label management, or safe metadata operations.

### 15. PAT and SSH key hygiene
- Personal Access Tokens: minimal scope, expiration set, audited quarterly
- Fine-grained PATs preferred over classic
- Bot accounts for CI access have separate emails; humans NEVER share PATs
- Deploy keys: read-only when possible; per-repo, not org-wide

## Defense-in-depth view

| Layer | Tool | What it catches |
|---|---|---|
| Source | Branch protection, CODEOWNERS | Unauthorized merges |
| Pre-commit | Gitleaks, Semgrep, talisman | Secrets, obvious bugs |
| PR | SAST (CodeQL, Semgrep), IaC scan, dep scan | Misconfig, vulnerable deps |
| Build | SLSA generator, reproducible builds | Tampered build |
| Sign | Cosign + Rekor | Identity assurance |
| Publish | Internal registry with verification | Untrusted artifacts blocked |
| Deploy | GitOps + admission policy | Unsigned / non-compliant blocked |
| Runtime | EDR / eBPF / Falco | Behavioral anomalies |

Each layer catches different attack patterns. None is sufficient alone.

## Common implementation pitfalls

- **OIDC trust policy with wildcard `sub`** — every repo in your org can assume the role; see [[gha-oidc-sub-claim-wildcards]]
- **PAT in env var, not secret** — leaked in log
- **Self-hosted runner with cluster-admin IAM role** — runner compromise = cloud admin
- **Reusable workflows from unpinned source** — same SHA-pinning rule applies
- **`pull_request_target` running fork code** — secret-leak attack vector
- **No env-level approval for prod deploys** — any approved PR auto-deploys, no last-stop human gate

## OPSEC for blue team

- Track CI/CD audit events as Tier-0 alerts
- Quarterly review: every workflow's permissions, every PAT, every OIDC trust policy
- Tabletop: "an attacker compromises a maintainer's GitHub account; can they reach prod?"
- Red-team your own CI/CD periodically; this is the highest-value attack path
- Pair with [[ci-cd-as-cloud-attack-surface]] for adversary perspective

## References
- [GitHub Actions security hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [GitLab CI/CD security guidelines](https://docs.gitlab.com/ee/ci/secure/)
- [Datadog Security Labs — CI/CD attack research](https://securitylabs.datadoghq.com/)
- [Step Security — Action SHA-pinning](https://www.stepsecurity.io/)
- [OWASP CI/CD Top 10](https://owasp.org/www-project-top-10-ci-cd-security-risks/)
- [Chainguard — CI/CD threat model series](https://www.chainguard.dev/unchained)
- [SLSA framework](https://slsa.dev/)

See also: [[ci-cd-as-cloud-attack-surface]], [[gha-oidc-sub-claim-wildcards]], [[tj-actions-tag-mutation]], [[github-actions-workflow-source-audit]], [[gitlab-ci-attacks]], [[jenkins-attacks]], [[sigstore-cosign-supply-chain-signing]], [[slsa-supply-chain-framework]], [[sbom-and-software-supply-chain-attestation]], [[ghost-commit-smuggling]], [[npm-postinstall-and-typosquat-audit]], [[devsecops-platform-engineering]], [[paved-road-pattern-platform]]
