---
title: BSIMM / OWASP SAMM / CMMI — security maturity models
slug: cmmi-bsimm-samm-comparison
aliases: [bsimm-samm, security-maturity-models]
---

> **TL;DR:** Security maturity models — BSIMM (observation-based benchmarking), OWASP SAMM (prescriptive roadmap), CMMI Cybermaturity, and NIST CSF tiers — each answer different questions. BSIMM tells you what your peers actually do. SAMM tells you what you should do next. CSF tiers give executives a single number. CMMI gives auditors a process-maturity story. Pick the one that matches the conversation you need to have, don't chase scores, and prioritise gaps tied to real business risk. Companion to [[appsec-maturity-checklist]], [[building-an-iso27001-isms-practitioner]], [[building-a-pci-dss-program-practitioner]], and [[devsecops-platform-engineering]].

## Why it matters

Every security leader eventually gets asked the same three questions: "How mature are we?", "How do we compare to peers?", and "What should we do next?" Maturity models exist to make those answerable without hand-waving. They also give boards and auditors a vocabulary that survives turnover.

The risk is the opposite: teams chase scores, run an annual self-assessment for the slide deck, and never actually change behaviour. The point of a maturity model is the conversation it forces and the roadmap it produces — not the number.

This note covers the four models you will see in real engagements, when to use each, and the honest limits of all of them.

## The models

### BSIMM — Building Security In Maturity Model

- Origin: Cigital, now Synopsys / Black Duck. First published 2008, refreshed annually.
- Structure: 12 practices grouped under 4 domains (Governance, Intelligence, SSDL Touchpoints, Deployment). Currently 120+ observed activities split across three levels.
- Method: descriptive, not prescriptive. An assessor interviews your SSG and observes which activities you actually do. You get a spider chart and a comparison to the anonymised industry data set (BSIMM15 covered ~130 firms).
- Output: an "observation" of your firm plus a peer comparison.
- Cost: vendor-led, paid engagement. The annual report is free.

BSIMM is most useful when you need to answer "are we behind our peers?" with data, especially for an exec audience that responds to comparisons. It is not a roadmap — it tells you what is common, not what you should do.

### OWASP SAMM — Software Assurance Maturity Model

- Origin: OWASP project, currently v2.x. Vendor-neutral, free.
- Structure: 5 business functions (Governance, Design, Implementation, Verification, Operations), each with 3 security practices, each with 2 streams, each with 3 maturity levels (so 30 stream × level cells).
- Method: prescriptive self-assessment via the SAMM toolbox spreadsheet or open-source tooling. You score each stream 0-3, identify target levels per practice, and generate a roadmap.
- Output: current vs target spider chart, gap list, suggested activities per stream.
- Cost: free. Consulting engagements exist but you can do it in-house.

SAMM is most useful when you need a concrete roadmap. The streams and activities give a small enough vocabulary that engineering managers can own them. Pair with [[appsec-maturity-checklist]] for an opinionated starting target.

### CMMI Cybermaturity Platform (ISACA)

- Origin: ISACA / CMMI Institute. Adapted from the classic CMMI process-maturity work.
- Structure: a hierarchy of capability areas mapped against NIST CSF and other frameworks, scored 0-5 (Incomplete, Initial, Managed, Defined, Quantitatively Managed, Optimising).
- Method: questionnaire-driven assessment, often paired with a workshop. Threat-prioritised — you tell the platform your top threats and it weights capabilities accordingly.
- Output: a quantitative maturity score per capability, target-state recommendation, peer benchmarking.
- Cost: SaaS subscription via ISACA.

CMMI Cybermaturity is most useful in regulated industries (financial services, government) where auditors and boards already speak CMMI. It is heavy. Smaller teams will find it disproportionate.

### NIST CSF Tiers (and CSF 2.0 profiles)

- Origin: NIST. CSF 1.1 (2018), CSF 2.0 (2024).
- Structure: 6 Functions in CSF 2.0 (Govern, Identify, Protect, Detect, Respond, Recover), broken into categories and subcategories. The "tiers" (1 Partial → 4 Adaptive) describe how you implement risk management, not how mature each control is.
- Method: build a Current Profile and Target Profile against the subcategories, then close the gap.
- Output: a profile per business unit and a tier for the overall risk-management approach.
- Cost: free.

CSF is most useful as the lingua franca for executive and regulator conversations in the US. It plays well with [[soc2-vs-iso27001]] and audit narratives. The tiers are deliberately coarse — they are not a substitute for a maturity score.

## How they compare

| Question | Best fit |
| --- | --- |
| "How do we stack up against peers?" | BSIMM |
| "What should we do next quarter?" | OWASP SAMM |
| "Give us a single board-level number" | CSF tiers, CMMI |
| "Demonstrate process discipline to auditors" | CMMI Cybermaturity |
| "Free, vendor-neutral, in-house" | SAMM + CSF |
| "Software / product security specifically" | BSIMM or SAMM |
| "Whole-of-enterprise cyber" | CSF, CMMI |

Most large programmes end up using two: SAMM (or BSIMM) for the appsec roadmap, and CSF for the enterprise narrative. Avoid running all four in parallel — you will spend more time assessing than improving.

## How to actually use the output

### Do not chase scores

A jump from SAMM 1.5 to 2.0 in Threat Assessment means nothing if your highest-risk product still has no threat model. The score is a proxy. Treat it like a code-coverage number — useful as a trend, dangerous as a target.

### Prioritise gaps with business risk

For each gap, ask:

