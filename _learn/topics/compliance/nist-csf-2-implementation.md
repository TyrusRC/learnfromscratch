---
title: NIST CSF 2.0 — implementation
slug: nist-csf-2-implementation
---

> **TL;DR:** NIST Cybersecurity Framework 2.0 (released February 2024) adds a sixth function — **Govern** — to the original Identify/Protect/Detect/Respond/Recover, broadens applicability beyond US critical infrastructure to all organisations, and ships implementation examples, informative references, and Tiers. Practitioner work is mapping organisational outcomes to Categories/Subcategories, scoring current/target Tiers, and producing a Profile-driven roadmap.

## What it is
CSF is voluntary, outcome-based, technology-neutral, and risk-based. Structure:
- **6 Functions** — Govern (GV, NEW in 2.0), Identify (ID), Protect (PR), Detect (DE), Respond (RS), Recover (RC)
- **23 Categories** — e.g., GV.OC (Organisational Context), PR.AA (Identity & Access)
- **106 Subcategories** — outcome statements ("authentication is managed for the workforce")
- **Implementation Examples** — concrete actions per Subcategory (NEW in 2.0)
- **Informative References** — links to ISO 27001/27002, NIST SP 800-53, CIS Controls, COBIT, etc.

Plus:
- **Tiers** — 1 Partial, 2 Risk Informed, 3 Repeatable, 4 Adaptive
- **Profiles** — current-state and target-state Subcategory selections + Tiers
- **Quick Start Guides** — by use case (small business, supply chain, comms sector, AI)

## What's new in 2.0 vs 1.1

- **Govern function** — risk strategy, roles, policy, cybersecurity supply-chain risk management (formerly scattered)
- **Supply chain integrated** as a Category under Govern (GV.SC), not standalone
- **Broader applicability** — "for organisations of all sizes and sectors" rather than critical infrastructure focus
- **Implementation Examples + Informative References** machine-readable (CSV/JSON)
- **CSF Tools** — NIST's online navigator + community-contributed mappings
- **AI explicit** — referenced in GV.RR and ID.RA

## Preconditions / where it applies
- Voluntary baseline for any organisation — no regulator forces CSF directly, but used as reference by many
- Federal contractors: increasingly required via FAR clauses
- Cyber insurance: insurers reference CSF maturity for premium discounts
- Boards: CSF Tier reporting is a common board-level KPI

## Implementation tradecraft

### Step 1 — Scope and prioritise
Define the system or business unit. CSF supports multiple Profiles per org (corporate IT, OT environment, customer-facing product). Don't try to apply one Profile to the whole organisation if risk profiles differ.

### Step 2 — Current Profile
Map your existing controls to each Subcategory:
- ✅ Fully implemented
- ⚠️ Partial / ad-hoc
- ❌ Not implemented
- N/A — justified exclusion

Source evidence: policies, screenshots, control inventory, audit reports. CSF doesn't require evidence at this maturity-self-assessment stage but auditors will want it.

### Step 3 — Tier scoring
Per Function (or Category for fine-grained):

| Tier | Risk Mgmt Process | Integrated Risk Mgmt | External Participation |
|---|---|---|---|
| 1 Partial | Ad-hoc, reactive | None | None |
| 2 Risk Informed | Some processes documented | Aware but no org-wide | Receive intel, no share |
| 3 Repeatable | Formal policies, regular review | Embedded across org | Share + receive intel |
| 4 Adaptive | Continuous improvement based on lessons | Continuous learning culture | Active collaboration |

Most enterprises target Tier 3 across most Functions; Tier 4 in Detect/Respond is realistic for mature SOCs.

### Step 4 — Target Profile
Choose target maturity per Subcategory based on:
- Threat model — adversary capability vs business impact
- Regulatory drivers (HIPAA, PCI, DORA, etc.)
- Risk appetite stated by board
- Resource constraints — don't target Tier 4 across the board

### Step 5 — Gap analysis + roadmap
For each gap (target − current), build remediation:
- Effort estimate (FTE-quarters, $$$)
- Dependencies
- Quick wins (Subcategories with low effort, high impact) vs. multi-year programs
- Owner per Category

