---
title: DORA (EU Digital Operational Resilience Act) — implementation
slug: dora-eu-implementation
---

> **TL;DR:** DORA (Regulation 2022/2554) is the EU's binding framework for ICT operational resilience in financial entities. In force since 17 January 2025. Applies to banks, insurers, investment firms, crypto-asset service providers, plus critical third-party ICT providers (cloud, SaaS). Practitioner work: ICT risk management, incident reporting, resilience testing (TLPT every 3 years for "significant" firms), and third-party register.

## What it is
DORA harmonises ICT resilience requirements across 27 EU member states. Previously each national regulator (BaFin, AMF, CSSF, FCA-equiv, etc.) had divergent rules; DORA replaces them with a single regulation directly applicable, complemented by Regulatory Technical Standards (RTS) and Implementing Technical Standards (ITS) developed by the European Supervisory Authorities (ESAs — EBA, EIOPA, ESMA).

## Preconditions / where it applies
- Financial entity established in the EU OR providing services into the EU
- ICT third-party provider (Tier 1+: cloud, SaaS, dedicated trading platforms, data analytics)
- Effective scope cascades: a US-based fintech with EU customers must comply through their EU subsidiary or designate an EU representative
- Microenterprises (<10 employees AND ≤€2M revenue) have proportional simplifications, NOT exemption

## Five pillars

### Pillar 1 — ICT risk management framework
- Board-approved ICT strategy aligned with business strategy
- Risk register covering identification, protection, detection, response, recovery
- ICT asset inventory ("information assets" mapped to business processes)
- BIA + RTO/RPO per critical function
- Annual review minimum, post-incident review mandatory

### Pillar 2 — ICT-related incident reporting
**Classification thresholds** (RTS on classification, in force):
- **Major incident** — multiple criteria thresholds (clients affected, duration, geographic scope, data integrity, economic impact, criticality of service)
- **Significant cyber threat** — separate category, voluntary reporting
- **Recurring incidents** — aggregate small incidents may breach major threshold

**Timelines** (RTS on reporting):
- **Initial notification** — within 4 hours of classification as major (and 24 hours of detection)
- **Intermediate report** — within 72 hours of initial
- **Final report** — within 1 month

Reports go to the firm's competent authority (e.g., BaFin for German entities) via a harmonised template. ESAs forward to ENISA, ECB, ESRB.

### Pillar 3 — Digital operational resilience testing
- Annual basic testing programme: vulnerability scans, scenario-based tests, source-code reviews, penetration tests
- **TLPT (Threat-Led Penetration Testing) every 3 years** for "significant" financial entities (designation criteria in RTS) — based on the **TIBER-EU framework**
- TLPT involves real-world threat scenarios, red-team execution against production systems with regulator oversight
- Testing scope must cover critical / important ICT systems

### Pillar 4 — ICT third-party risk
**Register of all ICT third-party arrangements** — mandatory, format prescribed:
- Provider identity, services, criticality classification, sub-contractor chain
- Contractual provisions required by Article 30 (access rights, exit strategy, data location, audit rights, monitoring)
- Submit register annually to competent authority

**Critical ICT Third-Party Providers (CTPPs)** — designated by ESAs based on systemic importance. Subject to direct EU oversight (think: AWS, Microsoft, Google for EU banking). First designations: 2025.

### Pillar 5 — Information sharing
Voluntary cyber threat intelligence sharing between financial entities. ENISA supports infrastructure; participation is encouraged not required.

## Implementation roadmap

| Quarter | Deliverable |
|---|---|
| Q1 | Gap assessment against DORA Articles 5-25, baseline maturity score |
| Q2 | Update ICT risk management framework, asset inventory, BIA |
| Q3 | Build third-party register, classify all providers, identify CTPPs in supply chain |
| Q4 | Update contracts with critical providers (Article 30 clauses) — usually requires renegotiation |
| Y2 Q1 | Incident classification + reporting playbook, tabletop drill |
| Y2 Q2 | First TLPT scoping if "significant" firm — engage TIBER-EU framework |
| Y2 Q3-Q4 | TLPT execution + remediation |
| Y3+ | Annual cycle |

## Common implementation pitfalls

- **Article 28 register** — many firms have a vendor list but not the depth DORA requires (sub-contractors, data flows, country of processing)
- **Contract gap** — pre-existing standard hyperscaler contracts don't include all Article 30 clauses; addenda required
- **TLPT vs. ordinary pentest** — TLPT is regulator-driven, red-team led, production-targeted, lasts months. Conflating with annual pentest underestimates effort 10×
- **Microenterprise reliance** — exemption is narrow, not "small bank" — most regulated entities don't qualify
- **Cross-border reporting** — branches in multiple EU states report to home authority but obligations differ; map per-jurisdiction

## Intersection with other frameworks

- **NIS2** (Directive 2022/2555) — broader scope (essential / important entities across many sectors). DORA is lex specialis for financial sector; NIS2 covers the rest. Some firms fall under both; DORA prevails for ICT incident reporting per Article 1(2)
- **PSD3 / PSR** — payment-services-specific resilience overlaps
- **GDPR** — separate data-breach notification regime; a single incident may trigger both DORA (ICT) and GDPR (personal data)
- **ISO 27001** — useful baseline but does NOT satisfy DORA — gap in third-party register depth, incident-reporting timelines, TLPT

## TLPT vs TIBER-EU vs CBEST

- **TIBER-EU** — framework published by ECB; voluntary before DORA, mandatory under DORA for significant firms
- **CBEST** — Bank of England's UK equivalent (UK left EU; no longer DORA-bound but equivalence MoUs exist)
- **TLPT** — DORA's term for the testing exercise; uses TIBER-EU methodology with mandatory regulator participation

The actual red-team execution follows [[osep-ad-attack-chain-walkthrough]] / red-team engagement shape ([[red-team-vs-pentest-engagement-shape]]) — but governance overhead (threat intelligence package, white team, regulator briefings) is significantly higher.

## OPSEC for compliance team

- Document every decision in the gap assessment with rationale + evidence — DORA inspections request this
- Maintain incident classification log even when threshold is NOT met — auditors verify the classification logic
- TLPT scoping document is treated as TLP:RED — leak to test target = exam invalidation + reputation hit
- Third-party register is a living document; quarterly review minimum or annual + change-triggered
- Designate the "DORA-Officer" role (or equivalent — there's no mandated title) for inspection point-of-contact

## References
- [Regulation (EU) 2022/2554 (DORA)](https://eur-lex.europa.eu/eli/reg/2022/2554/oj)
- [ESA Joint Committee — RTS / ITS portal](https://www.eba.europa.eu/publications-and-media/press-releases)
- [ECB TIBER-EU framework](https://www.ecb.europa.eu/paym/cyber-resilience/tiber-eu/html/index.en.html)
- [EIOPA DORA microsite](https://www.eiopa.europa.eu/)
- [Practitioner: KPMG / PwC / EY DORA implementation guides](https://kpmg.com/)

See also: [[nis2-implementation]], [[building-an-iso27001-isms-practitioner]], [[soc2-vs-iso27001]], [[third-party-risk-management-practitioner]], [[nist-csf-2-implementation]], [[tabletop-exercise-design-and-execution]], [[red-team-vs-pentest-engagement-shape]], [[vulnerability-management-lifecycle]], [[gdpr-incident-implications]], [[iso-22301-business-continuity]], [[iso-27002-2022-controls-catalog]]
