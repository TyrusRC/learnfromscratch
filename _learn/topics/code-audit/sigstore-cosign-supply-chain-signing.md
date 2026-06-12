---
title: Sigstore — Cosign, Rekor, Fulcio for supply-chain signing
slug: sigstore-cosign-supply-chain-signing
---

> **TL;DR:** Sigstore is the OpenSSF-hosted stack that makes container/artifact signing keyless and free: **Fulcio** issues short-lived signing certs tied to OIDC identity, **Cosign** signs and verifies artifacts, **Rekor** is an append-only transparency log. Replaces traditional PGP-signed releases with a workflow CI/CD pipelines can execute automatically with no long-lived keys.

## What it is
Three components:
- **Cosign** — CLI for signing/verifying OCI artifacts (containers, Helm charts, generic blobs)
- **Fulcio** — Certificate Authority issuing X.509 certs valid ~10 minutes, bound to OIDC identity (Google, GitHub, GitLab, Microsoft, Buildkite, etc.)
- **Rekor** — Transparency log (append-only, Merkle-tree backed) storing signature metadata for public verifiability

Workflow: CI pipeline authenticates via OIDC → Fulcio issues short-lived cert → Cosign signs artifact + cert chain → signature uploaded to OCI registry alongside artifact + Rekor entry → verifier checks signature, cert chain to Fulcio root, Rekor inclusion proof.

No long-lived signing keys. No PGP keyring management. Verifiable by anyone.

## Preconditions / where it applies
- Software vendors publishing container images, Helm charts, binaries
- CI/CD pipelines with OIDC integration (GitHub Actions, GitLab CI, Buildkite, CircleCI)
- Internal platforms wanting policy-enforced "only signed images deploy"
- Compliance contexts (SLSA, NIST SSDF, EO 14028) requiring verifiable provenance

## Tradecraft — signing

### Keyless signing in CI (GitHub Actions example)

```yaml
jobs:
  sign:
    permissions:
      id-token: write    # needed for OIDC
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with: {registry: ghcr.io, username: ${{ github.actor }}, password: ${{ secrets.GITHUB_TOKEN }}}
      - run: |
          docker build -t ghcr.io/myorg/app:$GITHUB_SHA .
          docker push ghcr.io/myorg/app:$GITHUB_SHA
      - uses: sigstore/cosign-installer@v3
      - run: |
          cosign sign --yes ghcr.io/myorg/app:$GITHUB_SHA
          # GITHUB_TOKEN OIDC implicit; Cosign fetches the OIDC token,
          # presents to Fulcio, gets cert, signs, uploads to Rekor.
```

The signature appears as a separate OCI artifact: `ghcr.io/myorg/app:sha256-<digest>.sig`.

### Signing with key (still supported)

```bash
cosign generate-key-pair    # cosign.key (encrypted) + cosign.pub
cosign sign --key cosign.key ghcr.io/myorg/app:1.0.0
```

Useful for air-gapped environments. Loses the public verifiability of keyless mode.

### Signing attestations

Attestations are signed claims about an artifact (provenance, SBOM, vulnerability scan results). They're stored as in-toto statements signed via Cosign.

```bash
# Generate SLSA provenance attestation
cosign attest --yes --predicate provenance.json --type slsaprovenance \
  ghcr.io/myorg/app:1.0.0

# Generate SBOM attestation
syft ghcr.io/myorg/app:1.0.0 -o spdx-json > sbom.json
cosign attest --yes --predicate sbom.json --type spdx ghcr.io/myorg/app:1.0.0

# Generate vulnerability scan attestation
trivy image --format cosign-vuln ghcr.io/myorg/app:1.0.0 > vuln.json
cosign attest --yes --predicate vuln.json --type vuln ghcr.io/myorg/app:1.0.0
```

Each attestation type has a defined predicate schema (in-toto.io/spec/Statement).

## Tradecraft — verification

### Simple verification

```bash
cosign verify --certificate-identity-regexp '^https://github\.com/myorg/.+' \
              --certificate-oidc-issuer https://token.actions.githubusercontent.com \
              ghcr.io/myorg/app:1.0.0
```

Verifies:
- Signature is valid
- Cert chain anchors at Fulcio root
- Cert SAN / extensions match expected identity (the GitHub repo / workflow)
- Rekor inclusion proof valid (no rollback)

### Verifying attestations

```bash
cosign verify-attestation --type slsaprovenance \
                          --certificate-identity-regexp ... \
                          ghcr.io/myorg/app:1.0.0
# Returns the signed predicate JSON for policy evaluation
```

