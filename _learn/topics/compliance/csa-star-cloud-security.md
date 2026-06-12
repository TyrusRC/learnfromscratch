---
title: CSA STAR — cloud security assurance
slug: csa-star-cloud-security
---

> **TL;DR:** Cloud Security Alliance (CSA) Security, Trust, Assurance and Risk (STAR) is the leading cloud-specific assurance program. Built around the Cloud Controls Matrix (CCM), STAR offers three levels — self-assessment (free, public), third-party certification, and continuous monitoring. Standard reference for cloud vendor due diligence; reflected in ISO 27017 and complements ISO 27001/27018/27701.

## What it is
CSA STAR is a publicly accessible registry of cloud security postures based on CCM v4 (current). It standardises how cloud providers describe their security to customers, reducing the vendor security questionnaire burden.

Three components:
- **CCM** — control framework (197 controls across 17 domains in v4)
- **CAIQ** — Consensus Assessments Initiative Questionnaire; the assessment instrument
- **STAR Registry** — public listing of submitted assessments

## STAR levels

### Level 1 — Self-Assessment
- Provider completes CAIQ + uploads to STAR Registry
- Free, public, voluntary
- Self-attested
- Useful baseline; widely used (~700+ entries)

### Level 2 — Third-Party Certification

Two paths:
- **STAR Certification** — built on ISO 27001 + CCM additional requirements; third-party certified by accredited assessor
- **STAR Attestation** — built on SOC 2 + CCM; AICPA-style attestation
- **C-STAR** (China-specific) — combined with GB/T 22080 (China's ISO 27001 equivalent)

### Level 3 — Continuous Monitoring (Continuous Auditing)
- Quasi-real-time evidence flow to assessor / registry
- Earliest implementations 2024-2025
- Aim: move from snapshot annual audits to continuous attestation

## Preconditions / where it applies

- Cloud service providers seeking to demonstrate security posture to customers
- Cloud customers using STAR Registry to evaluate vendors
- Internal cloud teams using CCM as a control framework
- Government cloud procurement processes (some reference CCM)

## CCM v4 structure (17 domains)

1. Audit & Assurance (A&A)
2. Application & Interface Security (AIS)
3. Business Continuity Management and Operational Resilience (BCR)
4. Change Control and Configuration Management (CCC)
5. Cryptography, Encryption and Key Management (CEK)
6. Datacenter Security (DCS)
7. Data Security and Privacy Lifecycle Management (DSP)
8. Governance, Risk Management and Compliance (GRC)
9. Human Resources (HRS)
10. Identity & Access Management (IAM)
11. Interoperability & Portability (IPY)
12. Infrastructure & Virtualization Security (IVS)
13. Logging and Monitoring (LOG)
14. Security Incident Management, E-Discovery, & Cloud Forensics (SEF)
15. Supply Chain Management, Transparency, and Accountability (STA)
16. Threat & Vulnerability Management (TVM)
17. Universal Endpoint Management (UEM)

CCM v4 added more depth on AI/ML, supply chain, and DevSecOps compared to v3.

## CCM ↔ other framework mappings

CCM published with cross-mappings to:
- ISO/IEC 27001 / 27002 / 27017 / 27018
- NIST SP 800-53 Rev 5
- PCI DSS 4.0
- HIPAA Security Rule
- GDPR
- CIS Controls v8
- FedRAMP Moderate / High

These mappings make CCM a useful "Rosetta Stone" for multi-framework cloud compliance.

## Implementation tradecraft (provider)

### Step 1 — Pick level appropriate to customer demand

- Small CSP: Level 1 self-assessment for visibility
- Mid/large CSP serving enterprise: Level 2 attestation or certification
- Highly regulated CSP (FedRAMP, HITRUST, PCI): combine with relevant other frameworks; STAR is one piece

### Step 2 — Complete CAIQ honestly

CAIQ has 261 questions in v4. Yes/No/NA answers with comments. Auditors and customers review the comments more than the yes/no — depth matters.

Honest answers + visible gaps + remediation plan > inflated answers found wanting in audit.

### Step 3 — Choose Level 2 attestation vs certification

| Attribute | STAR Certification | STAR Attestation |
|---|---|---|
| Foundation | ISO 27001 | SOC 2 |
| Auditor | ISO accredited CB | CPA firm |
| Geographic preference | Outside North America often | North America often |
| Report style | Compliance certificate | Examination report |
| Recurring | Annual + 3-year cycle | Annual |

Pick based on customer audience expectations.

### Step 4 — Publish on STAR Registry

For Level 1: upload completed CAIQ.

For Level 2: assessor uploads attestation/certification artifact.

### Step 5 — Continuous improvement

Update STAR submission on material changes (architecture shifts, new services, control improvements). Stale registry entries reduce customer trust.

## Implementation tradecraft (customer)

### Step 1 — Search registry

STAR Registry searchable at cloudsecurityalliance.org/star/registry. Filter by service type, certification level, region.

### Step 2 — Compare CAIQ responses

Cross-vendor comparison: how does AWS vs Azure vs GCP answer the same CAIQ question? Often surfaces material differences.

### Step 3 — Reuse for vendor risk assessment

CAIQ + STAR certification can satisfy substantial portions of your internal vendor security questionnaire. Significant time savings.

### Step 4 — Reference in contracts

Pre-procurement: require Level 2 STAR (or equivalent) in vendor selection. Post-procurement: contract clauses reference maintenance of STAR status.

## STAR + other cloud security programs

- **ISO 27017** — code of practice for cloud security; CCM aligns with 27017 controls
- **ISO 27018** — cloud privacy code; complements STAR Level 2 attestation
- **ISO 27701** — privacy management; STAR-Privacy add-on covers privacy controls
- **FedRAMP** — US federal cloud authorisation; CCM cross-mapped to NIST 800-53
- **TX-RAMP** — Texas state government cloud security; CCM-aligned
- **C-STAR** — China-specific
- **CISPE Code of Conduct** — European cloud data protection code; complements STAR

CCM is often the operational framework providers use; framework-specific certifications layer on top.

## Common implementation pitfalls

- **CAIQ marketing** — providers using CAIQ as marketing instrument rather than honest assessment; customers see through inflated answers
- **Stale STAR submissions** — registry entry 3+ years old without updates raises questions
- **Mismatch between STAR and reality** — provider passes audit but operations drift; periodic internal re-validation needed
- **Skipping mappings** — failing to map CCM controls to other frameworks duplicates compliance effort
- **Misunderstanding shared responsibility** — STAR captures provider's controls; customer responsibility for configuration / data classification / IAM remains

## Common control patterns surfaced by CAIQ

- Encryption key management: customer-managed keys vs provider-managed; HSM availability
- Logging: customer access to provider logs; immutability; retention
- Forensics: provider cooperation on incidents; chain-of-custody
- Supply chain: provider's subprocessor disclosure; change notification
- Data location: data residency commitments; sovereignty
- Egress: data portability and exit; format and timeline
- Vulnerability disclosure: provider's PSIRT process

These reflect the cloud-specific concerns NOT well-covered by generic ISO 27001 / SOC 2 — STAR's value lies in this cloud focus.

## OPSEC for compliance / cloud team

- CAIQ answers are PUBLIC if Level 1; review carefully before publishing
- Customer reuse of CAIQ may go beyond intended scope — restrict to relevant services
- Internal "CCM scorecard" describing actual vs documented control state is sensitive (TLP:AMBER)
- Subprocessor disclosures via CAIQ are competitive intelligence to be considered

## References
- [CSA STAR Registry](https://cloudsecurityalliance.org/star/registry)
- [Cloud Controls Matrix v4](https://cloudsecurityalliance.org/research/cloud-controls-matrix)
- [CAIQ v4](https://cloudsecurityalliance.org/research/cloud-controls-matrix)
- [STAR Certification](https://cloudsecurityalliance.org/star/certification/) — process documentation
- [ISO/IEC 27017:2015](https://www.iso.org/standard/43757.html) — cloud security code of practice
- [ISO/IEC 27018:2019](https://www.iso.org/standard/76559.html) — PII in cloud
- [CSA Cloud Security Knowledge (CCSK) certification](https://cloudsecurityalliance.org/education/ccsk/) — practitioner credential

See also: [[iso-27002-2022-controls-catalog]], [[iso-27701-privacy-extension]], [[building-an-iso27001-isms-practitioner]], [[soc2-vs-iso27001]], [[fedramp-authorization-process]], [[hitrust-csf-implementation]], [[cloud-iam-misconfig-patterns]], [[third-party-risk-management-practitioner]], [[zero-trust-architecture-practitioner]]
