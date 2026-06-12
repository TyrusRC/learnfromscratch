---
title: ISO/IEC 42001 — AI management system
slug: iso-42001-ai-management-system
---

> **TL;DR:** ISO/IEC 42001:2023 (published December 2023) is the first certifiable management system standard for AI. Same family as ISO 27001 (security) and ISO 9001 (quality) — Plan-Do-Check-Act, leadership accountability, risk-based — but scoped to organisations that develop, deploy, or use AI systems. Driver: regulatory pressure (EU AI Act, NIST AI RMF, US executive order 14110) plus enterprise need for assurance of supplier AI systems.

## What it is
ISO 42001 establishes requirements for an **AI Management System (AIMS)**. Like ISO 27001 builds an ISMS, ISO 42001 builds an AIMS — policies, procedures, roles, risk processes, controls, continual improvement — scoped to AI lifecycle.

Companion standards:
- **ISO/IEC 23894** — AI risk management (informative)
- **ISO/IEC 22989** — AI concepts and terminology
- **ISO/IEC 5338** — AI system life cycle processes
- **ISO/IEC 5259** series — data quality for analytics and ML
- **ISO/IEC 38507** — governance implications of AI for boards

42001 is the certifiable umbrella; the others fill in technical detail.

## Preconditions / where it applies
- Organisations developing AI models or systems (model labs, SaaS with ML features)
- Organisations deploying AI in products
- Organisations using AI procured from third parties (incl. ChatGPT-type integrations)
- AI components subject to EU AI Act high-risk classification → strong commercial driver for 42001 certification

## Structure (Annex A controls)

42001 Annex A has **39 controls in 9 categories**:

1. **A.2 Policies related to AI** — AI policy, alignment with org strategy
2. **A.3 Internal organisation** — roles, responsibilities, board oversight
3. **A.4 Resources for AI systems** — data, tooling, computing, human resources
4. **A.5 Assessing impacts of AI systems** — AI impact assessment (FRIA-style)
5. **A.6 AI system life cycle** — design, development, verification, deployment, decommissioning
6. **A.7 Data for AI systems** — provenance, quality, bias mitigation
7. **A.8 Information for interested parties of AI systems** — transparency, explainability, user info
8. **A.9 Use of AI systems** — operational controls, monitoring
9. **A.10 Third-party and customer relationships** — supplier AI risk, customer agreements

## AI Impact Assessment (A.5)
Closest analogue to the AI Act's Fundamental Rights Impact Assessment (FRIA). Required for each AI system:
- Intended purpose + reasonably foreseeable misuse
- Affected individuals and groups
- Risks: fairness, accuracy, reliability, robustness, security, privacy, transparency
- Risk mitigation measures
- Residual risk acceptance
- Review trigger conditions

Document; update on material change; produce on auditor request.

## Implementation tradecraft

**Phase 1 — Scope and governance (Months 1-2)**
- Decide what's in/out of scope (which AI systems, departments, lifecycle phases)
- Appoint AIMS owner — usually CTO, CISO, or new "Head of AI Governance"
- Board commitment statement (parallel to 27001 management commitment)
- Inventory all AI systems — first-party + procured + embedded-in-SaaS (often the longest list)

**Phase 2 — Risk and impact assessment (Months 2-4)**
- AI risk register: hallucination, bias, model drift, prompt injection, training-data leakage, supply chain (Hugging Face model integrity)
- Per-system AI Impact Assessment using A.5 template
- Map AI risks to existing 27001 risks (overlap with information security, privacy)

**Phase 3 — Control implementation (Months 4-9)**
- Data governance: provenance, consent, retention, bias testing (A.7)
- MLOps: versioned models, reproducible training, deployment gates (A.6)
- Monitoring: drift detection, performance regression, fairness metrics in production (A.9)
- Transparency artifacts: model cards, datasheets for datasets, system cards (A.8)
- Vendor AI assessment: due diligence checklist for procured LLMs (A.10)

**Phase 4 — Internal audit + management review (Month 10)**
- Mock audit by independent internal auditor or consultant
- Top management reviews KPIs, audit findings, risks
- Capture in records before certification

**Phase 5 — Certification body audit (Month 11-12)**
- Stage 1 (document review)
- Stage 2 (on-site / remote evidence sampling)
- Three-year cycle with surveillance audits annually

## Intersection with regulations

- **EU AI Act** (in force 2024, full applicability 2026-2027) — 42001 conformance is strong evidence of compliance, particularly for high-risk AI providers; expected to be referenced in harmonised standards (`hEN`) under Annex IV
- **NIST AI Risk Management Framework** (US) — not certifiable; 42001 is the closest certifiable framework aligned to it
- **US Executive Order 14110** (Biden, partly rescinded under Trump 2025) — referenced AI safety practices; many requirements survive in agency policies
- **UK AI Regulation** — principle-based, sector-led; 42001 cited as voluntary baseline
- **China — Generative AI Measures** — Chinese national standards diverge; 42001 useful for multinationals
- **GDPR + EU AI Act overlap** — AIMS must cover personal data dimensions; 27701 + 42001 reinforce each other

## Common implementation pitfalls

- **Treating AI as a security control alone** — AIMS covers ethics, fairness, transparency, beyond CIA triad
- **Vendor AI invisibility** — internal teams use ChatGPT, Copilot, Gemini, embedded LLMs; inventory is harder than first-party AI
- **Bias testing without representative test sets** — A.7 requires demonstrable mitigation, not just a checkbox
- **No model decommissioning process** — A.6 requires lifecycle including retirement
- **Transparency theater** — generic disclaimers don't meet A.8; need system-specific explanations

## Certification market signal

42001 certifications are early; first wave 2024-2025. Expect strong demand from:
- Enterprise AI vendors selling to regulated buyers (banks, insurers, governments)
- Public sector AI providers
- Multinationals preparing for EU AI Act high-risk obligations
- Healthcare and HR-tech AI providers (sectoral scrutiny)

Many orgs will pair 42001 + 27001 + 27701 as the "trust trifecta" for AI products.

## OPSEC for compliance team

- AIMS overlaps deeply with ISMS — share auditors, processes, document control
- Keep AI Impact Assessments TLP:AMBER — they describe weakness/limitations of your AI
- Model cards published externally are sanitised versions of the assessment, NOT the assessment itself
- Track regulatory updates; the AI compliance landscape changes faster than other frameworks

## References
- [ISO/IEC 42001:2023](https://www.iso.org/standard/81230.html)
- [ISO/IEC 23894:2023](https://www.iso.org/standard/77304.html) — AI risk management
- [NIST AI Risk Management Framework 1.0](https://www.nist.gov/itl/ai-risk-management-framework)
- [EU AI Act text (Regulation 2024/1689)](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32024R1689)
- [ISO/IEC 5338:2023 AI lifecycle](https://www.iso.org/standard/81118.html)

See also: [[iso-27002-2022-controls-catalog]], [[building-an-iso27001-isms-practitioner]], [[iso-27701-privacy-extension]], [[nist-csf-2-implementation]], [[dora-eu-implementation]], [[nis2-implementation]], [[third-party-risk-management-practitioner]], [[ai-llm-bug-bounty-methodology]]
