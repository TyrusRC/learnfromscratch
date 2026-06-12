---
title: ISO/IEC 27701 — privacy management extension
slug: iso-27701-privacy-extension
---

> **TL;DR:** ISO/IEC 27701 extends ISO/IEC 27001/27002 to a **Privacy Information Management System (PIMS)**. Same ISMS scaffolding, plus PII controls (Annex A for controllers, Annex B for processors), GDPR/CCPA mapping, and accountability artifacts. Currently 27701:2019 (next revision late 2025). Cannot be certified standalone — requires existing 27001 certification first.

## What it is
27701 was published as an extension specifically to bridge information security (27001/27002) with privacy (GDPR-style accountability). Two control sets:
- **Annex A** — additional controls for **PII controllers** (32 controls)
- **Annex B** — additional controls for **PII processors** (18 controls)

Plus modifications to 27001 clauses 4–10 to incorporate privacy considerations into the management system itself.

## Preconditions / where it applies
- Existing ISO 27001 certification (cannot certify 27701 alone — it's a bolt-on)
- Organisation processes personal data (controller, processor, or both)
- Strong commercial driver: GDPR Article 28 third-party assurance, CCPA service-provider verification, B2B sales requirements

## What 27701 changes vs 27001/27002

**Management system clauses**: each clause adds "and PII" — e.g., information security policy becomes information security AND privacy policy. Risk assessment includes privacy risks. Statement of Applicability adds Annex A/B controls.

**Annex A (controllers)** — 32 controls covering:
- Identifying and documenting the purpose
- Identifying lawful basis (GDPR Article 6)
- Records of processing (GDPR Article 30)
- Determining when consent is required + obtaining it
- Information provided to PII principals (privacy notices)
- Rights of PII principals (access, rectification, erasure, portability)
- Privacy by design and by default
- Records of decisions
- DPIA / privacy impact assessment process
- Personal data breach handling

**Annex B (processors)** — 18 controls covering:
- Customer agreement
- Organisation's purpose vs customer's instructions
- Marketing only when authorised
- Infringing instructions handling
- Customer obligations support
- Records of processing (processor side)
- Sub-processor management

Most B2B SaaS providers implement both A AND B (they're controllers for their own employees + processors for customer data).

## Mapping to GDPR

27701 Annex D provides explicit mapping of each control to GDPR articles. Common mappings:
- 7.2.1 Identify lawful basis ↔ Art. 6
- 7.3.1 Determining and fulfilling obligations ↔ Art. 12
- 7.3.4 PII principals rights ↔ Art. 15-22
- 7.4 Privacy by design ↔ Art. 25
- 8.2 Privacy impact assessments ↔ Art. 35 (DPIA)
- A.7.5 Records of processing ↔ Art. 30
- 7.3.10 Breach notification ↔ Art. 33-34

Mapping is informative, not legal advice — 27701 conformance doesn't automatically equal GDPR compliance. But it's strong evidence of accountability.

## Mapping to other privacy regimes
Annex D also maps to ISO/IEC 29100 (privacy framework). Practitioner-built mappings (community, not official) extend to:
- **CCPA / CPRA** — California
- **LGPD** — Brazil
- **PIPEDA** — Canada
- **APPI** — Japan
- **PDPA** — Singapore, Thailand
- **DPDP** — India
- **POPIA** — South Africa
- **PIPL** — China

For multinational orgs, 27701 is the unifying baseline; specific jurisdiction requirements layer on top.

## Implementation tradecraft

**Phase 1 — PIMS scoping (Month 1)**
- Identify all personal data flows: who's the controller? who's the processor?
- Many organisations are BOTH — e.g., B2B SaaS is processor for customer data, controller for employee/prospect data
- Define which Annex (A, B, or both) applies
- Update ISMS scope to include PIMS scope

**Phase 2 — Gap assessment (Month 1-2)**
- 27001 controls already in place vs. 27701 additions
- Existing GDPR/CCPA compliance work — most already addresses 27701 controls
- Record of Processing Activities (RoPA) — often the biggest gap
- DPIA process — needed for high-risk processing

**Phase 3 — Control implementation (Month 2-6)**
- Privacy notices reviewed for completeness and clarity
- Data Subject Access Request (DSAR) workflow + SLA
- Subprocessor inventory + customer notification process (Annex B)
- Cross-border transfer mechanisms (SCCs, BCRs, adequacy decisions)
- Breach detection + 72-hour notification readiness
- Privacy training for relevant staff

**Phase 4 — Internal audit + cert audit (Month 7-9)**
- Integrated with 27001 audit cycle
- Auditors verify both ISMS and PIMS controls

## Common implementation pitfalls

- **RoPA invisible to operations** — Article 30 records exist on paper but don't match actual data flows; auditor data-flow walkthrough catches this
- **Subprocessor inventory stale** — every new SaaS added by a team is a subprocessor; quarterly review minimum
- **Customer agreement gaps** — Annex B requires processor controls embedded in customer DPA; pre-existing customer contracts may not align
- **DPIA done once, never updated** — material change triggers reassessment; auditors check trigger criteria
- **Cross-border transfer post-Schrems II** — still a moving target; document EDPB guidance compliance

## Intersection with other frameworks

- **27001** — foundation; 27701 is the privacy add-on
- **27002** — information security guidance; 27701 doesn't replace, supplements
- **42001 (AI)** — increasingly relevant when AI processes personal data
- **NIST Privacy Framework** — similar concepts; can co-exist
- **CSA STAR Privacy** — cloud-specific assessment with 27701 alignment

## Commercial drivers

- B2B SaaS sales to EU customers: 27701 certificate often required for vendor onboarding
- GDPR Article 32 + Article 28: 27701 + 27001 strong evidence of "appropriate technical and organisational measures"
- Insurance: privacy liability coverage may discount with 27701 certification
- Regulator engagement: DPAs view 27701 favourably during investigations

## OPSEC for compliance team

- RoPA contains sensitive operational detail — TLP:AMBER internal; never publish wholesale
- Subprocessor list is often customer-visible (DPA requirement); keep current
- DPIA library: sensitive (describes processing weaknesses) — store in restricted area
- DSAR handling logs are evidence; retain for inspection but minimise PII in the logs themselves

## What's next: 27701:2025 revision

Public draft circulated 2024; expected publication late 2025. Changes:
- Restructured to align with 27001:2022's clause structure
- Integration of NIST Privacy Framework concepts
- More explicit AI / automated decision-making coverage
- Expanded cross-border transfer guidance
- Improved DPIA process detail

Plan for transition period similar to 27001:2013→2022.

## References
- [ISO/IEC 27701:2019](https://www.iso.org/standard/71670.html)
- [GDPR mapping (informative Annex D)](https://www.iso.org/) — official text
- [IAPP — 27701 implementation series](https://iapp.org/)
- [ICO accountability framework](https://ico.org.uk/for-organisations/accountability-framework/) — UK regulator's complementary guide
- [EDPB guidance library](https://edpb.europa.eu/edpb_en) — Schrems II + transfer guidance

See also: [[iso-27002-2022-controls-catalog]], [[building-an-iso27001-isms-practitioner]], [[iso-27001-lead-auditor-certification]], [[iso-42001-ai-management-system]], [[gdpr-incident-implications]], [[appi-japan]], [[dpdp-india]], [[lgpd-brazil]], [[pdpa-singapore]], [[third-party-risk-management-practitioner]]
