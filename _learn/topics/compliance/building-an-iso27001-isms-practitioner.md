---
title: Building an ISO 27001 ISMS — practitioner playbook
slug: building-an-iso27001-isms-practitioner
aliases: [build-isms, isms-practitioner-playbook]
---

> **TL;DR:** Building an ISO 27001 Information Security Management System (ISMS) from scratch to first certification is a 6-12 month slog dominated not by control implementation but by *evidence discipline*: scope, risk methodology, Statement of Applicability, internal audit, and management review. Auditors fail first-timers on the management system clauses (4-10) far more than on Annex A controls. This is a companion to [[soc2-vs-iso27001]], [[iso-27001-lead-auditor-certification]], [[appsec-maturity-checklist]], and [[secure-sdlc-rollout-playbook]] — read those for context on framework choice, auditor mindset, and where ISMS work plugs into engineering.

## Why it matters

ISO 27001 is the international baseline customers in EMEA, APAC, and increasingly the US ask for in security questionnaires. Unlike [[soc2-vs-iso27001]] SOC 2 (an attestation by a CPA firm against your written controls), 27001 is a *certification* against a fixed standard by an accredited body. That distinction shapes the project: you cannot redefine controls. You must implement a management system that meets clauses 4-10, justify which Annex A controls apply, and prove the system *operates* over time.

Practitioners get pulled into this work three ways: (1) as the in-house security engineer asked to "get us 27001 by Q3," (2) as a vCISO or consultant scoping multiple clients, or (3) as part of an [[appsec-maturity-checklist]] uplift driven by a sales cycle. The failure mode in all three is treating it as a controls checklist. Auditors care that the *system* exists, is risk-driven, and self-corrects. Strong controls with no management review = nonconformity. Weak controls with documented risk acceptance + a working internal audit programme = pass.

ISO 27001:2022 has 93 Annex A controls organised into 4 themes (Organisational, People, Physical, Technological), down from 114 in :2013. The 2022 revision also added 11 net-new controls including threat intelligence, ICT readiness for business continuity, secure coding, and data masking — relevant if you also run [[cti-collection-management]] or [[secure-sdlc-rollout-playbook]].

## Scope, classes, and patterns

### Defining scope (clause 4.3)

Scope is the single most consequential decision. Too broad and you have to evidence controls across systems you do not own; too narrow and customers reject the certificate.

Useful patterns:

- **Product-line scope:** "The development, operation, and support of the Acme SaaS platform." Excludes corporate IT outside the product team. Common for early-stage SaaS.
- **Entity scope:** "All operations of Acme Ltd." Heavier, but cleaner for enterprise sales and avoids "is the certificate real?" pushback.
- **Site scope:** "Operations at the London HQ." Rare for cloud-native companies; common for managed services or data centre operators.

Document scope as a one-page statement listing: in-scope services, supporting functions (HR, legal, IT), physical locations, technology platforms, and explicit exclusions with justification. Auditors will probe exclusions hard.

### The four control themes (Annex A 2022)

- **A.5 Organisational (37 controls)** — policies, roles, supplier management, incident management, intelligence ([[cti-collection-management]] aligned), legal/contractual.
- **A.6 People (8 controls)** — screening, terms of employment, awareness, disciplinary process, post-employment.
- **A.7 Physical (14 controls)** — secure areas, equipment, clear desk, cabling, maintenance.
- **A.8 Technological (34 controls)** — endpoint, network, crypto, logging, vulnerability management, secure development (links to [[secure-sdlc-rollout-playbook]]).

### Statement of Applicability (SoA)

