---
title: SOC 2 vs ISO 27001 — practitioner's view
slug: soc2-vs-iso27001
aliases: [soc2-iso27001-comparison, audit-frameworks]
---

> **TL;DR:** SOC 2 and ISO 27001 are the two dominant general-purpose security audit frameworks. SOC 2 (AICPA) is a US-origin attestation against five Trust Services Criteria (Security required, plus optional Availability, Confidentiality, Processing Integrity, Privacy). ISO 27001 is a globally-recognised certification with mandatory ISMS (Information Security Management System) and a defined set of controls in Annex A. They overlap ~80% in controls but differ in process, audience, and cost. Companion to [[pci-dss-4-implementation]] and [[appsec-maturity-checklist]].

## Why this question matters

- SaaS vendors selling to enterprises are typically asked for one or both.
- "SOC 2 Type II" is the de-facto US-market sales requirement.
- "ISO 27001" is the de-facto EU / international requirement.
- Building one and mapping to the other is the cost-efficient path.
- Both are stepping-stones to more specific regimes (FedRAMP, PCI DSS).

## Quick comparison

| Aspect | SOC 2 | ISO 27001 |
|--------|-------|-----------|
| Origin | AICPA (US) | ISO/IEC (global) |
| Output | Attestation report | Certification |
| Frequency | Annual (Type II covers a period) | 3-year cycle (yearly surveillance) |
| Auditor | Licensed CPA | Accredited certification body |
| Scope | Selected TSCs | Whole ISMS |
| Cost | ~$20k–100k | ~$30k–150k |
| Audience | US enterprise buyers | International buyers, EU, gov |
| Report | Detailed test of controls | Certificate + scope statement |
| ISMS required? | No (but helpful) | Yes (mandatory) |

## SOC 2 in detail

### Trust Services Criteria (TSCs)

- **Security** — required for all SOC 2 reports.
- **Availability** — uptime / DR commitments.
- **Confidentiality** — protection of confidential info.
- **Processing Integrity** — processing accuracy / completeness.
- **Privacy** — personal info handling per organisation's commitments.

Most SaaS get Security + Availability; some add Confidentiality.

### Type I vs Type II

- **Type I** — point-in-time. Cheaper, faster, less impressive.
- **Type II** — over a period (typically 6 months minimum, 12 months for renewal). What enterprise buyers actually want.

### Report structure

- Service description.
- Management assertion.
- Auditor's opinion.
- Description of controls.
- Tests of controls (Type II only).
- Results of tests.

### Common control categories (CC series)

- CC1 — control environment.
- CC2 — communication.
- CC3 — risk assessment.
- CC4 — monitoring.
- CC5 — control activities.
- CC6 — logical / physical access.
- CC7 — operations.
- CC8 — change management.
- CC9 — risk mitigation.

Plus criteria for the additional TSCs.

## ISO 27001 in detail

### ISMS — the management system

ISO 27001 isn't just a control list. It's a management system: documented scope, leadership commitment, risk assessment, treatment, monitoring, internal audit, management review, continual improvement.

Practitioner: the ISMS is the bigger work item than the controls themselves.

### Annex A controls

ISO 27001:2022 has 93 controls in 4 themes:
- Organisational (37).
- People (8).
- Physical (14).
- Technological (34).

Statement of Applicability (SoA) lists which controls apply.

### Certification process

1. Define scope.
2. Implement ISMS.
3. Risk assessment + treatment plan.
4. Internal audit.
5. Management review.
6. Stage 1 audit (document review).
7. Stage 2 audit (implementation).
8. Certification.
9. Surveillance audits (years 1 + 2).
10. Re-certification (year 3).

## Operational comparison

### Risk methodology

- **SOC 2** doesn't prescribe risk methodology; the organisation defines and the auditor evaluates.
- **ISO 27001** requires a documented risk methodology and treatment plan.

### Documentation

- **SOC 2** requires controls documented enough to test.
- **ISO 27001** requires extensive ISMS documentation (policies, procedures, records, audit logs).

### Continuous improvement