### Policy-driven verification (Kyverno / OPA admission)

Kyverno policy enforcing only signed images deploy:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: {name: verify-images}
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify
      match: {any: [{resources: {kinds: [Pod]}}]}
      verifyImages:
        - imageReferences: ["ghcr.io/myorg/*"]
          attestors:
            - entries:
                - keyless:
                    issuer: https://token.actions.githubusercontent.com
                    subject: 'https://github.com/myorg/app/.github/workflows/release.yaml@refs/tags/v*'
                    rekor: {url: https://rekor.sigstore.dev}
```

See [[policy-as-code-opa-kyverno-defender]].

## Rekor — transparency log

Rekor is the public, append-only log. Every Sigstore signature is logged with its hash, signer identity, and verifiable inclusion proof.

```bash
# Search Rekor for entries about an artifact
rekor-cli search --sha 0123abc...
rekor-cli get --uuid 24296fb24...
```

Public Rekor instance: rekor.sigstore.dev. Organizations running their own Sigstore (private cloud) operate private Rekor instances.

**Why a transparency log matters:**
- Detect compromised signing identity post-facto (audit for unexpected entries)
- Prevent rollback attacks (signed artifact can't be silently retracted)
- Enable third-party verification without trusting either party

## Private / air-gapped Sigstore

Public Sigstore is hosted by OpenSSF. Enterprises with isolated networks deploy:
- **Private Fulcio** — own OIDC provider, own root CA
- **Private Rekor** — own transparency log
- **Private OCI registry** — Harbor / Nexus with signature endpoints

Reference deployment: [sigstore/sigstore](https://github.com/sigstore/sigstore) and Chainguard's "private sigstore" patterns.

## SLSA integration

Sigstore is the underlying tech that makes SLSA Level 2+ provenance practical. SLSA defines the **what** (provenance schema, build platform requirements); Sigstore defines the **how** (signing, transparency).

See [[slsa-supply-chain-framework]].

## Common use cases

1. **Container image signing** — most common; signed image gates deployment
2. **Helm chart signing** — OCI Helm charts signed same way
3. **Go module sum verification** — Cosign-signed checksums in `go.sum`
4. **GitHub release signing** — `gh release create` + Cosign blob signing
5. **SBOM attestation** — every release ships a signed SBOM
6. **VEX (Vulnerability Exploitability Exchange) statements** — signed assessments of CVE applicability

## Common implementation pitfalls

- **Forgetting `id-token: write` permission** in GitHub Actions — OIDC token unavailable, Fulcio call fails
- **Wrong `--certificate-identity-regexp`** — verification too permissive (`.*` matches any signer) or too strict (typo in repo path blocks legit signers)
- **Skipping Rekor verification** — `--insecure-ignore-tlog` defeats the point
- **Relying on public Sigstore SLA** for production gates — for high-availability, deploy private Sigstore or mirror Rekor
- **Treating signature as integrity check only** — signature proves identity, not that the artifact is "good"; pair with vulnerability + license scans
- **Long cert lifetimes via key-based signing without key rotation** — key-based mode shifts back to traditional PGP-style risks

## OPSEC for blue team

- Monitor Rekor for entries matching your org identity — unexpected entries = compromised signer
- Audit `cosign verify` failures in CI — failed verification might mean tampering, not just config issue
- Track signing identity coverage — every published artifact in your inventory should have a signature
- Rotate OIDC issuer credentials per `id-token` workflow exposure (GitHub PAT, GitLab token)
- For air-gapped: ensure private Fulcio + Rekor backed up; loss = signing capability lost permanently

## References
- [Sigstore project](https://www.sigstore.dev/)
- [Cosign docs](https://docs.sigstore.dev/cosign/)
- [Rekor docs](https://docs.sigstore.dev/logging/overview/)
- [Fulcio docs](https://docs.sigstore.dev/certificate_authority/overview/)
- [SLSA framework](https://slsa.dev/)
- [Chainguard — keyless signing in practice](https://www.chainguard.dev/unchained)
- [Kyverno verifyImages](https://kyverno.io/docs/writing-policies/verify-images/)

See also: [[slsa-supply-chain-framework]], [[sbom-and-software-supply-chain-attestation]], [[policy-as-code-opa-kyverno-defender]], [[gitops-security-argo-flux]], [[helm-chart-security-audit]], [[cicd-pipeline-hardening-defender]], [[github-actions-workflow-source-audit]], [[gha-oidc-sub-claim-wildcards]], [[tj-actions-tag-mutation]], [[npm-postinstall-and-typosquat-audit]], [[k8s-image-registry-poisoning]]