### Step 6 — Continuous review
Annual reassessment minimum; quarterly for high-velocity orgs. Post-incident: lessons learned trigger Subcategory re-scoring.

## Key Subcategories often under-implemented

- **GV.SC-08** — cybersecurity supply chain risk roles, responsibilities, authorities (post-SolarWinds priority)
- **GV.OV-03** — cybersecurity risk management performance measured and reviewed
- **ID.AM-08** — systems, hardware, software, and data are managed throughout their life cycles
- **PR.AA-05** — access permissions, entitlements, and authorisations defined / reviewed
- **DE.AE-08** — incidents are declared when adverse events meet defined incident criteria
- **RS.MA-05** — criteria for initiating recovery is applied (often missing — when does IR hand off to recovery?)
- **RC.CO-04** — public updates use approved methods and messaging

## Mapping to other frameworks

CSF 2.0 publishes machine-readable mappings to:
- ISO/IEC 27001:2022 + 27002:2022
- NIST SP 800-53 Rev 5 (control catalog the Feds use)
- NIST SP 800-171 (CUI controls — required by CMMC)
- CIS Critical Security Controls v8
- PCI DSS v4.0
- HIPAA Security Rule
- COBIT 2019

Practical use: pick the "lead" framework you'll be audited against (e.g., ISO 27001 for ISMS, PCI DSS for cardholder, SOC 2 for SaaS) and use CSF as the cross-cutting governance/board reporting layer.

## Tooling

- **NIST CSF Tool** (csrc.nist.gov) — official online navigator with example searches
- **CSF Reference Tool** — desktop / Excel companion
- **Community Profiles** — sector-specific starting points (manufacturing, election security, smart grid)
- **AuditBoard / ZenGRC / OneTrust** — commercial GRC platforms with CSF templates
- **Open-source: SecureCodeBox, Eramba** — for smaller orgs

## Common pitfalls

- **Vanity Tiers** — claiming Tier 3 without evidence; first auditor review knocks it back to Tier 2
- **One-shot assessment** — CSF is a continuous-improvement framework; year-2 reassessment without action items wastes the year-1 effort
- **Ignoring Govern** — CSF 2.0 makes governance explicit. Skipping it (because "security is technical") leaves Risk Management Strategy unaddressed
- **Subcategory cherry-picking** — selecting only the easy Subcategories for Current Profile to claim higher coverage. Auditors detect this via cross-reference
- **Confusing CSF with audit standard** — CSF is a framework, not a certifiable standard (unlike ISO 27001). No "NIST CSF certificate" exists; attestations are self-claimed

## OPSEC for compliance team

- Keep current Profile + evidence in version control or GRC platform with audit trail
- For board reporting: heatmap of Function × Tier (current vs target) is the standard visual
- Be precise on Tier scoring rationale — "Tier 3 because policy documented + reviewed annually" not "Tier 3 because we feel mature"
- Map every regulator reporting line: CMMC 2.0 maps to NIST SP 800-171 which CSF references — so CSF mapping evidence partially satisfies CMMC

## References
- [NIST Cybersecurity Framework 2.0 (PDF)](https://nvlpubs.nist.gov/nistpubs/CSWP/NIST.CSWP.29.pdf)
- [NIST CSF 2.0 Reference Tool](https://www.nist.gov/cyberframework/csf-20-reference-tool)
- [Quick Start Guides](https://www.nist.gov/cyberframework/quick-start-guides)
- [CSF Tool (informal community)](https://csf.tools/)
- [Cybersecurity Framework Profiles repository](https://www.nist.gov/cyberframework/profiles)

See also: [[building-an-iso27001-isms-practitioner]], [[soc2-vs-iso27001]], [[dora-eu-implementation]], [[nis2-implementation]], [[pci-dss-4-implementation]], [[third-party-risk-management-practitioner]], [[appsec-maturity-checklist]], [[vulnerability-management-lifecycle]], [[ciso-vciso-track]], [[policy-and-standards-writing]]
