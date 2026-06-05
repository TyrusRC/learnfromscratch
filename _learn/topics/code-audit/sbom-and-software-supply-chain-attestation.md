---
title: SBOM and software supply chain attestation
slug: sbom-and-software-supply-chain-attestation
aliases: [sbom-attestation, slsa-in-toto-sigstore]
---

> **TL;DR:** A Software Bill of Materials (SBOM) is an ingredient list for a build; an attestation is a signed statement about how that build happened, by whom, and from what sources. Together they let downstream consumers answer "did this binary actually come from the commit it claims, and what's inside it?" The hard problems are not generating SBOMs (Syft, cdxgen, Trivy do it in seconds) but ingesting them into a vulnerability and license pipeline, and verifying attestations at deploy time. This note covers SPDX vs CycloneDX, SLSA levels, in-toto, Sigstore, GitHub artifact attestations, and the regulatory drivers (EU CRA, US E.O. 14028). Companion to [[cve-2024-3094-xz-utils-backdoor]], [[npm-postinstall-and-typosquat-audit]], [[python-pypi-supply-chain-audit]], [[case-study-3cx-supply-chain]], [[case-study-solarwinds-2020]], and [[ghost-commit-smuggling]].

## Why it matters

Supply-chain incidents over the last six years — SolarWinds (2020), Codecov (2021), Kaseya (2021), 3CX (2023), MOVEit (2023, exploitation rather than build compromise), XZ Utils (2024) — share a common gap: defenders could not, after the fact, prove which build of which artifact ran in their environment, what it contained, or whether the published binary matched the upstream source. SBOMs and attestations are the audit trail that closes that gap.

Regulators noticed. US Executive Order 14028 (2021) required federal vendors to provide SBOMs; the EU Cyber Resilience Act (CRA, in force 2024, enforcement 2027) mandates SBOMs and vulnerability handling for products with digital elements; the FDA requires SBOMs for premarket medical-device submissions (2023+). Adjacent regimes: [[nis2-implementation]] pushes essential-entity supply-chain risk management, and sector playbooks like [[financial-sector-defender-playbook]] and [[healthcare-sector-defender-playbook]] increasingly demand third-party SBOM ingestion ([[third-party-risk-management-practitioner]]).

The catch: producing an SBOM is the easy 5%. Ingesting thousands of SBOMs from vendors, deduplicating components, mapping to CVEs, tracking licenses, and re-checking when a new CVE drops — that's the work.

## SBOM formats

### SPDX

Linux Foundation standard, ISO/IEC 5962:2021. Verbose, license-focused, long pedigree. SPDX 3.0 (2024) adds AI/ML and dataset profiles. JSON, YAML, RDF, tag-value, spreadsheet serializations. Federal preference in the US under E.O. 14028 guidance.

### CycloneDX

OWASP project, lightweight, security- and vulnerability-focused. JSON or XML. Native support for VEX (Vulnerability Exploitability eXchange) — letting vendors say "yes that CVE is in our SBOM but the vulnerable code path is unreachable." Widely adopted by appsec tooling.

### SWID

ISO/IEC 19770-2 software identification tags. Older, asset-management oriented, mostly seen embedded in enterprise software packaging (Windows MSI). Useful for inventory correlation, not for vulnerability triage.

Pick one primary and convert as needed. Most orgs land on CycloneDX for internal use and emit SPDX for federal customers.

### Component identifier hygiene