- Which products or revenue lines does this protect?
- What is the most plausible incident this prevents or detects?
- What does it cost to close (people-months, tooling, behaviour change)?
- What is the regulator / customer impact of leaving it open?

Rank by (risk reduction) / (effort). The bottom of the list does not get done — and that is fine, as long as the decision is conscious. Pair with the threat-risk view in [[appsec-threat-modeling]] and [[third-party-risk-management-practitioner]].

### Map to existing programmes

Maturity-model gaps should land as work items in existing programmes, not a parallel "maturity initiative". Examples:

- SAMM Verification gap → SAST/DAST coverage work in [[sast-dast-ci-integration]].
- SAMM Operations gap → runbook work in [[soc-runbook-design]] and [[soc-shift-handoff-runbook]].
- CSF Govern gap → policy work in [[policy-and-standards-writing]] and ISMS work in [[building-an-iso27001-isms-practitioner]].
- BSIMM CR (Code Review) gap → secure-SDLC rollout in [[secure-sdlc-rollout-playbook]].
- CSF Detect gap → detection backlog in [[detection-engineering-pyramid-of-pain]] and [[siem-detection-use-case-catalog]].

### Realistic improvement timeline

Moving one full level across a practice is a 12-24 month effort if you are also doing day-job work. Whole-programme uplift from "ad hoc" to "managed" typically takes 3-5 years. Anyone promising a level-2-to-level-3 jump in a quarter is selling something. Budget for the cultural change, not just the tooling.

## Defensive baseline — a sane first assessment

If you have never run a maturity assessment, this is the cheapest useful start:

1. Pick **one** model. For appsec, use SAMM. For enterprise, use CSF 2.0.
2. Score yourself honestly against every stream / subcategory. Two engineers and a security lead in a room for a day. Do not invite the vendor yet.
3. Pick target levels per practice based on your risk appetite — not "all 3s". A mature programme is often 2s across the board with selected 3s where the risk demands.
4. Generate the gap list. Bucket into "do this year", "do next year", "accept".
5. Re-score every 12 months. Track deltas, not absolutes.
6. Only after two cycles, consider paying for an external BSIMM or CMMI engagement.

Tie the cadence to the audit cycle in [[soc2-vs-iso27001]] and the ISMS reviews in [[building-an-iso27001-isms-practitioner]] so it is not extra overhead.

## Workflow to study

- Read the latest **BSIMM** annual report end-to-end. Note which activities cluster at level 1 — those are table stakes.
- Download the **OWASP SAMM toolbox** spreadsheet. Score a real product team you know. Argue the scores with them.
- Skim the **NIST CSF 2.0** core. Build a one-page profile for a fictional mid-size SaaS company.
- Read one **CMMI Cybermaturity** case study. Notice how heavy the artefact requirements are.
- Practice translating a maturity gap into a backlog item: who owns it, what done looks like, what control evidence it produces. Pair with [[audit-evidence-sampling-and-scoring]].
- Run a tabletop using [[tabletop-exercise-design-and-execution]] and map which CSF subcategories the gaps light up.

## Vendor marketing vs reality

- "Industry-leading maturity scores" — every vendor says this. BSIMM observations are not certifications, and SAMM has no official accreditation. Be wary of marketing claims of "BSIMM Level 3" — that is not how BSIMM works.
- "Continuous maturity tracking platforms" — most produce dashboards your engineers will not look at. The value is in the conversation, not the SaaS.
- "AI-driven maturity uplift" — at the time of writing, no maturity model is improved by an AI dashboard. The work is human and political.
- Consultants pitching a full BSIMM + SAMM + CSF + CMMI assessment in one engagement are almost always padding scope. Pick one.

## Who succeeds with maturity programmes

- Programmes with an executive sponsor who cares about the *roadmap*, not the *score*.
- Teams who treat the model as a vocabulary and let engineering own implementation.
- Organisations that re-assess on a fixed cadence (annual is plenty) and report deltas, not absolutes.
- Security leaders who can translate maturity gaps into business-risk language — see [[ciso-vciso-track]] and [[grc-analyst-career-track]] for the people doing this work.

## Who fails

- Programmes driven entirely by GRC, with no engineering buy-in.
- Teams that pay for an external assessment, file the report, and change nothing.
- Leaders who target "all 3s" across the board — gold-plating that drains budget from real risk.
- Organisations that run BSIMM, SAMM, CSF and CMMI simultaneously without a single owner.

## Related

- [[appsec-maturity-checklist]]
- [[secure-sdlc-rollout-playbook]]
- [[building-an-iso27001-isms-practitioner]]
- [[building-a-pci-dss-program-practitioner]]
- [[devsecops-platform-engineering]]
- [[policy-and-standards-writing]]
- [[soc2-vs-iso27001]]
- [[appsec-threat-modeling]]
- [[sast-dast-ci-integration]]
- [[third-party-risk-management-practitioner]]
- [[audit-evidence-sampling-and-scoring]]
- [[ciso-vciso-track]]
- [[grc-analyst-career-track]]
- [[tabletop-exercise-design-and-execution]]
- [[detection-engineering-pyramid-of-pain]]

## References

- BSIMM annual reports and framework — https://www.bsimm.com/
- OWASP SAMM v2 — https://owaspsamm.org/
- NIST Cybersecurity Framework 2.0 — https://www.nist.gov/cyberframework
- ISACA CMMI Cybermaturity Platform — https://www.isaca.org/enterprise/cmmi-cybermaturity-platform
- OWASP SAMM toolbox and benchmark — https://owaspsamm.org/benchmarking/
- NIST CSF 2.0 Reference Tool — https://www.nist.gov/cyberframework/csf-20-reference-tool
