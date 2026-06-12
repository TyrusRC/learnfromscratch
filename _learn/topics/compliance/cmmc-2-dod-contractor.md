---
title: CMMC 2.0 — DoD contractor cybersecurity
slug: cmmc-2-dod-contractor
---

> **TL;DR:** Cybersecurity Maturity Model Certification (CMMC) 2.0 is the US Department of Defense's framework requiring contractors handling Federal Contract Information (FCI) or Controlled Unclassified Information (CUI) to demonstrate cybersecurity practices. Three levels (1 self-assessment, 2 third-party C3PAO, 3 government-led). Final rule effective December 16, 2024; phased contract inclusion through 2028.

## What it is
CMMC consolidates US DoD cybersecurity requirements (DFARS 252.204-7012, NIST SP 800-171 Rev 2, NIST SP 800-172) into a tiered certification framework. Replaces the prior self-attestation model with verification appropriate to data sensitivity.

CMMC applies to the entire Defense Industrial Base (DIB) — ~300,000+ contractors, primes through subcontractors. Once in contracts, applies to all tiers handling FCI/CUI.

## Three levels

### Level 1 (Foundational)
- **Scope**: contractors handling Federal Contract Information (FCI) only
- **Requirements**: 17 basic cybersecurity practices from FAR 52.204-21
- **Assessment**: annual self-assessment + affirmation by senior official
- **No third-party validation** required

### Level 2 (Advanced)
- **Scope**: contractors handling Controlled Unclassified Information (CUI)
- **Requirements**: 110 practices aligned with NIST SP 800-171 Rev 2
- **Assessment**:
  - **Self-assessment** allowed for non-prioritised acquisition CUI (limited)
  - **C3PAO assessment** required for prioritised acquisition CUI (most contracts) — every 3 years
- C3PAO = CMMC Third Party Assessment Organization, accredited by CyberAB

### Level 3 (Expert)
- **Scope**: contractors handling CUI involving "highest-priority" DoD programs
- **Requirements**: Level 2 + subset of NIST SP 800-172 enhanced practices (~24 additional)
- **Assessment**: government-led (DIBCAC) every 3 years
- **Path**: must achieve Level 2 first; then DIBCAC assesses for Level 3

## Preconditions / where it applies

- Any business with a DoD contract or subcontract involving FCI or CUI
- DFARS 252.204-7012 clause already requires NIST 800-171 implementation; CMMC layers verification
- Subcontractors must achieve at least the level required by the prime
- Foreign suppliers in DIB also subject to CMMC if handling US CUI

## Implementation tradecraft

### Phase 1 — Determine required level

Read your DoD contract / RFP for CMMC level requirement. If unsure:
- FCI only → Level 1
- CUI handled → Level 2 (most common)
- CUI for high-priority programs (nuclear, missile defense, advanced aviation) → Level 3

CMMC requirements are flowed down from prime to subs.

### Phase 2 — Scope the CUI environment

Identify where CUI lives in your environment:
- Storage: file shares, databases, email, document management
- Processing: applications, services, scripts
- Transmission: email, FTP, APIs, removable media
- People: who has access, who needs access

Like PCI's CDE, scoping CUI environment reduces assessment burden. Enclave architectures (segmented CUI handling environment) are common.

### Phase 3 — Gap assessment against NIST SP 800-171 Rev 2

110 controls grouped in 14 families:
1. Access Control (AC) — 22 controls
2. Awareness and Training (AT) — 3
3. Audit and Accountability (AU) — 9
4. Configuration Management (CM) — 9
5. Identification and Authentication (IA) — 11
6. Incident Response (IR) — 3
7. Maintenance (MA) — 6
8. Media Protection (MP) — 9
9. Personnel Security (PS) — 2
10. Physical Protection (PE) — 6
11. Risk Assessment (RA) — 3
12. Security Assessment (CA) — 4
13. System and Communications Protection (SC) — 16
14. System and Information Integrity (SI) — 7

Each control scored on SPRS (Supplier Performance Risk System):
- Fully implemented = full points
- Partially implemented = partial points (varies by control)
- Not implemented = -5 / -3 / -1 points (varies by control criticality)

Max score = 110; minimum acceptable for Level 2 self-assessment = positive score with POAM closure plan.

### Phase 4 — Develop System Security Plan (SSP)

Mandatory document describing:
- Environment boundary
- Each control's implementation status
- Roles and responsibilities
- Architecture diagrams
- Data flows

SSP is the central CMMC artifact — auditor reviews it first, samples evidence after.

### Phase 5 — Plan of Action and Milestones (POAM)

For controls not fully implemented, document:
- Specific deficiency
- Remediation plan
- Resources required
- Target completion date

