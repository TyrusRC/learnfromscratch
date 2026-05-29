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

## AWS
- [[aws-iam-enum]] · [[aws-instance-metadata]]
- [[aws-sts-assume-role]]
- [[aws-s3-attacks]] · [[aws-lambda-attacks]]
- [[aws-secrets-manager]] · [[aws-cross-account]]
- [[aws-organisations-abuse]]

## Azure / Entra
- [[entra-id-enum]] · [[az-cli-tokens]]
- [[managed-identities]]
- [[azure-key-vault-attacks]]
- [[service-principal-abuse]]
- [[app-registration-abuse]]
- [[entra-conditional-access-bypass]]

## GCP
- [[gcp-service-account-enum]] · [[gcp-metadata-server]]
- [[gcs-attacks]] · [[gcp-iam-misconfig]]
- [[gcp-oauth-app-abuse]]

## Kubernetes
- [[k8s-rbac-abuse]] · [[k8s-service-account-tokens]]
- [[k8s-host-mount-escape]] · [[k8s-privileged-pod]]
- [[k8s-etcd-attacks]] · [[k8s-admission-controllers]]

## Cross-cloud and CI/CD
- [[multi-cloud-pivoting]]
- [[ci-cd-as-cloud-attack-surface]]
