---
title: Helm chart — security audit
slug: helm-chart-security-audit
---

> **TL;DR:** A Helm chart packages templated Kubernetes manifests; values + templates render into YAML at install time. Charts pulled from untrusted repos can ship privileged pods, hostPath mounts, cluster-admin RBAC, and pre-install hooks running arbitrary code. Auditing means rendering with default + worst-case values, then checking the output against an admission baseline.

## What it is
Helm v3+ removed Tiller; clients render templates locally and submit manifests directly to kube-apiserver. Charts can be installed from:
- Helm repository (HTTP) — `helm repo add` then `helm install`
- OCI registry — `helm install oci://registry/chart:1.2.3`
- Local directory — `helm install ./chart`
- Tarball — `helm install chart.tgz`

The "chart" is just a directory with `Chart.yaml`, `values.yaml`, `templates/*.yaml`, and optional `crds/`, `charts/` (subcharts), `hooks/` annotations.

## Preconditions / where it applies
- Anyone deploying charts authored by others (community, vendor, internal)
- GitOps via Argo CD / Flux pulling Helm charts ([[gitops-security-argo-flux]])
- Internal platform team curating "blessed" chart catalog
- Bug bounty / pentest engagement against k8s clusters with Helm-managed apps

## Tradecraft — audit workflow

### Step 1 — Render the chart
Never trust the chart description. Always render the actual manifests:

```bash
helm template my-release my-chart \
  --values values.yaml \
  --namespace prod \
  > rendered.yaml

# With subchart dependencies pulled
helm dependency update
helm template ... --include-crds > rendered.yaml
```

Render with multiple value sets:
- `values.yaml` defaults
- `values-production.yaml` real deployment values
- An "attacker" values file maximising privilege flags

### Step 2 — Scan rendered manifests

```bash
# kubesec.io — best practices scoring
kubesec scan rendered.yaml

# Trivy — covers misconfig + vuln in referenced images
trivy config rendered.yaml
trivy k8s --report summary cluster

# Checkov — IaC scanning
checkov -f rendered.yaml --framework kubernetes

# Polaris (Fairwinds)
polaris audit --audit-path rendered.yaml
```

### Step 3 — Inspect security-sensitive constructs

Manual review checklist:
- `securityContext.privileged: true`
- `securityContext.runAsUser: 0` (root)
- `securityContext.allowPrivilegeEscalation: true`
- `securityContext.capabilities.add: [...]` — `SYS_ADMIN`, `NET_ADMIN`, `SYS_PTRACE` are red flags
- `hostNetwork: true` / `hostPID: true` / `hostIPC: true`
- `volumeMounts` with `hostPath` — especially `/`, `/var/run/docker.sock`, `/etc`, `/proc`
- ServiceAccount with `cluster-admin` ClusterRoleBinding
- Custom RBAC: `ClusterRole` with `["*"]` resources or `["*"]` verbs
- `automountServiceAccountToken: true` when not needed
- `imagePullPolicy: Always` with mutable tags (latest) — see Step 5
- Init containers running tools (curl, nsenter, debug binaries) that should be removed from runtime
- Pod-level secrets in env vars (vs mounted files)

### Step 4 — Pre-install / pre-upgrade hooks
Helm hooks (`helm.sh/hook` annotation) run Jobs at lifecycle points:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "0"
    helm.sh/hook-delete-policy: hook-succeeded
```

Hooks run with the chart's RBAC; attackers stage code in hooks because they run BEFORE main resources and `helm template` doesn't always surface them.

Audit:
```bash
helm template ... | yq 'select(.metadata.annotations["helm.sh/hook"] != null)'
```

### Step 5 — Image references
Charts reference container images. Audit:
- Are images from your trusted registry mirror?
- Are tags pinned to digests (`@sha256:...`)?
- Does the chart support `image.pullPolicy: IfNotPresent` for stability + tag immutability?
- Are init containers using throwaway images that haven't been scanned?

```bash
# Extract all images referenced
helm template ... | yq '..|.image? // empty' | sort -u
# Pipe to vulnerability scanner
helm template ... | yq '..|.image? // empty' | xargs -n1 trivy image
```

### Step 6 — Custom Resource Definitions (CRDs)
Charts shipping CRDs install cluster-scoped API extensions. Once installed, CRDs persist across helm uninstall (`crds/` directory is special).

Audit CRDs for:
- ClusterRole granted to CRD controller — often broader than needed
- ValidatingWebhookConfiguration / MutatingWebhookConfiguration — see [[k8s-admission-webhook-abuse]]
- Owner of the CRD-controller's webhook → admission bypass if compromised

### Step 7 — Subchart dependencies
`Chart.yaml` `dependencies:` block pulls subcharts. Recursively audit. Subcharts inherit the parent's `release.namespace` but may declare their own `namespace`.

```bash
helm dependency list
# Audit each subchart from its source independently
```

### Step 8 — Values injection attack surface
User-supplied `values.yaml` can sometimes inject configuration. If the chart authors used `.Values.extraArgs | toYaml`, attacker-controlled values become pod args. If `.Values.command` is overrideable, attacker can swap entrypoint.

```bash
# Find values references in templates that could be code-execution-relevant
rg -P '\.Values\.(command|args|image|entrypoint|securityContext|hostPath|hostNetwork)' templates/
```

### Step 9 — Chart provenance and signing
```bash
# Helm 3 signs and verifies charts using PGP
helm package --sign --key 'maintainer@example.com' --keyring ~/.gnupg/pubring.kbx my-chart
helm verify my-chart-1.2.3.tgz

