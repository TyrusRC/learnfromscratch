---
title: SLSA — Supply-chain Levels for Software Artifacts
slug: slsa-supply-chain-framework
---

> **TL;DR:** SLSA (Supply-chain Levels for Software Artifacts) is OpenSSF's framework defining incremental requirements for producing tamper-evident, verifiable builds. Four build-track levels (0, 1, 2, 3) with corresponding source and dependency tracks under development. SLSA Level 3 has become a baseline expectation for security-mature open-source and enterprise software since the SolarWinds / Codecov / 3CX incidents.

## What it is
SLSA defines requirements across multiple "tracks":
- **Build track** — provenance + isolation of the build process
- **Source track** (draft) — integrity of source code submission process
- **Dependency track** (planned) — provenance of consumed dependencies

Current SLSA v1.0 (April 2023) focuses on the build track. Source and dependency tracks are in development.

## Build track levels

| Level | Requirements |
|---|---|
| **0** | No requirements (default state) |
| **1** | Provenance document exists; describes how artifact was built; not yet authenticated |
| **2** | Signed provenance; build platform hosted (not local laptop); reasonably hard to forge |
| **3** | Hardened build platform with strong isolation between builds; non-falsifiable provenance |

(Earlier SLSA v0.1 had Level 4; collapsed into the v1.0 Level 3 + future enhancements.)

## Provenance — the central artifact

SLSA provenance is a signed in-toto statement describing:
- What was built (subject artifact + digest)
- Who built it (build platform identity)
- How it was built (build entry point, parameters, source ref, dependencies)
- When it was built (timestamp)
- What ran the build (builder version, configuration)

```json
{
  "_type": "https://in-toto.io/Statement/v1",
  "subject": [{"name": "ghcr.io/myorg/app", "digest": {"sha256": "abc..."}}],
  "predicateType": "https://slsa.dev/provenance/v1",
  "predicate": {
    "buildDefinition": {
      "buildType": "https://slsa-framework.github.io/github-actions-buildtypes/workflow/v1",
      "externalParameters": {
        "workflow": {
          "ref": "refs/tags/v1.0.0",
          "repository": "https://github.com/myorg/app",
          "path": ".github/workflows/release.yaml"
        }
      },
      "resolvedDependencies": [
        {"uri": "git+https://github.com/myorg/app@refs/tags/v1.0.0",
         "digest": {"sha1": "..."}}
      ]
    },
    "runDetails": {
      "builder": {"id": "https://github.com/actions/runner/github-hosted"},
      "metadata": {"invocationId": "...",
                    "startedOn": "...",
                    "finishedOn": "..."}
    }
  }
}
```

## Preconditions / where it applies
- Software publishers producing artifacts consumed by others (open source, vendor SaaS, internal platforms)
- Compliance with US Executive Order 14028 + NIST SP 800-218 (SSDF)
- Customer / regulatory requirement (financial services, healthcare, federal contracts)
- High-value targets (CI/CD compromise a known incident class)

## Tradecraft — reaching SLSA Level 3

### GitHub Actions reusable workflows (easiest path)
GitHub publishes SLSA Level 3 reusable workflows that handle provenance generation automatically:

```yaml
jobs:
  build:
    uses: slsa-framework/slsa-github-generator/.github/workflows/builder_container-based_slsa3.yml@v2
    with:
      builder-image: ghcr.io/myorg/builder:1.0.0
      builder-digest: sha256:...
      config-path: .slsa-config.yaml
```

The reusable workflow:
- Runs in a separate isolated job (privilege isolation)
- Generates provenance describing the build
- Signs with Sigstore keyless
- Uploads provenance as separate OCI artifact (`.intoto.jsonl`)

Similar reusable workflows exist for npm packages, Go modules, Python packages, generic Docker.

### GitLab CI SLSA
GitLab CI has a SLSA generator template (`SLSA.gitlab-ci.yml`). Requirements parallel GitHub.

### Self-hosted runners — careful
SLSA Level 3 requires "hardened build platform". Self-hosted runners disqualify Level 3 unless you can demonstrate equivalent isolation (ephemeral runners, network restriction, no persistent state). Most orgs stay on GitHub-hosted runners for SLSA-eligible builds.

### Verifying SLSA provenance
Consumer side:

```bash
# slsa-verifier tool
slsa-verifier verify-artifact \
  --provenance-path provenance.intoto.jsonl \
  --source-uri github.com/myorg/app \
  --source-tag v1.0.0 \
  myartifact.tar.gz
```

For container images:

```bash
cosign verify-attestation --type slsaprovenance \
  --certificate-identity-regexp ... \
  ghcr.io/myorg/app:1.0.0
```

