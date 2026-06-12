---
title: ISO 22301 — business continuity management
slug: iso-22301-business-continuity
---

> **TL;DR:** ISO 22301:2019 is the certifiable Business Continuity Management System (BCMS) standard. Same management-system architecture as ISO 27001; scope is operational resilience — keeping critical activities running through disruption (cyber, natural disaster, supply chain, pandemic). Increasingly bundled with 27001 for "resilience" customer assurance and required by DORA, NIS2, sector regulators.

## What it is
ISO 22301 specifies requirements to plan, establish, implement, operate, monitor, review, maintain, and improve a Business Continuity Management System (BCMS). Companion standards:
- **ISO 22313:2020** — implementation guidance (the "27002 of 22301")
- **ISO 22317:2015** — Business Impact Analysis (BIA) guidance
- **ISO 22318:2015** — supply chain continuity
- **ISO 22320:2018** — incident response
- **ISO 22330:2018** — people aspects of business continuity
- **ISO 22331:2018** — BC strategy and solutions

22301 is certifiable; the others are guidance.

## Preconditions / where it applies
- Any organisation whose disruption has material impact (financial, regulatory, reputational, safety)
- Regulated sectors increasingly require it: financial (DORA, MAS, FINMA), telecoms, healthcare
- Critical infrastructure operators (NIS2 essential / important entities)
- Customer-driven: B2B vendor risk reviews include BC assurance

## Core concepts

### Business Impact Analysis (BIA)
Identify each activity, its dependencies, and the impact of disruption over time. Outputs:
- **Maximum Tolerable Period of Disruption (MTPD)** — how long can this activity be down before unacceptable impact?
- **Recovery Time Objective (RTO)** — target time to resume the activity (must be ≤ MTPD with margin)
- **Recovery Point Objective (RPO)** — acceptable data loss window
- **Minimum Business Continuity Objective (MBCO)** — minimum acceptable level of service during disruption

Per-activity, not per-system. IT RTO is a derived value from business activity RTOs.

### Risk assessment vs BIA
Distinct exercises:
- **BIA** — assumes disruption happens, focuses on impact and recovery
- **Risk assessment** — likelihood and prevention of disruption causes

Both required by 22301. Often run sequentially: BIA defines what must survive; risk assessment shows which threats are most likely.

### Business continuity strategy
Once BIA identifies critical activities with RTOs, choose how to meet them:
- **Resilience** — design to not fail (redundancy, geographic distribution)
- **Recovery** — design to restore quickly (backups, alternate sites, failover)
- **Workaround** — manual / degraded mode while primary is down

Most BC strategies blend all three. Cost rises sharply with shorter RTOs.

### Business continuity plans (BCPs)
Per-activity playbooks: roles, procedures, communication, escalation, dependencies, recovery steps. Tested, exercised, kept current.

### Crisis management
Higher-level than activity BCP: cross-organisational incident command structure, executive decision-making, external communications, regulatory notifications.

## Annex A (informative)
Unlike 27001, 22301's Annex A doesn't list controls. The standard works through clauses 4-10, and implementers map controls to their environment.

## Implementation tradecraft

**Phase 1 — Scope and BIA (Months 1-3)**
- Scope BCMS to entire org OR critical lines of business
- Engage business owners (NOT just IT) — they own activity RTOs
- BIA workshop per business area; output the activity inventory + RTO/RPO/MBCO
- Validate impact estimates with finance (financial impact), legal (regulatory penalty), comms (reputational)

**Phase 2 — Risk assessment (Months 2-4)**
- Risk register: cyber attack, supplier failure, natural disaster, key personnel loss, pandemic, utility outage, geopolitical
- Likelihood × impact rating
- Treatment: prevent, mitigate, transfer (insurance), accept

**Phase 3 — Strategy selection (Months 4-5)**
- Per critical activity: resilience / recovery / workaround options
- Cost-benefit analysis vs RTO; document the chosen strategy and rationale
- Get executive sponsor sign-off (resourcing decision)