# Modern alternative: Sigstore + Cosign
cosign sign --identity-token $(gcloud auth print-identity-token) \
  registry/my-chart:1.2.3
cosign verify --certificate-identity-regexp '...' registry/my-chart:1.2.3
```

OCI Helm charts integrate cleanly with cosign. See [[sigstore-cosign-supply-chain-signing]].

## Common dangerous patterns in popular charts

- **bitnami/postgresql** older versions: persistence volumes hostPath-fallback
- **stable/nginx-ingress** (deprecated): RBAC ClusterRole wildcards before refactor
- **prometheus-operator-stack**: extensive cluster-scoped permissions for ServiceMonitors
- **vault**: requires elevated permissions; verify auto-init paths
- **cert-manager**: needs ClusterIssuer permissions; bound to your DNS provider creds
- **istio**: webhook injection runs as cluster-admin during install

These aren't necessarily wrong — they're necessary for the chart's function — but the cluster admin should validate the trust model.

## Hardening internal charts

Patterns for organisations publishing internal charts:
- Pin all images to digests, generated from CI
- Drop unnecessary capabilities; runAsNonRoot mandatory
- ServiceAccount with minimum RBAC (use Helm's `serviceAccount.create: true` + named role binding)
- NetworkPolicy templates shipped by default (allow-list egress)
- PodDisruptionBudget for HA
- Helm `values.schema.json` for input validation; rejects unexpected fields
- `helm lint` + `helm template | kubeval` + `kubeconform` + `polaris` in CI

## Admission-time enforcement

Independent of chart quality, admission policy enforces baselines at apply time:
- **Pod Security Admission** — built-in PSA labels (`restricted`, `baseline`, `privileged`)
- **Kyverno** policies — see [[policy-as-code-opa-kyverno-defender]]
- **OPA Gatekeeper** ConstraintTemplates

Layered defense: chart audit + CI scan + admission policy.

## Common implementation pitfalls

- Trusting `helm.sh/hook` Jobs because they're "just init code" — they run with chart-managed RBAC
- Allowing `values.global.*` overrides for security-relevant fields
- Skipping CRD audit — CRDs persist forever
- Missing subchart audit
- Not pinning image digests; mutable tags = unpredictable security posture
- Using `helm install` directly in production (no GitOps audit trail)

## OPSEC for blue team

- Audit Helm release inventory: `helm list --all-namespaces` — unauthorized releases are persistence
- Helm Secrets stored in cluster as Secrets named `sh.helm.release.v1.*` (Kubernetes Secret backend) — protect them
- Release rollback (`helm rollback`) is admin-equivalent — audit usage
- For SBOM: `syft helm:chart:1.2.3` generates SBOM of images and packages within

## References
- [Helm Security Best Practices](https://helm.sh/docs/topics/securing_installation/)
- [Datree — Helm policy](https://www.datree.io/)
- [Kubesec.io](https://kubesec.io/) — manifest scoring
- [CNCF — Helm security blog series](https://www.cncf.io/blog/)
- [Bridgecrew — Checkov Helm policies](https://www.checkov.io/4.Integrations/Helm.html)

See also: [[gitops-security-argo-flux]], [[sigstore-cosign-supply-chain-signing]], [[k8s-admission-webhook-abuse]], [[k8s-rbac-abuse]], [[k8s-manifest-source-audit]], [[policy-as-code-opa-kyverno-defender]], [[iac-scanning-checkov-tfsec-kics]], [[k8s-privileged-pod]], [[k8s-host-mount-escape]], [[sbom-and-software-supply-chain-attestation]], [[k8s-image-registry-poisoning]], [[kubelet-exposed-api-attacks]]
