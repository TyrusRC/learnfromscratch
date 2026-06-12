---
title: PCI DSS 4.0 — Customised Approach
slug: pci-dss-4-customised-approach
---

> **TL;DR:** PCI DSS 4.0 introduces a **Customised Approach** alongside the traditional Defined Approach. Customised lets you meet the **Customised Approach Objective** of each requirement via alternative controls (not just the prescribed control), provided you document a Controls Matrix and pass a Targeted Risk Analysis. Powerful for mature security programs and cloud-native architectures; high overhead and not all requirements are eligible.

## What it is
For each PCI DSS 4.0 requirement, the standard specifies:
- **Customised Approach Objective** — what the requirement is trying to achieve
- **Defined Approach Requirement** — the prescribed implementation
- **Defined Approach Testing Procedures** — how a QSA validates the prescribed implementation
- **Customised Approach Objective** (sometimes phrased as eligibility note)

Customised Approach: the entity implements ANY control that meets the Objective, documents it, and proves effectiveness through a Controls Matrix and a Targeted Risk Analysis (TRA). The QSA then designs custom testing procedures.

## Preconditions / where it applies
- Entities with mature security programs that can document and demonstrate alternative controls
- Cloud-native architectures where prescribed PCI controls don't fit (e.g., AWS-native logging vs. local-host logging)
- ROC (Report on Compliance) entities — NOT available to SAQ-only entities (Self-Assessment Questionnaires use Defined only)
- Compensating Controls (CCs) still exist for narrow cases where Customised doesn't apply

## Eligibility

NOT every requirement is Customised-eligible. The PCI DSS 4.0 standard explicitly flags which requirements:
- **Customised eligible** — most technical requirements
- **NOT Customised eligible** — primarily policy/process requirements, organisational structure requirements, and some specific technical requirements (e.g., 3.5.1 strong cryptography is fixed)

Check Appendix E of the standard before assuming a requirement is eligible.

## Tradecraft

### Step 1 — Identify candidate requirements
For each requirement where the Defined Approach is awkward / expensive / impossible:
- Is it Customised-eligible? (Check standard)
- Can you articulate the Customised Approach Objective being met?
- Can you describe an alternative control that meets that Objective?

Typical candidates:
- Logging requirements where cloud-native services (CloudTrail, Azure Monitor) differ from prescribed format
- Network segmentation in container orchestrators where flat L3 isn't realistic
- Anti-malware requirements where modern EDR doesn't map to the prescribed "anti-virus"
- Patch management where ephemeral infrastructure replaces rather than patches

### Step 2 — Targeted Risk Analysis (TRA)
Document the alternative control:
- What's the prescribed control? What's the Objective?
- What's the proposed control?
- How does the proposed control achieve the Objective?
- What threats does the Objective address?
- How does the proposed control address those threats?
- Effectiveness evidence (testing, metrics)
- Residual risk + acceptance

Template-grade TRAs run 2-5 pages per requirement. PCI SSC publishes a TRA template for use in 12.3.x.

### Step 3 — Controls Matrix
A formal document mapping each customised requirement to:
- Defined Approach Requirement (verbatim)
- Customised Approach Objective (verbatim)
- Description of the implemented control
- Testing methodology proposed for QSA
- Frequency of testing / monitoring
- Evidence to be collected

The Controls Matrix is reviewed and approved by the QSA BEFORE assessment, not during. This is the biggest workflow change vs Defined Approach.

### Step 4 — QSA pre-engagement
For Customised entries, the QSA must:
- Validate Controls Matrix and TRA before formal assessment
- Design testing procedures (may differ per entity)
- Document evidence of effective control operation
- Justify the assessment opinion to PCI SSC

QSA fees for Customised typically higher; assessment time longer.

### Step 5 — Ongoing evidence
PCI DSS expects Customised Controls Matrix + TRA reviewed at least annually + after significant changes. Maintain evidence continuously, not just before the audit.

## Common Customised Approach examples

**Requirement 5.2 (Anti-malware)** — Defined says deploy anti-malware on commonly affected systems. Customised: cloud-native serverless workloads with attestation, immutable infrastructure, and runtime behavioural detection — Objective met without traditional AV.

**Requirement 8.3.6 (Account lockout)** — Defined says lock after N failed attempts. Customised: ML-based fraud detection that blocks at first anomalous attempt regardless of count — meets Objective of preventing brute force.

**Requirement 10.4 (Time synchronisation)** — Defined specifies NTP with specific configuration. Customised: cloud-provider native time service with documented accuracy + integrity — meets Objective.

**Requirement 11.4.1 (Penetration testing methodology)** — Defined is industry-accepted methodology + scope. Customised approach less common here; methodology requirements tend to stay Defined.

## When NOT to use Customised Approach

- SAQ-only entity (not eligible)
- First PCI DSS assessment cycle (high risk, learn Defined first)
- Limited mature documentation capability
- QSA team without Customised experience
- Most requirements are workable under Defined — selective Customised is the norm
- Time-constrained assessment (Customised adds weeks)

For most entities, the answer is: stay Defined for everything possible, use Customised for the 3-10 requirements where it materially helps.

## Customised vs Compensating Controls

PCI DSS still allows **Compensating Controls (CCs)** for cases where neither Defined nor Customised works:
- Compensating Control = narrow technical or business constraint prevents requirement; alternative control accepted with QSA judgment
- Customised Approach = entity prefers alternative implementation that meets the Objective; documented programmatically

CCs are reactive (constraint-driven); Customised is proactive (design choice). PCI SSC encourages migration from CCs to Customised where eligible.

## Common implementation pitfalls

- **TRA too thin** — auditors reject "we believe this is equivalent" without rigorous threat analysis
- **Controls Matrix missing testing procedures** — QSA can't validate without your proposed testing methodology
- **Pre-engagement skipped** — entity submits Customised in formal assessment without QSA pre-review → assessment delays
- **Customised applied to ineligible requirement** — wasted documentation effort
- **Annual review not done** — Controls Matrix and TRA aged out by next assessment cycle

## Strategic decision

Customised Approach is a strategic asset for:
- Cloud-native, container-native, serverless architectures
- Multi-tenant SaaS where shared infrastructure doesn't map to single-tenant requirements
- Microservices with attestation-based zero-trust where perimeter requirements don't apply
- Modernised orgs where prescribed controls reflect 2010-era data center thinking

For traditional data center + endpoints, Defined Approach is usually faster and cheaper.

## OPSEC for compliance team

- Controls Matrix is sensitive: describes what's defended and how — TLP:AMBER internal
- TRA documents residual risk and acceptance — board-visibility item
- QSA-approved Controls Matrix is contractually customer-disclosable for AOC review

## References
- [PCI DSS v4.0 standard](https://www.pcisecuritystandards.org/) — purchase + supplementary guidance
- [PCI SSC — Customised Approach Information Supplement](https://www.pcisecuritystandards.org/) — official methodology
- [PCI SSC — Targeted Risk Analysis Template](https://www.pcisecuritystandards.org/)
- [QSA companies (PCI SSC list)](https://www.pcisecuritystandards.org/assessors_and_solutions/) — for engagement
- [PCI DSS 4.0 Council documents library](https://www.pcisecuritystandards.org/document_library)

See also: [[building-a-pci-dss-program-practitioner]], [[pci-dss-4-implementation]], [[pci-qsa-career-track]], [[pci-saq-selection-and-scoping]], [[pci-cardholder-data-flow-mapping]], [[pci-3ds-and-p2pe-overlays]], [[iso-27002-2022-controls-catalog]], [[nist-csf-2-implementation]]