The format wars matter less than the identifier discipline inside. Useful identifiers: `purl` (package URL, e.g., `pkg:npm/lodash@4.17.21`), CPE (NVD's identifier, brittle), SWID tag IDs, file hashes (SHA-256). Without stable IDs you cannot join an SBOM to a CVE feed automatically.

## Generation tools

- **Syft** (Anchore): scans filesystems, container images, archives. Multi-ecosystem. Outputs SPDX, CycloneDX, Syft JSON. Pairs with Grype for vulnerability matching.
- **cdxgen** (OWASP): CycloneDX-native, deep language-ecosystem support including build-time dependency graphs that filesystem scans miss.
- **Trivy** (Aqua): scanner-first, SBOM as a side effect. Good in CI for combined vuln + SBOM output.
- **Tern**: container-image focused, parses Dockerfile and layers for provenance.
- **GitHub dependency graph + `sbom` API**: free, per-repo, SPDX. Limited to ecosystems GitHub parses; misses vendored or binary deps.
- **Vendor pipelines**: most modern build systems (Maven, Gradle, Bazel, npm, pip, Go) have plugins to emit SBOMs at build time, which is more accurate than scanning after the fact.

Build-time SBOMs > post-hoc scans, because they capture the resolved dependency graph the build actually used, including transitive resolutions and version pins. Post-hoc scans miss devDependencies, vendored sources, and statically linked C libraries.

## Consumption: where the real work lives

### Vulnerability lookup

Feed SBOMs into a continuously updated CVE/GHSA matcher: Grype, Trivy, Dependency-Track (OWASP), Snyk, vendor offerings. Two persistent pains:

- **False positives from CPE matching**: NVD's CPE strings are noisy; `lodash` matched against the wrong CPE will flag CVEs you don't have.
- **VEX layering**: vendor says "not exploitable in our context" — you need a process to ingest VEX and suppress without losing track of the underlying component.

### License compliance

GPL contamination in proprietary products, attribution requirements, copyleft cascades. SPDX shines here. Tools: FOSSA, Black Duck, OSS Review Toolkit (ORT), ScanCode Toolkit.

### Operational pipeline

Minimum viable program:

1. SBOMs generated at build, signed, stored alongside artifacts.
2. Ingested into a central repository (Dependency-Track, vendor SaaS).
3. Continuously matched against CVE feeds; new CVE on existing component triggers ticket to product owner.
4. Vendor SBOMs ingested for third-party software, same flow.
5. Reports map components to deployed environments so a CVE on log4j tells you which prod services.

Most "we have SBOMs" programs stop at step 1.

## Attestation: SLSA, in-toto, Sigstore

SBOMs say *what* is in a build; attestations say *how* it was built and *whether you should trust the claim*.

### SLSA — Supply-chain Levels for Software Artifacts

Google-originated framework (now OpenSSF), versioned (v1.0 in 2023, focused on Build track). Levels:

- **L1** — Build process exists, provenance documented (not signed). Mostly "we know what built this."
- **L2** — Provenance signed, version-controlled source, hosted build platform.
- **L3** — Hardened build platform (non-falsifiable provenance, isolated builds). Most mature programs land here.
- **L4** — Removed in v1.0; previously two-person review and hermetic builds. Returning in future tracks.

SLSA is a maturity ladder, not a compliance checkbox. Compare with [[appsec-maturity-checklist]] and [[secure-sdlc-rollout-playbook]].

### in-toto

Attestation framework — defines the envelope and predicate types for signed statements about steps in a supply chain. SLSA provenance is one predicate type; SBOM-attached attestations are another (SPDX, CycloneDX as predicates). Provides a layout file that downstream consumers verify the full chain against.

### Sigstore

Keyless signing infrastructure run by OpenSSF.

- **Cosign**: signing tool, often used for container images and arbitrary blobs.
- **Fulcio**: short-lived certificate authority, binds OIDC identity (GitHub Actions OIDC, Google, etc.) to signing keys for ~10 minutes.
- **Rekor**: append-only transparency log; signatures are logged so absence-of-evidence becomes evidence-of-tampering.
- **Trustroot / TUF**: distributes the trust anchors.

The point of Sigstore is "no long-lived private key to lose." The OIDC identity (e.g., a specific GitHub Actions workflow) signs, and the log records what was signed when, by whom.

### GitHub artifact attestations

Built-in since 2024: `actions/attest-build-provenance` and friends emit SLSA provenance signed via Sigstore, logged to Rekor, tied to the workflow identity. `gh attestation verify` consumes them. Cheapest path to SLSA L2/L3 for projects already on GitHub Actions. Pair with [[github-actions-workflow-source-audit]] to make sure the workflow itself is hardened.

## Runtime verification

Generating signed attestations means nothing if nothing checks them at deploy. Patterns:

- **Kubernetes admission**: Kyverno, Sigstore policy-controller, Connaisseur — reject pods whose images lack a valid Cosign signature or required attestation. Related to [[k8s-admission-webhook-abuse]] (be aware of the admission layer's own attack surface).
- **Package manager verification**: `cosign verify` in CI before promotion to prod; npm package provenance (introduced 2023) shown on the registry.
- **Binary launch policies**: macOS notarization, Windows code signing, ELF signature checks — coarser than attestation verification but the user-visible enforcement layer.

## Common gaps (vendor marketing vs reality)

- **"We generate SBOMs"** with no ingestion pipeline. The SBOM sits in an artifact registry, never queried.
- **Attestations produced but never verified**. Build-side checkbox; deploy-side never enforces. Equivalent to logging without alerting ([[detection-engineering-pyramid-of-pain]]).
- **SBOM accuracy assumed**. Filesystem scanners miss statically linked deps; build-time generation is required for fidelity.
- **VEX flooded with "not affected"** with no review process — defenders stop trusting vendor VEX.
- **Federal compliance theater**. Vendors ship an SBOM PDF to satisfy a procurement question; useless for actual triage.
- **No source-to-binary link**. SBOM lists components but cannot prove the binary was built from the source commit it claims — that's what SLSA provenance solves, and most programs skip it.

## Regulatory drivers

- **US E.O. 14028** (2021) + OMB M-22-18 + NIST SP 800-218 (SSDF): federal-vendor self-attestation, SBOM required on request.
- **EU CRA** (Regulation 2024/2847): SBOMs for products with digital elements, vulnerability handling, 24-hour exploitation reporting. Enforcement window into 2027.
- **EU NIS2** ([[nis2-implementation]]): supply-chain risk management for essential and important entities.
- **US FDA** (Section 524B of FD&C Act, 2023): SBOM required for premarket medical device cybersecurity submissions.
- **Sectoral**: PCI DSS 4.0 ([[pci-dss-4-implementation]]) requires inventories of bespoke and custom software; financial regulators ([[financial-sector-defender-playbook]]) push third-party SBOM ingestion via DORA in the EU.

Treat these as the *floor*. The competitive differentiator is operational ingestion, not the SBOM itself.

## Defensive baseline

- Build-time SBOM generation in every build pipeline (CycloneDX recommended for internal use, SPDX where federal customers require).
- Central SBOM repository with continuous CVE matching (Dependency-Track or equivalent).
- Sigstore-signed provenance attestations for every release artifact (SLSA L2 minimum, L3 target).
- Admission-layer verification in Kubernetes and equivalent gates in non-K8s deploys.
- Third-party SBOM intake process in vendor onboarding ([[third-party-risk-management-practitioner]]).
- VEX ingestion and review workflow.
- Map components to deployments so a new CVE produces an actionable list of affected services.
- Tabletop a "new critical CVE in dependency X" scenario annually ([[tabletop-exercise-design-and-execution]]).

## Workflow to study

1. Pick a containerized service you own. Run Syft to generate SPDX and CycloneDX outputs. Diff them.
2. Run Grype or Trivy against the SBOM; triage results. Note any clear false positives from CPE mismatch.
3. Switch to build-time SBOM (Maven, npm, Gradle, or Go plugin). Compare component count and accuracy to the Syft scan.
4. Set up Dependency-Track locally, ingest the SBOM, observe continuous CVE matching.
5. In a GitHub Actions workflow, enable `actions/attest-build-provenance`. Verify with `gh attestation verify`.
6. Sign a container image with Cosign using GitHub OIDC; verify with `cosign verify` against the Rekor log.
7. Deploy Sigstore policy-controller to a kind cluster; configure a policy requiring the signature; demonstrate rejection of an unsigned image.
8. Generate a VEX statement for a known false-positive CVE and feed it back through Dependency-Track.
9. Cross-reference against [[case-study-solarwinds-2020]] and [[case-study-3cx-supply-chain]]: which controls in this workflow would have detected each compromise, and which would not?

Realistic effort: a single engineer can build the local lab in a week. Rolling it across an org with hundreds of services and dozens of vendors is a multi-quarter program with dedicated headcount, not a side project.

## Related

- [[cve-2024-3094-xz-utils-backdoor]]
- [[npm-postinstall-and-typosquat-audit]]
- [[python-pypi-supply-chain-audit]]
- [[go-module-substitution-audit]]
- [[github-actions-workflow-source-audit]]
- [[ghost-commit-smuggling]]
- [[case-study-3cx-supply-chain]]
- [[case-study-solarwinds-2020]]
- [[secure-sdlc-rollout-playbook]]
- [[appsec-maturity-checklist]]
- [[third-party-risk-management-practitioner]]
- [[nis2-implementation]]
- [[k8s-admission-webhook-abuse]]

## References

- SLSA framework, v1.0 specification — https://slsa.dev/spec/v1.0/
- in-toto attestation framework — https://github.com/in-toto/attestation
- Sigstore project documentation — https://docs.sigstore.dev/
- CycloneDX specification (OWASP) — https://cyclonedx.org/specification/overview/
- SPDX specification (Linux Foundation / ISO 5962) — https://spdx.dev/specifications/
- NTIA "The Minimum Elements for an SBOM" — https://www.ntia.gov/files/ntia/publications/sbom_minimum_elements_report.pdf