- **SOC 2** Type II requires the controls to operate consistently over the period.
- **ISO 27001** explicitly requires continual improvement; auditors look for evidence of evolution.

### Geographic perception

- **SOC 2** is poorly recognised outside the US.
- **ISO 27001** is widely recognised globally.

## Building one and mapping

If you build to ISO 27001 standards, you can map controls to SOC 2 TSCs with relatively little additional effort.

Conversely, SOC 2 alone leaves you short of an ISMS for ISO 27001.

Pragmatic order:
1. Build ISMS (lighter version) and SOC 2 controls.
2. Get SOC 2 first (faster, US enterprise sales).
3. Mature the ISMS.
4. Pursue ISO 27001 when EU / international growth justifies.

## Control-implementation evidence patterns

Modern automation makes both achievable:
- **Drata, Vanta, Secureframe, Tugboat, Sprinto** — compliance automation platforms.
- Pull telemetry from cloud / SaaS to evidence controls.
- Continuous monitoring vs annual scrambling.

Reduce hours-per-audit dramatically with automation, but don't eliminate the controls themselves.

## Common practitioner mistakes

- **SOC 2 with no real controls** — exists but auditor opinion qualified ("did not meet"). Buyers read these.
- **ISO 27001 with no real ISMS** — certification withdrawn at surveillance audit.
- **Scope too broad** — auditing the entire org instead of relevant scope. Cost balloons.
- **Scope too narrow** — buyers can tell when scope excludes critical infrastructure.
- **Same person doing implementation and audit** — independence issue.
- **No real risk assessment** — boilerplate copy-pasted between companies.
- **Manual evidence collection** — Excel-driven, error-prone.

## Mapping to other regimes

Most controls map across:
- **PCI DSS** ([[pci-dss-4-implementation]]) — overlap, but PCI is more prescriptive on technical controls.
- **HIPAA** ([[hipaa-security-rule]]) — adjacent.
- **NIS2** ([[nis2-implementation]]) — adjacent.
- **FedRAMP** — much higher bar; both are stepping stones.
- **GDPR** — privacy-specific, less control-oriented.

## Workflow to study

1. Read SOC 2 Trust Services Criteria (publicly available from AICPA).
2. Read ISO 27001:2022 + ISO 27002 controls (paywalled but well-known).
3. Walk a small project's controls and map to each.
4. Use a compliance automation tool's gap analysis.

## Real-world business context

- Lacking SOC 2 in US enterprise sales is a deal-blocker for most B2B SaaS deals.
- Lacking ISO 27001 in EU enterprise is similar.
- Both add ~6–12 months engineering work upfront.
- Both then become continuous compliance commitments.

Plan for them before sales asks; retrofitting is more expensive.

## Workflow to start

1. **Pick one** based on customer geography.
2. **Engage a Type II / certification readiness firm** if internal expertise limited.
3. **Define scope** — what's in, what's out, documented.
4. **Implement** controls using automation tooling.
5. **Internal audit** before external.
6. **External audit** / certification.

## Related

- [[pci-dss-4-implementation]] — adjacent regime.
- [[hipaa-security-rule]] — adjacent regime.
- [[nis2-implementation]] — adjacent regime.
- [[gdpr-incident-implications]] — adjacent.
- [[appsec-maturity-checklist]] — programmatic baseline.
- [[secure-sdlc-rollout-playbook]] — control-implementation flavour.

## References
- [AICPA — Trust Services Criteria](https://www.aicpa-cima.com/resources/landing/system-and-organization-controls-soc-suite-of-services)
- [ISO/IEC 27001:2022](https://www.iso.org/standard/27001)
- [ISO/IEC 27002:2022 — Annex A control guidance](https://www.iso.org/standard/27002)
- [Drata / Vanta / Secureframe — compliance automation platforms (vendor pages)](https://drata.com/)
- See also: [[pci-dss-4-implementation]], [[hipaa-security-rule]], [[nis2-implementation]], [[appsec-maturity-checklist]], [[iso-27002-2022-controls-catalog]], [[iso-27701-privacy-extension]], [[hitrust-csf-implementation]], [[csa-star-cloud-security]]