See [[sigstore-cosign-supply-chain-signing]].

## Source track (draft, evolving)

Proposed source levels:
- **Source Level 1** — version-controlled
- **Source Level 2** — change history retained, code review enforced
- **Source Level 3** — protected branches, signed commits, two-party review for high-risk changes

For most orgs, GitHub branch protection + CODEOWNERS + DCO/GPG signed commits meets Source Level 3 informally.

## Dependency track (planned)

Recursive SLSA: artifact A built with SLSA L3 from dependencies B, C, D — what's the SLSA level of B, C, D? Dependency track will define how to attest to transitive supply chain.

For now: combine SBOM ([[sbom-and-software-supply-chain-attestation]]) with selective scrutiny of critical dependencies.

## SLSA + SBOM + VEX

Three complementary artifacts:
- **SBOM** — what's in the build (package list)
- **SLSA provenance** — how the build was made
- **VEX** — which CVEs in the SBOM actually affect this artifact

Mature supply chain ships all three signed.

## Adoption signals (2024-2025)

- npm packages: 35%+ of top-1000 packages now publish SLSA provenance
- Major CNCF projects (Kubernetes, Istio, Argo, Tekton, Flux) ship signed images with attestations
- Some federal contracts reference SLSA in supply-chain language
- Cosign + Rekor integration makes SLSA L3 achievable in a single CI workflow

## Common implementation pitfalls

- **Provenance without verification** — publishing provenance is half the work; consumers must verify
- **Wrong source URI in verification** — typos in `--source-uri` accept attacker repo with valid signature
- **Self-hosted runners claiming Level 3** — without isolation evidence, can't claim L3
- **SLSA fatigue: "we shipped L1 once"** — L1 alone provides little; aim for L2+ minimum
- **Mixing Level claims across artifacts** — be specific per artifact, not org-wide
- **SLSA without admission enforcement** — provenance not gating deployment = aspirational compliance only

## Mapping to other supply chain efforts

- **NIST SSDF (SP 800-218)** — SLSA satisfies many SSDF practices
- **EU Cyber Resilience Act (CRA)** — provenance + SBOM align with CRA "essential cybersecurity requirements" for software
- **US EO 14028** — drives SSDF + SBOM requirements; SLSA is the technical implementation
- **CISA Secure by Design** — supply chain pillar overlaps SLSA
- **OpenSSF Scorecard** — checks for SLSA provenance generation; raises score
- **CNCF Software Supply Chain Best Practices Whitepaper** — references SLSA

## OPSEC for blue team / platform team

- Centralised build platform (e.g., shared SLSA Level 3 builder) — all teams use, all artifacts get L3 for free
- Block CI workflows that don't use the SLSA-aware reusable workflow (CI policy enforcement)
- Audit Rekor for your org's signing identity — unexpected entries = compromised CI
- Periodically test: download a published artifact and verify provenance from a separate workstation; broken verification surfaces real-world issues

## OPSEC for adversary modeling

What SLSA Level 3 PREVENTS:
- Tampered binary uploaded to package registry post-build
- Build platform run on developer laptop (no isolation, easy compromise)
- Provenance forged with rotating attacker keys (Sigstore Rekor catches retro forgery)
- Mismatched source ref (signed for v1.0 but actually built from main with backdoor)

What SLSA Level 3 does NOT prevent:
- Malicious code in the source repo (Source track when ready)
- Compromised dependency (Dependency track when ready)
- Build with valid provenance but bad output (compiler bug, malicious dev pushing legit code)
- Runtime compromise post-deployment

SLSA narrows the attack surface; doesn't eliminate it.

## References
- [SLSA framework](https://slsa.dev/)
- [SLSA Level 3 GitHub generator](https://github.com/slsa-framework/slsa-github-generator)
- [slsa-verifier](https://github.com/slsa-framework/slsa-verifier)
- [in-toto attestation framework](https://in-toto.io/)
- [OpenSSF Scorecard](https://github.com/ossf/scorecard)
- [NIST SP 800-218 SSDF](https://csrc.nist.gov/pubs/sp/800/218/final)
- [US EO 14028](https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/)

See also: [[sigstore-cosign-supply-chain-signing]], [[sbom-and-software-supply-chain-attestation]], [[cicd-pipeline-hardening-defender]], [[github-actions-workflow-source-audit]], [[gha-oidc-sub-claim-wildcards]], [[tj-actions-tag-mutation]], [[npm-postinstall-and-typosquat-audit]], [[ghost-commit-smuggling]], [[devsecops-platform-engineering]], [[ci-cd-as-cloud-attack-surface]]
