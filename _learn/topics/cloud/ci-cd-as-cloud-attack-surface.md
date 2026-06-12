---
title: CI/CD as cloud surface
slug: ci-cd-as-cloud-attack-surface
---

> **TL;DR:** Pipelines (GitHub Actions, GitLab CI, CircleCI, Jenkins) hold first-class cloud credentials via OIDC federation or long-lived tokens — compromising a workflow file, a referenced action, or a runner gets you the role those pipelines assume.

## What it is
Modern build systems no longer ship static cloud keys; they mint short-lived credentials by federating the runner's identity (an OIDC JWT) to an AWS/Azure/GCP trust policy. The pipeline itself is therefore a privileged principal. Anything that can write to `.github/workflows/`, mutate a reusable workflow, alter a build script, or land code on a self-hosted runner can issue those credentials and pivot into the cloud control plane.

## Preconditions / where it applies
- Repo with cloud-deploy workflows (Terraform, ECS/EKS deploy, Lambda push, ARM/Bicep, gcloud).
- PRs from forks allowed to trigger `pull_request_target`, or push-on-tag workflows triggered by tag mutation.
- Trust policy with sloppy `sub` claim (see [[gha-oidc-sub-claim-wildcards]]) or long-lived `AWS_*`/`GOOGLE_*` repo secrets.
- Self-hosted runners reused across jobs (token bleed-through on disk and env).

## Technique
1. **Map the trust** — read `.github/workflows/*.yml` for `permissions: id-token: write` and `aws-actions/configure-aws-credentials@v*` invocations. Note the role ARN, audience, and the repo/branch the action runs on.
2. **Find a write primitive**: a PR you can land, a third-party action pinned by tag (mutable), a script in a dependency, or a self-hosted runner left labelled on the public internet.
3. **Exfil the OIDC token** during a job and trade it for cloud creds out-of-band, or echo the resulting STS keys masked-but-recoverable (`base64`, `sed s/./& /g`):

```yaml
- run: |
    curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
      "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com" \
      | jq -r .value | base64 -w0
```

4. **From cloud creds**, enumerate (`aws sts get-caller-identity`, `aws iam list-attached-role-policies`) and pivot per the [[cloud-iam-misconfig-patterns]] playbook.
5. **Self-hosted runner pivot**: if the runner is a long-lived VM, drop persistence in `~/.bashrc` or `_work/_temp/` so subsequent jobs leak their tokens to you.

## Detection and defence
- Pin third-party actions by commit SHA, not tag (see [[tj-actions-tag-mutation]] for why).
- Make trust policy `sub` strings exact: `repo:org/repo:ref:refs/heads/main`, never `repo:org/*`.
- Reject `pull_request_target` workflows that check out the PR head; if unavoidable, gate on `if: github.event.pull_request.head.repo.full_name == github.repository`.
- Ephemeral self-hosted runners only (one job per VM), no shared state.
- CloudTrail/Activity logs: alert on `AssumeRoleWithWebIdentity` from unexpected `sub` claims, on first-seen `userAgent: aws-sdk-*` from CI roles outside business hours.
- Branch protection plus required reviews for any file under `.github/`.

## References
- [GitHub: Security hardening with OpenID Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect) — canonical OIDC sub-claim format.
- [Palo Alto Unit42 — tj-actions supply chain](https://unit42.paloaltonetworks.com/github-actions-supply-chain-attack/) — real-world CI breach mechanics.
- [HackTricks Cloud — CI/CD](https://cloud.hacktricks.wiki/en/pentesting-ci-cd/index.html) — pipeline attack catalogue.

See also: [[cicd-pipeline-hardening-defender]], [[gitops-security-argo-flux]], [[sigstore-cosign-supply-chain-signing]], [[slsa-supply-chain-framework]], [[iac-scanning-checkov-tfsec-kics]]
