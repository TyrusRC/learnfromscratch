---
title: GCP IAM misconfig
slug: gcp-iam-misconfig
---

> **TL;DR:** GCP IAM bindings — primitive roles, custom roles with stray `*Update`/`actAs` permissions, and bindings at folder/org scope — are the canonical escalation surface; Rhino's privesc catalog enumerates ~40 known single-permission-to-owner paths.

## What it is
GCP IAM grants are tuples of (principal, role, resource) attached as bindings at a resource node. Roles are bundles of permissions; permissions ending in `.set`, `.create`, `.update`, `.actAs` are the dangerous ones because they let you pivot to identities or attach yourself to higher-privilege bindings. The "primitive roles" — Owner, Editor, Viewer — are project-wide superpowers; Editor in particular includes `iam.serviceAccountKeys.create` on every project SA, an instant privesc to any SA in the project.

## Preconditions / where it applies
- Foothold principal (user, service account, or workload-identity-bound identity).
- That principal holds at least one permission from Rhino's catalog (e.g. `iam.serviceAccounts.actAs`, `iam.roles.update`, `cloudfunctions.functions.create`, `deploymentmanager.deployments.create`).
- Target project/folder/org has higher-priv SAs to pivot to.

## Technique
**Enumerate your effective permissions:**

```bash
gcloud projects get-iam-policy $PROJECT --format=json \
  | jq '.bindings[] | select(.members[] | contains("'$ME'"))'
gcloud iam roles describe roles/editor   # see what Editor actually grants
# what can I do here?
gcloud asset search-all-iam-policies --scope=projects/$PROJECT --query='policy:'$ME
```

**Known single-permission privesc paths (Rhino catalog highlights):**

1. **`iam.serviceAccountKeys.create`** on any SA → mint a JSON key for that SA, auth as it.
   ```bash
   gcloud iam service-accounts keys create k.json --iam-account=admin-sa@proj.iam.gserviceaccount.com
   gcloud auth activate-service-account --key-file=k.json
   ```
2. **`iam.serviceAccounts.getAccessToken` / `iam.serviceAccounts.signJwt`** → mint OAuth/ID tokens for the target SA without a key.
   ```bash
   gcloud auth print-access-token --impersonate-service-account=admin-sa@...
   ```
3. **`iam.serviceAccounts.actAs` + `cloudfunctions.functions.create`** → deploy a function running as the target SA; invoke it to exfil its token.
4. **`iam.serviceAccounts.actAs` + `compute.instances.create`** → launch a VM with the SA attached; SSH in; query [[gcp-metadata-server]] for the token.
5. **`deploymentmanager.deployments.create`** → DM runs as the Google APIs SA which has heavy permissions; deploy a template that grants you Owner.
6. **`iam.roles.update`** on a role you hold → add `*` permissions to your own role.
7. **`cloudbuild.builds.create`** → builds run as the Cloud Build SA which has Editor by default; build a step that exfils its token.
8. **`orgpolicy.policy.set`** → relax org policies that block SA key creation in other projects, then chain.

**Owner-via-Editor:** Editor on a project + any one SA in that project → SA-key → impersonate → use that SA's grants on other projects.

Chain with [[gcp-service-account-enum]] for target selection and [[gcp-metadata-server]] for credential extraction inside compute.

## Detection and defence
- Cloud Audit Logs (Admin Activity): alert on `SetIamPolicy`, `CreateServiceAccountKey`, `GenerateAccessToken`, `deployments.insert`.
- Disable SA key creation via org policy `iam.disableServiceAccountKeyCreation`.
- Replace primitive roles (Owner/Editor/Viewer) with custom least-priv roles; never grant Editor at project scope.
- Use Workload Identity Federation instead of SA keys for external workloads.
- Run IAM Recommender — it surfaces over-privileged grants based on 90-day usage.
- Tag and inventory all SAs; auto-disable unused SAs and rotate keys aggressively.

## References
- [Rhino Security — GCP IAM Privesc](https://github.com/RhinoSecurityLabs/GCP-IAM-Privilege-Escalation) — privesc catalog
- [HackTricks Cloud — GCP privesc](https://cloud.hacktricks.wiki/en/pentesting-cloud/gcp-security/gcp-privilege-escalation/index.html) — abuse paths
- [Google — IAM best practices](https://cloud.google.com/iam/docs/using-iam-securely) — hardening guidance