The SoA is a spreadsheet listing every Annex A control with columns: applicable (Y/N), justification, implementation status, link to evidence. This is the document auditors live in. Excluding a control is allowed but requires a written justification (e.g., A.7.5 "physical security perimeter" reduced if you are fully cloud-hosted — but you still need supplier control over the cloud provider's physical security via A.5.19-A.5.22).

Common SoA mistakes: marking everything "applicable" out of fear (you then owe evidence for all 93), or excluding A.8.28 "secure coding" because "we use AI" — neither flies.

## Risk methodology (clause 6.1)

ISO 27001 does not mandate a specific risk methodology. You must define one and use it consistently. Practitioner-friendly approaches:

- **Asset-based** — enumerate assets (from the asset register), identify threats per asset, score likelihood x impact. Heavy but defensible. Traditional auditor expectation.
- **Scenario-based** — identify top 20-50 risk scenarios (e.g., "supply-chain compromise of build pipeline" referencing [[case-study-3cx-supply-chain]] or [[case-study-solarwinds-2020]]) and assess. Faster, more useful for engineering teams.
- **ISO 27005 aligned** — formal, defensible, slow. Good for regulated industries.

Document: scales (e.g., 1-5 likelihood, 1-5 impact), risk appetite (which combined scores require treatment vs acceptance), treatment options (modify, retain, avoid, share), and a re-assessment cadence (annually + on major change).

Tie risks to Annex A controls in the SoA. The auditor will trace: risk -> treatment plan -> SoA control -> implementation evidence -> operating evidence -> internal audit -> management review. Break the chain anywhere and you get a nonconformity.

## Asset register and policy hierarchy

### Asset register

Required by A.5.9. Keep it lightweight: asset name, owner, classification (Public / Internal / Confidential / Restricted is a defensible 4-tier model), location/system, lifecycle stage. For SaaS companies, your asset register is mostly: code repos, data stores, SaaS subscriptions, employee endpoints. Do not list every Lambda function — list the *system*.

### Policy hierarchy

Three tiers works for most organisations:

1. **Information Security Policy** (top-level, signed by CEO, 1-2 pages, reviewed annually) — the constitutional document.
2. **Topic-specific policies** — Access Control, Cryptography, Supplier Security, Acceptable Use, Incident Response, Secure Development (which references your [[secure-sdlc-rollout-playbook]]), Business Continuity, Data Classification, HR Security. 8-12 documents, 3-5 pages each.
3. **Procedures and standards** — how the policies are operationalised. Live in the engineering wiki, not the GRC tool.

Every policy needs: owner, version, review date, approver. Auditors check dates.

## Defensive baseline: the management system clauses

Engineers underestimate clauses 4-10. These are where first-time audits fail.

- **Clause 4** — Context: scope, interested parties, ISMS boundaries.
- **Clause 5** — Leadership: top management commitment, policy, roles. Need evidence the CEO/CTO *did something*, not just signed a doc.
- **Clause 6** — Planning: risks, objectives. Objectives must be measurable (e.g., "reduce critical findings MTTR to under 14 days").
- **Clause 7** — Support: resources, competence, awareness, communication, documented information.
- **Clause 8** — Operation: run the risk treatment plan.
- **Clause 9** — Performance evaluation: monitoring, **internal audit**, **management review**.
- **Clause 10** — Improvement: nonconformity, corrective action, continual improvement.

The big three first-audit findings, almost universally:

1. **Incomplete or undocumented risk assessment** — methodology not written down, or risks identified but no treatment plan.
2. **Missing internal audit** — never performed, or performed by someone with conflict of interest (the person who built the ISMS auditing their own work).
3. **Inadequate management review** — no agenda, no minutes, or held but no decisions recorded. Must cover the inputs listed in clause 9.3 (audit results, nonconformities, risk status, objectives, feedback from interested parties, opportunities for improvement).

## Workflow to study

A realistic greenfield timeline:

### Months 1-2: Foundation

- Pick scope. Write it down. Get exec sign-off.
- Choose risk methodology. Document it.
- Draft Information Security Policy + 8-12 topic policies. Use templates (IT Governance Ltd, ISO 27001 toolkit) and adapt — do not write from scratch.
- Stand up the asset register.
- Select a GRC tool: Drata, Vanta, Secureframe, Sprinto, ISMS.online, or for the budget-conscious, a structured SharePoint/Confluence + spreadsheets. Automation tools accelerate evidence collection but do not replace the management system thinking.

### Months 3-5: Risk + controls

- Run the risk assessment. Produce risk register.
- Build the SoA. Map every Annex A control to: applicable yes/no, justification, status, evidence link.
- Implement control gaps. Most engineering controls (logging, vulnerability management, access reviews, MFA, encryption) already exist if you have a mature [[appsec-maturity-checklist]] / [[secure-sdlc-rollout-playbook]] — they just need documentation.
- Roll out security awareness training. Evidence completion.

### Months 6-8: Operate the system

- Generate at least 3 months of operating evidence before Stage 2 (auditors want to see the ISMS *running*, not just existing).
- Hold first management review. Record minutes.
- Run first internal audit. Use an independent person — an external consultant, a board member, a colleague from another department, or a buddy-system swap with another company. If you hold [[iso-27001-lead-auditor-certification]] you can audit your own org as long as you did not build the parts you audit.
- Treat findings. Document corrective actions.

### Months 9-12: Certification

- **Stage 1 audit (documentation review):** auditor reviews scope, SoA, policies, risk assessment, audit reports, management review minutes. Typically 1-2 days. Findings here are "go fix this before Stage 2."
- **Stage 2 audit (implementation review):** auditor interviews staff, samples evidence, walks through controls. Typically 3-5 days for small SaaS. Major nonconformities block certification; minor nonconformities require a corrective action plan within 90 days.
- **Certification decision:** issued by the certification body after independent review. Valid 3 years with annual surveillance audits and a full recertification at year 3.

## Realistic practitioner notes

- **Budget:** 15-50k USD for certification body fees (small SaaS, 50-200 employees) plus 20-60k for a GRC tool annually. Consultants add 30-80k if used. Internal labour is the largest cost — usually 0.5-1.0 FTE for 6-12 months.
- **Who does this:** Security manager / compliance lead / vCISO. Engineers contribute evidence but should not own the ISMS — they will resent it and it will stall.
- **GRC tool reality:** Drata/Vanta/Secureframe automate evidence collection from AWS/GitHub/Okta/Jamf. They do *not* write your risk methodology, run your management review, or pass your audit for you. Marketing claims of "compliance in weeks" mean SOC 2 Type 1 (point-in-time), not 27001.
- **Common transitions in:** SOC analyst -> GRC analyst -> ISMS lead; auditor -> in-house compliance; software engineer with policy aptitude -> security engineer -> ISMS owner.
- **Day-to-day reality:** 60% documentation and chasing evidence, 20% meetings (management review, vendor reviews, audit prep), 15% control implementation oversight, 5% actual security work. Engineers who romanticise hands-on security usually hate this role within a year.
- **Who succeeds:** people who enjoy systems thinking, writing, and slow improvement loops. Who struggles: people who need the dopamine of incident response or offensive work — go do [[ir-from-source-signals]] or [[pentest-engagement-execution]] instead.

## Integration with the broader programme

The ISMS does not replace your detection, IR, or appsec programmes — it *governs* them.

- Annex A.5.7 (threat intelligence) -> see [[cti-collection-management]].
- A.5.24-A.5.30 (incident management, business continuity, ICT readiness) -> ties to [[ir-from-source-signals]] and case studies like [[case-study-okta-2023-support-system]], [[case-study-lastpass-2022]], [[case-study-moveit-2023]].
- A.8.25-A.8.28 (secure development lifecycle) -> [[secure-sdlc-rollout-playbook]] and [[appsec-maturity-checklist]].
- A.5.19-A.5.22 (supplier management) -> the documentation lane your security questionnaires live in; aligned with [[soc2-vs-iso27001]] reciprocity.
- Regulatory overlap -> [[gdpr-incident-implications]], [[nis2-implementation]], [[pci-dss-4-implementation]], [[hipaa-security-rule]] depending on industry.

## References

- ISO/IEC 27001:2022 standard — https://www.iso.org/standard/27001
- ISO/IEC 27002:2022 implementation guidance — https://www.iso.org/standard/75652.html
- IAF mandatory documents for accredited certification — https://iaf.nu/en/iaf-documents/
- UKAS register of accredited certification bodies — https://www.ukas.com/find-an-organisation/
- ENISA guidance on ISO 27001 and NIS2 alignment — https://www.enisa.europa.eu/
- NCSC (UK) ISO 27001 perspective — https://www.ncsc.gov.uk/collection/board-toolkit

## Related

- [[soc2-vs-iso27001]]
- [[iso-27001-lead-auditor-certification]]
- [[appsec-maturity-checklist]]
- [[secure-sdlc-rollout-playbook]]
- [[pci-dss-4-implementation]]
- [[hipaa-security-rule]]
- [[nis2-implementation]]
- [[gdpr-incident-implications]]
- [[cti-collection-management]]
- [[ir-from-source-signals]]
- [[nist-csf-2-implementation]]
- [[dora-eu-implementation]]
- [[iso-27002-2022-controls-catalog]]
- [[iso-42001-ai-management-system]]
- [[iso-27701-privacy-extension]]
- [[iso-22301-business-continuity]]
