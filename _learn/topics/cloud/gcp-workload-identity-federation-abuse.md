---
title: GCP Workload Identity Federation abuse
slug: gcp-workload-identity-federation-abuse
aliases: [gcp-wif-abuse, workload-identity-federation-misconfig]
---

> **TL;DR:** GCP Workload Identity Federation (WIF) lets external identities (OIDC tokens from GitHub Actions, AWS, Azure, or arbitrary OIDC providers) impersonate GCP service accounts without a long-lived JSON key. The trust decision is made by `attribute_condition` CEL expressions. Misconfigured conditions — e.g., `attribute.repository != ""` instead of `attribute.repository == "org/repo"` — let any identity matching the loose condition impersonate the service account. Pattern: identity-layer compromise of GCP without ever phishing a user. Companion to [[gha-oidc-sub-claim-wildcards]] and [[gcp-metadata-token-theft]].

## Why this matters

- WIF is **the modern recommended way** to authenticate CI/CD into GCP — rapidly replacing long-lived keys.
- The trust gate is **a CEL expression** the admin writes by hand. Easy to get wrong.
- Wrong WIF policies expose **service-account-level access** to anyone who can present a matching token.
- The blast radius is whatever IAM the service account has — often broad in CI/CD usage.

## How WIF works

The flow:

1. External workload (e.g., GitHub Actions) obtains an OIDC token from its identity provider (`token.actions.githubusercontent.com`).
2. Workload presents the token to GCP's STS endpoint with a target workload-identity-pool / provider.
3. GCP validates the JWT signature against the provider's JWKS.
4. GCP evaluates the `attribute_condition` against the token claims.
5. If the condition passes, GCP issues a federated STS token.
6. The STS token is exchanged for a service-account access token (if the SA's IAM allows the `serviceAccountTokenCreator` for the federated principal).

Two gates: the **condition** in WIF, and the **IAM binding** on the service account.

## Common misconfigurations

### Pattern A — Empty / too-loose condition

```python
# Misconfigured
attribute_condition = "attribute.repository != ''"
```

Any GitHub repo can present a token with a non-empty repository attribute — i.e., **every GitHub Actions runner**. Combined with a service account that has any useful permission, anyone on GitHub can take over the SA.

Correct:

```python
attribute_condition = "attribute.repository == 'my-org/my-repo'"
```

### Pattern B — Wildcarded repository owner

```python
attribute_condition = "attribute.repository.startsWith('my-org/')"
```

Any repo in `my-org` can impersonate, including fork-PRs that run workflows with elevated tokens. See [[gha-oidc-sub-claim-wildcards]].

### Pattern C — IAM binding too permissive

The SA's IAM binding might be:

```
serviceAccount:my-sa@p.iam.gserviceaccount.com
  -> principalSet://iam.googleapis.com/projects/.../locations/global/workloadIdentityPools/.../*
```

The `/*` allows any federated principal. Should be:

```
serviceAccount:my-sa@p.iam.gserviceaccount.com
  -> principalSet://iam.googleapis.com/projects/.../locations/global/workloadIdentityPools/.../attribute.repository/my-org/my-repo
```

### Pattern D — Audience misconfiguration

The `audience` parameter (Google's WIF expects a specific audience). If the workload identity pool accepts the default audience without enforcement, tokens from other workloads that happen to target the same default can impersonate.

## Recon approach

With read-only access in the target GCP project:

- `gcloud iam workload-identity-pools list`
- `gcloud iam workload-identity-pools providers list --workload-identity-pool=X`
- Examine each provider's `attributeCondition` and `attributeMapping`.
- `gcloud iam service-accounts list` and check IAM policy for `principalSet://...` bindings.

External recon: organisations sometimes publish WIF setup in Terraform on public GitHub. Search for `google_iam_workload_identity_pool_provider` configs.

## Exploit shape

1. Identify a target project's WIF provider trusting GitHub.
2. Observe the `attribute_condition`.
3. Create a fork-PR or a new repo matching the condition.
4. CI workflow uses `google-github-actions/auth` with the target's WIF config.
5. Obtain federated STS token, then SA access token.
6. Operate as the SA.

Pacu and similar tools now have WIF audit modules.

## Defensive baseline

- Conditions must be **exact-match** on `attribute.repository` (and `attribute.ref` if needed for branch-protection).
- IAM bindings use **principal**, not `principalSet://`, when targeting one repo.
- Service account permissions are **least privilege** — don't make CI SAs project-owner.
- WIF events appear in **Cloud Audit Logs** as `iamcredentials.googleapis.com/GenerateAccessToken` with the federated subject.
- Alert on **first-time** federated subjects per service account.

## Workflow to study

1. Create a GCP project, configure WIF pool + provider for GitHub Actions.
2. Bind a SA with low-priv permissions.
3. Author a GitHub Actions workflow using the WIF config.
4. Run, observe the federated impersonation.
5. Loosen the condition to `attribute.repository != ''`; observe that any repo can now impersonate.
6. Read the audit log entries.

## Related cloud federation attacks

- **AWS IAM Roles Anywhere** — see [[aws-iam-roles-anywhere-abuse]].
- **AWS OIDC federation for GitHub Actions** — same misconfig class.
- **Azure federated identity credentials** — same shape; less well audited.
- **`tj-actions/changed-files`** style supply chain — see [[tj-actions-tag-mutation]] — touches WIF indirectly when the action is used as the WIF-token producer.

## References
- [GCP Workload Identity Federation docs](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Google — best practices for WIF](https://cloud.google.com/iam/docs/best-practices-for-using-and-managing-workload-identity-pools)
- [Datadog Security Research — GCP misconfig](https://securitylabs.datadoghq.com/)
- [WIF audit modules in Prowler](https://github.com/prowler-cloud/prowler)
- See also: [[gha-oidc-sub-claim-wildcards]], [[aws-iam-roles-anywhere-abuse]], [[gcp-metadata-token-theft]], [[cloud-iam-misconfig-patterns]]