**Phase 4 — Plan development (Months 5-8)**
- Activity-level BCPs
- ICT continuity plan (overlaps with IT DR)
- Crisis management plan
- Communications plan (internal, external, regulator, customer)
- Supply chain continuity per critical supplier
- Workplace recovery (alternate sites, remote work activation)

**Phase 5 — Exercise programme (Months 8-12)**
22301 requires testing. Types:
- **Tabletop** — discussion-based scenario walkthrough
- **Walkthrough** — step-by-step procedure validation
- **Simulation** — controlled scenario with role-play
- **Full live test** — actual failover / alternate site activation

Mix types; each plan tested at least annually. Document lessons learned and update plans.

**Phase 6 — Internal audit + certification (Month 12-14)**
- BCMS audit including evidence of BIA, plans, exercises
- Management review
- Stage 1 / Stage 2 certification audit

## Tie-ins to other standards

- **ISO 27001 Annex A.5.29** — BC for information security (subset of 22301)
- **ISO 27001 Annex A.5.30** — ICT readiness for BC (new in 2022)
- **DORA** — uses BC concepts heavily (ICT-specific resilience, TLPT)
- **NIS2** — essential entities must demonstrate BC capability
- **PCI DSS 12.10** — incident response, which BC complements
- **Sector regulators** — FFIEC, OCC, PRA all have BC expectations for financial services

Pairing 27001 + 22301 is common; many CB will perform integrated audit.

## Common implementation pitfalls

- **IT-only BCMS** — 22301 covers ALL activities, not just systems
- **Static plans** — annual review minimum; trigger-based update (org change, new critical activity)
- **Untested plans** — auditors check exercise records first
- **Optimistic RTO** — business says "1 hour" without resourcing for it; auditor finds discrepancy
- **Single-region cloud assumption** — strategy assumes cloud provider survives; multi-region or multi-cloud strategy needed for high-RTO activities
- **Key personnel single-point** — bus factor 1 on critical processes; succession planning required
- **Supplier BC gap** — your BC depends on supplier BC; review supplier evidence (their 22301 or equivalent)

## Crisis management integration

Maturity model:
- **Reactive** — improvised response when crisis hits
- **Defined** — documented plans, owner per scenario
- **Managed** — regular exercises, refined plans
- **Optimised** — integrated with risk management, threat intel, continuous improvement

Most pre-22301 organisations sit between Reactive and Defined.

## OPSEC for BC team

- BCP documents contain operational detail attackers value — TLP:AMBER internal
- Crisis contact lists must be reachable when systems are down (printed copies, offline storage)
- Supplier BC reports include their weaknesses — treat as confidential
- Exercise scenarios used by red teams = realistic attack vectors; protect

## Tooling

- **Fusion / MetricStream / OneTrust** — commercial BCMS platforms
- **Excel + SharePoint** — many SMBs run BCMS in spreadsheets successfully
- **Everbridge / xMatters** — mass notification during crises
- **Tabletop tools** — Backstory, custom playbooks
- Open-source: limited; most BCMS tooling is commercial

## References
- [ISO 22301:2019](https://www.iso.org/standard/75106.html)
- [ISO 22313:2020 guidance](https://www.iso.org/standard/75107.html)
- [Business Continuity Institute (BCI)](https://www.thebci.org/) — industry body, Good Practice Guidelines
- [DRI International](https://drii.org/) — professional certification path
- [Continuity Central](https://www.continuitycentral.com/) — practitioner news + analysis

See also: [[iso-27002-2022-controls-catalog]], [[building-an-iso27001-isms-practitioner]], [[dora-eu-implementation]], [[nis2-implementation]], [[tabletop-exercise-design-and-execution]], [[crisis-communications-cyber]], [[patch-management-program]], [[third-party-risk-management-practitioner]], [[cyber-insurance-practitioner]]
