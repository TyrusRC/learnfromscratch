---
title: Multi-cloud pivoting
slug: multi-cloud-pivoting
---

> **TL;DR:** Workload identity federation lets a principal in one cloud (or a CI runner, or a K8s pod) mint short-lived creds in *another* cloud via OIDC/SAML — compromise the source identity once, traverse to every cloud that trusts it.

## What it is
Workload identity federation replaces stored cross-cloud keys with OIDC: cloud A issues a signed JWT for one of its workloads, cloud B's trust policy says "if the JWT comes from issuer A and the `sub` claim matches X, mint me an STS/SA token". Convenient for engineering — and a single trust-policy `sub` typo turns the federation into an "anyone can assume" door. The same pattern threads through GitHub/GitLab → cloud, K8s SA → cloud, and Okta/Auth0 → cloud.

## Preconditions / where it applies
- Source workload you control: a GCP service account, an EKS/AKS/GKE pod with a token, a CI job, an Azure managed identity, or any OIDC-signing IdP.
- Destination cloud with an IAM/IdP federation configured (AWS IAM Identity Provider + role with `AssumeRoleWithWebIdentity`, GCP Workload Identity Pool, Azure federated credential on app registration).
- Loose `sub`/audience constraints in the destination trust policy (see [[gha-oidc-sub-claim-wildcards]]).

## Technique
1. **Enumerate federation** in each cloud you can already read:
   - AWS: `aws iam list-open-id-connect-providers`, then `aws iam list-roles` and grep trust policies for `Federated:`.
   - GCP: `gcloud iam workload-identity-pools list --location=global`, then `... providers list`.
   - Azure: `az ad app federated-credential list --id <appId>`.

2. **Mint a token from the source** the destination expects:

```bash
# GCP SA -> ID token destined for AWS
gcloud auth print-identity-token --audiences=sts.amazonaws.com \
  --impersonate-service-account=svc@proj.iam.gserviceaccount.com

# Trade it for AWS creds
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::111:role/gcp-to-aws \
  --role-session-name pivot \
  --web-identity-token "$ID_TOKEN"
```

3. **AWS -> GCP** via Workload Identity Federation: present an AWS SigV4-signed `GetCallerIdentity` token to GCP STS `token` endpoint; GCP verifies the AWS identity and returns a federated access token you can use with `--impersonate-service-account` for a real GCP SA.

4. **K8s pod -> cloud**: the projected `ServiceAccountToken` is already an OIDC JWT — combined with IRSA (AWS), Workload Identity (GCP), or Azure Workload Identity, a pod that you RCE into hands you a cloud-control-plane token. See [[token-stealing-cloud]] for harvesting from `/var/run/secrets/tokens/`.

5. **Chain**: GitHub Actions OIDC -> AWS role -> AWS role that trusts a GCP WIF -> GCP project; trust graphs are rarely audited end-to-end.

## Detection and defence
- Constrain every federation by **issuer + audience + sub** (exact match), and `aud` should be cloud-provider-specific not `sts.amazonaws.com` reused everywhere.
- AWS: alert on `AssumeRoleWithWebIdentity` with new `sub` values; GCP: monitor `AuditLog` for `ExchangeToken` from unexpected pools; Azure: alert on new federated credentials on app registrations.
- Inventory federated identity providers like you do users — they are users.
- Prefer **resource-scoped** trust (per-repo, per-cluster, per-SA) over org-wide.
- Network egress controls on workloads: a pod that should never talk to `sts.amazonaws.com` shouldn't be allowed to.

## References
- [GCP: Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation) — formal flow for federating into GCP.
- [AWS: AssumeRoleWithWebIdentity](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html) — STS API used by every OIDC pivot into AWS.
- [HackTricks Cloud — Cross-cloud pivoting](https://cloud.hacktricks.wiki/) — recipes per source/destination pair.
