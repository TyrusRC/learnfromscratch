---
title: Cloud red team
slug: cloud-red-team
aliases: [cloud-pentesting, multi-cloud-red-team]
---

> Cloud is IAM-shaped. Most "cloud bugs" are really identity, policy,
> trust, or supply-chain bugs that happen to live in a cloud control
> plane. This path puts identity first, then layers per-provider attack
> surface and Kubernetes on top.

## Prereqs

- [[web-application-security]] stage 1 + [[api-security]] stage 1.
- One scripting language (Python preferred for cloud SDKs).
- Free-tier accounts in AWS, Azure, and GCP for hands-on.

## Stage 1 — universal IAM mental model

- [[cloud-identity-mental-model]] — principals, policies, trust, scope.
- [[cloud-iam-misconfig-patterns]] — confused deputy, over-broad trust,
  wildcard resources, transitive trust.
- [[token-stealing-cloud]] — where short-lived credentials live and how
  they leak.
- [[ssrf-to-cloud]] — instance metadata as the universal pivot.

## Stage 2 — per-provider attack surface

### AWS
- [[aws-iam-enum]] · [[aws-instance-metadata]] ·
  [[aws-sts-assume-role]].
- [[aws-s3-attacks]] · [[aws-lambda-attacks]] ·
  [[aws-secrets-manager]].
- [[aws-cross-account]] · [[aws-organisations-abuse]].

### Azure / Entra ID
- [[entra-id-enum]] · [[az-cli-tokens]] ·
  [[managed-identities]].
- [[azure-key-vault-attacks]] · [[service-principal-abuse]].
- [[app-registration-abuse]] · [[entra-conditional-access-bypass]].

### GCP
- [[gcp-service-account-enum]] · [[gcp-metadata-server]].
- [[gcs-attacks]] · [[gcp-iam-misconfig]] ·
  [[gcp-oauth-app-abuse]].

## Stage 3 — Kubernetes and multi-cloud pivoting

- [[k8s-rbac-abuse]] · [[k8s-service-account-tokens]].
- [[k8s-host-mount-escape]] · [[k8s-privileged-pod]].
- [[k8s-etcd-attacks]] · [[k8s-admission-controllers]].
- [[multi-cloud-pivoting]] — federation, OIDC trust between clouds.
- [[ci-cd-as-cloud-attack-surface]] — GitHub Actions OIDC, GitLab JWT,
  CircleCI tokens.

## References

- HackTricks Cloud:
  <https://cloud.hacktricks.wiki/en/index.html>.
- [PEACH framework](https://peach.bonfire.security/) for SaaS-tenancy
  isolation.
- [Wiz Cloud Threat Landscape](https://threats.wiz.io/).
- [HackingTheCloud](https://hackingthe.cloud/).
