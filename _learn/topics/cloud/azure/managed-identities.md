---
title: Managed identities
slug: managed-identities
---

> **TL;DR:** Any code running on an Azure resource with a managed identity can hit the IMDS endpoint and receive an Entra access token; the only authorisation gate is whatever RBAC the identity was granted.

## What it is
Managed identities are the Azure equivalent of an instance role. A *system-assigned* identity is tied 1:1 to a resource (deleted with it); a *user-assigned* identity is a standalone object that can be attached to many resources. Both are surfaced as a service principal in Entra and can hold Entra role assignments, Azure RBAC, and Key Vault access. Inside the resource, code reaches `http://169.254.169.254/metadata/identity/oauth2/token` (VMs) or `IDENTITY_ENDPOINT` + `IDENTITY_HEADER` env vars (App Service, Functions, Container Apps) and exchanges for an access token scoped to whatever `resource` it asks for.

## Preconditions / where it applies
- Code execution or unrestricted SSRF on a VM, App Service, Function, Container App, AKS pod (via IRSA-style federation or workload identity), Logic App, etc.
- A managed identity is attached (check `az vm identity show` / Portal).
- Identity has some non-trivial RBAC — the default "no roles" identity is useless but most enterprises drift.

## Technique
1. Hit the metadata endpoint from inside the resource and request a token for ARM and/or Graph.
2. Use that token to enumerate what the identity can do (`az role assignment list`).
3. Pivot — Key Vault dataplane, storage SAS, ARM deployment write, etc.

```bash
# VM (IMDS)
curl -s -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/"
```

```bash
# App Service / Functions (env-var based)
curl -s "$IDENTITY_ENDPOINT?resource=https://graph.microsoft.com&api-version=2019-08-01" \
     -H "X-IDENTITY-HEADER: $IDENTITY_HEADER"
```

```bash
# Use the token
TOK=$(curl -sH "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" \
  | jq -r .access_token)

az account get-access-token --resource https://management.azure.com/ --output none
az login --identity         # easiest form, if az CLI is present
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

Frequent post-ex wins: an App Service with `Contributor` over its resource group → deploy a new function that reads storage account keys; an AKS kubelet identity with `AcrPull` plus `Reader` on the cluster → enumerate secrets via Run Command; a Logic App with Key Vault Secrets User → silently exfil secrets.

## Detection and defence
- Audit RBAC of every managed identity quarterly; remove `Contributor`/`Owner` at subscription scope.
- For Functions and App Service, set `WEBSITE_DISABLE_MSI_AUTH_PERSISTENCE` style controls and ensure the identity endpoint is not reachable from arbitrary worker code paths (firewall the IMDS at the host where supported).
- Activity Log alerts on `Microsoft.Authorization/roleAssignments/write` and on tokens minted for Graph from unusual identities.
- Related: [[azure-key-vault-attacks]], [[app-registration-abuse]], [[aws-instance-metadata]], [[gcp-metadata-server]].

## References
- [HackTricks Cloud — Managed identities](https://cloud.hacktricks.wiki/en/pentesting-cloud/azure-security/az-services/az-managed-identities.html) — abuse recipes per resource type.
- [Microsoft — Managed identities overview](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview) — official endpoint and configuration reference.

See also: [[az-cli-tokens]], [[azure-key-vault-attacks]], [[azure-storage-sas-abuse]], [[service-principal-abuse]]
