---
title: Cloud — topics
slug: cloud-index
aliases: [cloud-topics]
---

Cloud control-plane attack primitives. See [[cloud-red-team]] for
ordering.

## Universal
- [[cloud-identity-mental-model]]
- [[cloud-iam-misconfig-patterns]]
- [[token-stealing-cloud]]
- [[ssrf-to-cloud]]

## AWS — fundamentals
- [[aws-iam-enum]] · [[aws-instance-metadata]]
- [[aws-sts-assume-role]] · [[aws-assumerole-chains]]
- [[aws-s3-attacks]] · [[aws-lambda-attacks]]
- [[aws-secrets-manager]] · [[aws-cross-account]]
- [[aws-organisations-abuse]]
- [[aws-imds-ssrf-pivot]]

## AWS — modern persistence and evasion
- [[aws-sso-device-code-phishing]]
- [[aws-iam-eventual-consistency-persistence]]
- [[aws-cloudtrail-policy-size-evasion]]
- [[aws-rogue-oidc-idp-persistence]]
- [[aws-iam-roles-anywhere-abuse]]
- [[s3-bucket-key-policy-confused-deputy]]

## Azure / Entra — fundamentals
- [[entra-id-enum]] · [[az-cli-tokens]]
- [[managed-identities]] · [[azure-managed-identity-abuse]]
- [[azure-key-vault-attacks]]
- [[service-principal-abuse]]
- [[app-registration-abuse]]
- [[entra-conditional-access-bypass]]

## Azure / Entra — 2024-2026 research
- [[entra-actor-token-cross-tenant]]
- [[entra-cross-tenant-sync-abuse]]
- [[entra-device-code-prt-pivot]]
- [[entra-connect-exploitation-2025]]
- [[azure-pipelines-logging-command-injection]]

## GCP
- [[gcp-service-account-enum]] · [[gcp-metadata-server]]
- [[gcs-attacks]] · [[gcp-iam-misconfig]]
- [[gcp-oauth-app-abuse]]
- [[gcp-metadata-token-theft]]
- [[gcp-workload-identity-federation-abuse]]

## SaaS / IdP control planes
- [[okta-attacks]]
- [[google-workspace-attacks]]
- [[m365-admin-attacks]]
- [[cloudflare-tenant-attacks]]

## Data / orchestration
- [[airflow-attacks]]
- [[terraform-state-extraction]]

## Kubernetes
- [[k8s-rbac-abuse]] · [[k8s-service-account-tokens]]
- [[k8s-host-mount-escape]] · [[k8s-privileged-pod]]
- [[k8s-etcd-attacks]] · [[k8s-admission-controllers]]
- [[k8s-ingressnightmare]]
- [[k8s-admission-webhook-abuse]]
- [[opa-rego-policy-bypasses]]

## Cross-cloud and CI/CD
- [[multi-cloud-pivoting]]
- [[multi-cloud-red-team-scenario-walkthrough]]
- [[cloud-to-onprem-pivot-techniques]]
- [[ci-cd-as-cloud-attack-surface]]
- [[gha-oidc-sub-claim-wildcards]]
- [[tj-actions-tag-mutation]]
- [[gitlab-ci-attacks]] · [[jenkins-attacks]]

## Zero Trust + cloud security tooling
- [[zero-trust-architecture-practitioner]]
- [[ztna-vs-vpn-migration]]
- [[identity-aware-proxy-deep]]
- [[cspm-cnapp-dspm-landscape]]
- [[service-mesh-security-deep]]