CMMC 2.0 allows limited POAMs for Level 2 self-assessment (some controls cannot be POAMed; e.g., MFA). Level 2 C3PAO and Level 3 have stricter POAM constraints.

### Phase 6 — Implement controls

Practical implementation patterns:
- **Identity**: MFA (FIDO2 preferred), least privilege, role-based access
- **Email**: GCC High or Microsoft 365 GCC for CUI-handling mail
- **File storage**: GCC, AWS GovCloud, Azure Government, properly classified
- **Network**: segmentation between CUI enclave and corporate
- **Endpoint**: managed via Intune Government or similar; encryption, FIPS-validated crypto
- **Logging**: collect, retain, monitor (AU family)
- **Incident response**: 72-hour CUI incident reporting to DoD (DIBnet)

### Phase 7 — Self-assessment or C3PAO assessment

- **Self-assessment**: complete via SPRS portal, senior official affirms, annual recurrence
- **C3PAO**: schedule with accredited C3PAO; assessment 1-2 weeks; report uploaded to eMASS

## Common architectural patterns

### Enclave model
Segment CUI handling to a dedicated environment (cloud or on-prem) isolated from broader corporate network. Smaller scope, faster assessment, cleaner controls. Most common pattern for small/medium DIB.

### Whole-organisation model
Apply CMMC controls org-wide. Easier compliance for small org where everything touches CUI; expensive for large org with mixed business lines.

### Managed services model
Outsource CUI handling to a managed services provider holding their own CMMC Level 2 / Level 3 certification (e.g., Microsoft GCC High, AWS GovCloud, Project Hosts). Shared responsibility — the provider's certification covers infrastructure, you cover your data and configuration.

Provider AoCs reference NIST SP 800-171 controls they implement; you map remaining controls.

## Common implementation pitfalls

- **Treating CMMC as IT problem only** — covers HR, physical, contracts, supply chain
- **Underestimating scope** — CUI in email attachments, archives, backups is in scope
- **Self-assessment without POAM honesty** — false attestation = False Claims Act exposure (significant)
- **GCC commercial vs GCC High confusion** — only GCC High meets requirements for most CUI; standard GCC insufficient
- **Subcontractor flow-down ignored** — primes must verify subcontractor compliance
- **Late certification** — C3PAO capacity limited; backlog likely as contracts include CMMC requirement

## Intersection with other frameworks

- **NIST SP 800-171 Rev 2** — CMMC Level 2 is essentially this with verification layered
- **NIST SP 800-172** — CMMC Level 3 enhanced practices
- **FedRAMP** — required for cloud service providers handling CUI; CMMC ≠ FedRAMP (different scope)
- **ISO 27001** — partial overlap; ISO 27001 alone doesn't satisfy CMMC
- **CMMC ≠ ITAR** — separate regimes; defence export-controlled tech may require both
- **DFARS 252.204-7012** — preceded CMMC; still active alongside

## Tooling

- **Microsoft GCC High** — preferred for many small/medium DIB
- **AWS GovCloud (US)** — alternative for cloud workloads
- **Azure Government** — equivalent for Microsoft-aligned shops
- **Project Hosts / iboss / others** — managed CMMC environments
- **Apptega / Hyperproof / Drata** — CMMC compliance platforms
- **SPRS portal** — official DoD self-assessment submission

## Cost reality

Small DIB Level 2 assessment cost (2025):
- Self-assessment + remediation: $50K-$200K depending on existing maturity
- C3PAO assessment: $50K-$150K + assessment fees ($30K-$80K)
- Annual maintenance: $20K-$100K depending on environment size

Many small DIB pursue cloud-managed environments (GCC High at $30+/user/month) to reduce internal complexity.

## OPSEC for compliance team

- SSP and POAM are sensitive: describe your defensive posture and gaps — CUI-equivalent confidential
- C3PAO assessment reports contain detailed findings — restrict access
- DoD CUI incident reports submitted to DIBnet within 72 hours; coordinate with legal
- False attestation under CMMC has been the subject of False Claims Act litigation — accuracy of self-assessment matters

## References
- [DoD CMMC site](https://dodcio.defense.gov/CMMC/)
- [CyberAB — CMMC Accreditation Body](https://cyberab.org/) — C3PAO listing
- [NIST SP 800-171 Rev 2](https://csrc.nist.gov/pubs/sp/800/171/r2/upd1/final)
- [NIST SP 800-172](https://csrc.nist.gov/pubs/sp/800/172/final)
- [DoD Project Spectrum](https://www.projectspectrum.io/) — small business education / Cyber Readiness Check

See also: [[nist-csf-2-implementation]], [[building-an-iso27001-isms-practitioner]], [[fedramp-authorization-process]], [[third-party-risk-management-practitioner]], [[hitrust-csf-implementation]], [[appsec-maturity-checklist]], [[soc2-vs-iso27001]]
