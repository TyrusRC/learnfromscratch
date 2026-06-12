---
title: HITRUST CSF — implementation
slug: hitrust-csf-implementation
---

> **TL;DR:** HITRUST Common Security Framework (CSF) is a risk- and compliance-management framework primarily used in US healthcare. Maps ISO 27001, NIST, HIPAA, PCI DSS, and others into a single assessment. Three assurance levels (e1, i1, r2) with corresponding rigor. Required or preferred by many large US healthcare systems for vendor onboarding. Now expanded beyond healthcare via HITRUST Alliance.

## What it is
HITRUST started in 2007 as the Health Information Trust Alliance to consolidate compliance burden for healthcare entities. The framework cross-references over 40 sources (HIPAA Security Rule, HIPAA Privacy Rule, NIST 800-53, ISO 27001, PCI DSS, COBIT, state privacy laws). A single HITRUST assessment satisfies multiple compliance requirements.

Current version: HITRUST CSF v11.x. Updates released annually with new authoritative source mappings.

## Assurance levels (post-2022 model)

| Level | Rigor | Use case |
|---|---|---|
| **e1 (Essentials)** | 44 requirements, 1-year cert | Foundational baseline; smaller orgs, lower-risk |
| **i1 (Implemented)** | 182 requirements, 1-year cert | Best practice implementation; "good security" |
| **r2 (Risk-based, 2-year)** | 200-1,800+ requirements (tailored), 2-year cert | Risk-tailored, most rigorous; what large healthcare systems require |

The r2 is the historic HITRUST CSF assessment — comprehensive, expensive, the gold standard in healthcare assurance.

The e1 and i1 introduced in 2022 to provide cheaper, faster entry points and address growing demand from smaller / lower-risk vendors.

## Preconditions / where it applies

- Healthcare entities (providers, payers, pharma, medical device) and their business associates
- US-centric primarily; expanding internationally
- Vendor onboarding requirement: many large US health systems (Cleveland Clinic, Kaiser, etc.) require HITRUST from vendors handling PHI
- Insurance: cyber insurance carriers sometimes discount HITRUST-certified entities

## Framework structure

HITRUST CSF organises ~150 control objectives across 19 domains:

1. Information Protection Program
2. Endpoint Protection
3. Portable Media Security
4. Mobile Device Security
5. Wireless Security
6. Configuration Management
7. Vulnerability Management
8. Network Protection
9. Transmission Protection
10. Password Management
11. Access Control
12. Audit Logging & Monitoring
13. Education, Training and Awareness
14. Third Party Assurance
15. Incident Management
16. Business Continuity & Disaster Recovery
17. Risk Management
18. Physical & Environmental Security
19. Data Protection & Privacy

Each control objective has Level 1 / Level 2 / Level 3 implementation specifications, scaled by risk.

## Risk-tailored model (r2 specific)

Unlike most frameworks, HITRUST r2 tailors required controls based on:
- Organisation type (Covered Entity, Business Associate, etc.)
- Data type processed (PHI, PCI, government data)
- System complexity
- Geographic scope
- Regulatory factors (specific state laws applicable)

After completing the risk factor questionnaire, HITRUST MyCSF tool selects which control requirements apply to your organisation. Smaller orgs may have 200 requirements; large healthcare systems may have 1,800+.

## Implementation tradecraft

### Phase 1 — MyCSF subscription + scoping (Month 1)

- Subscribe to MyCSF (HITRUST's compliance platform; required for any HITRUST assessment)
- Define scope (systems, services, business units)
- Complete risk factor questionnaire to determine applicable controls

### Phase 2 — Self-assessment + gap analysis (Months 1-3)

For each applicable control, score implementation maturity:
- **PRISMA-based scoring**: Policy, Process, Implemented, Measured, Managed
- Each scored 0-100% completeness
- HITRUST requires evidence for every claim

Gap analysis identifies remediation needs before formal assessment.

### Phase 3 — Remediation (Months 3-9)

Address gaps; build documented policies and procedures; implement technical controls. HITRUST is heavy on documentation — Policy and Process maturity scoring requires written, approved, distributed documents.

### Phase 4 — Internal assessment

Self-rate maturity scores against evidence. Submit through MyCSF for review.

### Phase 5 — External validated assessment (i1, r2)

HITRUST Assessor (CPA firm or specialist) performs:
- Documentation review
- Control testing
- Interview sampling
- Walkthrough
- Evidence verification

Assessor uploads results to MyCSF; HITRUST quality review process validates and issues certification.

### Phase 6 — Interim assessment + certification renewal

- **r2**: certification valid 2 years; interim assessment at 1-year mid-point
- **i1**: certification valid 1 year; full re-assessment annually
- **e1**: certification valid 1 year; rapid re-assessment

## Inheritance and shared responsibility

HITRUST supports inheritance: cloud providers (AWS, Azure, GCP, ServiceNow) hold HITRUST certifications; customers can inherit controls implemented at the provider level. Documented inheritance reduces customer scope by 30-50% on cloud-heavy environments.

Inheritance must be documented per control with specific reference to the provider's HITRUST certification scope.

## HITRUST vs HIPAA

Common confusion. They're related but distinct:
- **HIPAA** is law (regulations under HHS); compliance is required for covered entities and business associates
- **HITRUST** is a framework; certification is voluntary
- HITRUST certification is strong evidence of HIPAA Security Rule compliance, but doesn't replace HIPAA compliance work (e.g., Privacy Rule has aspects HITRUST doesn't cover deeply)
- HHS doesn't recognise HITRUST as auto-compliance, but treats certification favourably in investigations

Many healthcare orgs use HITRUST as the operational framework to systematically implement HIPAA.

## HITRUST + SOC 2

HITRUST and SOC 2 are sometimes combined:
- **HITRUST CSF** — defines the controls
- **SOC 2** — auditor opinion on whether controls operate effectively

Combined HITRUST + SOC 2 attestation possible through some assessors — single audit, two deliverables.

## HITRUST vs ISO 27001

| Aspect | HITRUST CSF | ISO 27001 |
|---|---|---|
| Origin | US healthcare | International |
| Cross-mapping | 40+ frameworks pre-mapped | Manual mapping required |
| Risk tailoring | Built-in factor-based | Self-determined risk assessment |
| Healthcare focus | Primary | Generic |
| Cost | Higher (especially r2) | Lower |
| Recognition | US healthcare strong | Global, multi-sector |

US healthcare contracts: HITRUST often preferred. International or non-healthcare: ISO 27001.

## Cost reality

- **MyCSF subscription**: $15K-$50K+/year depending on scope
- **e1 assessment**: $30K-$80K
- **i1 assessment**: $50K-$150K
- **r2 assessment**: $200K-$1M+ (large orgs)
- **Remediation**: highly variable

HITRUST is among the most expensive frameworks; investment is justified by US healthcare market access.

## Common implementation pitfalls

- **Underestimating documentation requirements** — Policy + Process maturity require formal written documents, version-controlled, approved
- **Missing inherited control documentation** — inheritance not documented = lost scope reduction
- **Scoping too broadly** — claiming "whole organisation" when only PHI-handling business units need to be in scope drives cost up
- **MyCSF data quality** — sloppy data entry into MyCSF surfaces during HITRUST quality review; iterations add weeks
- **HIPAA / state law gap** — HITRUST is comprehensive but state-specific laws (e.g., CCPA, NY SHIELD) need separate consideration

## Recent updates

- 2022: introduced e1, i1 levels
- 2023: HITRUST CSF v11 with new AI risk considerations
- 2024-2025: expanded authoritative source mappings (NIS2, DORA referenced for international HITRUST users)
- 2025: HITRUST AI Risk Management Framework (new product complementing CSF)

## OPSEC for compliance team

- Risk factor questionnaire describes organisational vulnerabilities and exposures — TLP:AMBER
- MyCSF contains detailed control implementation evidence — access-controlled
- HITRUST certification letter is shareable externally
- Internal score breakdown is sensitive (where you scored low) — don't expose

## References
- [HITRUST Alliance](https://hitrustalliance.net/)
- [MyCSF platform](https://hitrustalliance.net/mycsf/)
- [HITRUST CSF Framework](https://hitrustalliance.net/hitrust-csf/) — purchase / subscription required
- [HHS — HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)
- [HIMSS — healthcare compliance practitioner resources](https://www.himss.org/)

See also: [[hipaa-security-rule]], [[nist-csf-2-implementation]], [[iso-27002-2022-controls-catalog]], [[soc2-auditor-track]], [[soc2-vs-iso27001]], [[fedramp-authorization-process]], [[cmmc-2-dod-contractor]], [[third-party-risk-management-practitioner]], [[ciso-vciso-track]]
