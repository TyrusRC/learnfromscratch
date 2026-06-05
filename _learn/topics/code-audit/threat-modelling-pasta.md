---
title: Threat modelling — PASTA methodology
slug: threat-modelling-pasta
aliases: [pasta-threat-modelling, process-for-attack-simulation]
---

> **TL;DR:** PASTA (Process for Attack Simulation and Threat Analysis) is a seven-stage, risk-centric threat modelling methodology developed by Tony UcedaVélez and Marco Morana. Unlike [[threat-modelling-stride-deep]] which is bottom-up and component-focused, PASTA is top-down and starts from business objectives, walking through technical scope, decomposition, threat intel, weaknesses, attack modelling, and finally risk and impact. It is heavier-weight than STRIDE or [[attack-tree-methodology]] and only pays off on high-stakes systems — financial platforms, healthcare clinical apps, mission-critical infrastructure — where the output feeds a real risk register and treatment decisions, not a SharePoint folder. See also [[threat-modelling-linddun-privacy]] and [[appsec-threat-modeling]].

## Why it matters

Most threat modelling in the wild is STRIDE-on-a-whiteboard: engineers list components, brainstorm threats per element, and produce a backlog of mitigations. That works for individual services but breaks down when leadership asks "what is the actual business risk if this system is compromised, and is our spend on controls proportional to that risk?"

PASTA was designed to answer that question. It is built around the idea that:

- threat modelling should start with **business objectives**, not with boxes and arrows
- threats are not abstract — they come from **real threat actors** with motives, targeting your specific assets
- the output is a **risk-ranked attack scenario list** with quantified impact, suitable for risk committees and budget conversations

It is the methodology most commonly invoked in regulated, high-blast-radius contexts: payment systems ([[building-a-pci-dss-program-practitioner]]), clinical platforms ([[healthcare-sector-defender-playbook]]), trading systems, critical national infrastructure ([[nis2-implementation]]).

### Where PASTA fits in the methodology landscape

| Methodology | Orientation | Strength | Weakness |
|---|---|---|---|
| STRIDE | Bottom-up, per-element | Fast, dev-friendly | Component-myopic; ignores business context |
| LINDDUN | Privacy-focused | Maps GDPR-style risks | Narrow scope outside privacy |
| Attack trees | Goal-decomposition | Visual, intuitive | No risk quantification |
| PASTA | Top-down, business-driven | Risk-quantified, intel-informed | Heavy; weeks to months of effort |
| OCTAVE / FAIR | Pure risk analysis | Quantitative | Not technically grounded |

PASTA borrows from FAIR for risk framing and from MITRE ATT&CK for the attack modelling stage, so in practice it is a **synthesis methodology** rather than a clean-room invention.

## The seven stages

PASTA's defining feature is its sequential, gated process. Each stage produces an artefact that feeds the next. Skipping stages — common in practice — defeats the methodology.

### Stage 1 — Define business objectives

Identify the business goals the system supports, the regulatory and contractual obligations attached (PCI DSS, HIPAA, SOC 2, contractual SLAs), and the **risk appetite** of the organisation. Output: a "business impact reference" you can later use to weight attack scenarios.

Typical inputs: BIA from the business continuity team, regulatory register from [[grc-analyst-career-track]], existing risk register entries.

### Stage 2 — Define the technical scope

Enumerate the technical assets in play: applications, services, network boundaries, third-party dependencies, data stores, identity providers. This is the **boundary-setting** stage — what is in scope, what is not, and where the trust boundaries fall. Output: technical architecture document with explicit scope boundaries.

Practitioners commonly conflate this with stage 3 (decomposition). They are different: stage 2 is "what exists", stage 3 is "how it works internally".

### Stage 3 — Application decomposition

Decompose the in-scope system into data flows, components, trust boundaries, and entry/exit points. This is where you produce DFDs — the same artefact STRIDE uses, but here it is one stage of seven rather than the whole exercise. Output: detailed data flow diagrams, asset inventory, trust boundary map.

If you stop here and run STRIDE per element, you have… run STRIDE. Don't claim PASTA.

### Stage 4 — Threat analysis

Bring in **threat intelligence**: who realistically targets systems like yours, what TTPs do they use, what are their motives? This stage anchors the whole methodology in reality. For a fintech app you would pull from [[apt-tradecraft-dprk-lazarus]] (DPRK targets crypto/finance) and [[ransomware-affiliate-playbook]]; for a healthcare clinical system, [[healthcare-sector-defender-playbook]] threat actors; for a critical-infrastructure operator, nation-state TTPs from [[apt-tradecraft-russian-svr-fsb]] and [[apt-tradecraft-chinese-mss]].

Output: relevant threat actor catalogue with TTPs, mapped to MITRE ATT&CK where possible. Feeds [[cti-collection-management]].

### Stage 5 — Vulnerability and weakness analysis

Map the threats from stage 4 onto the technical surface from stages 2–3. Where do the actor's TTPs land against your real weaknesses? This pulls from SAST/DAST findings ([[sast-dast-ci-integration]]), pentest reports, IaC review ([[terraform-and-iac-source-audit]]), and known CVEs in your stack.

Output: weakness register correlated with actor TTPs.

### Stage 6 — Attack modelling

Build **attack trees** or attack graphs showing realistic paths from actor capability through identified weaknesses to business-impacting outcomes. This is where [[attack-tree-methodology]] formally enters PASTA — as one stage of seven. You can also overlay BloodHound-style paths ([[bloodhound]]) for AD-resident systems, or kill-chain narratives for ransomware ([[ransomware-affiliate-playbook]]).

Output: attack scenarios, each with a path through the technical environment ending in a business-relevant outcome.

### Stage 7 — Risk and impact analysis

Score each attack scenario for likelihood (informed by stage 4 threat intel + stage 5 weakness exposure) and impact (informed by stage 1 business objectives). Common scoring frameworks: FAIR for quantitative, a 5x5 qualitative matrix for lighter-weight programs. Output: ranked attack scenario list with treatment recommendations.

This output feeds:

- the corporate **risk register** (accept / mitigate / transfer / avoid)
- security **roadmap prioritisation**
- **control investment** conversations with finance
- pentest scoping ([[pentest-proposal-and-scoping]]) — the scenarios become test objectives
- detection engineering backlogs ([[detection-engineering-pyramid-of-pain]], [[siem-detection-use-case-catalog]])

## When PASTA is worth the investment

Be honest: PASTA on a small internal CRUD app is malpractice. Use STRIDE in 90 minutes and move on. PASTA pays off when:

- the system is **mission-critical** or **high-revenue** (trading platform, payment switch, EHR, energy SCADA gateway)
- regulators or contracts expect **demonstrable risk-based decisions** (PCI DSS req 12, HIPAA risk analysis, NIS2/DORA equivalents)
- the threat actor landscape is **non-trivial and varied** — not "script kiddies", but a mix of insiders, nation states, organised crime
- leadership will actually **read and act on** the output

If any of those are not true, run a lighter methodology and document why. Methodology-over-fit is its own risk.

### Realistic effort

A genuine PASTA exercise on a single complex system runs:

- 2–6 weeks elapsed time
- 40–120 person-hours across security, architecture, threat intel, and business stakeholders
- requires a facilitator with both threat modelling fluency and risk-analysis literacy
- expect 1–3 weeks of stakeholder scheduling friction on top of the analysis itself

Vendors selling "PASTA in a day" workshops are selling stages 1–3 with a sticker on top.

## Common practitioner mistakes

- **Treating PASTA as documentation rather than analysis.** Stages exist to produce decisions. If the output is a 90-page PDF nobody opens, the methodology failed.
- **Skipping stage 4 (threat intel).** Without real-actor framing, you get the same generic threat list you would from STRIDE. The intel grounding is the differentiator.
- **Skipping stage 7 (risk scoring).** Without quantified output, leadership cannot prioritise. The whole point of going top-down was to land here.
- **Running PASTA once, never refreshing.** Threat landscapes change. A PASTA from 2022 that has not been refreshed against post-LockBit-takedown ransomware shifts is stale.
- **Confusing PASTA with STRIDE-with-business-context.** PASTA is explicitly attack-simulation. If you are not modelling attacker paths in stage 6, you are doing something else.
- **Using PASTA for everything.** It is for high-stakes systems. Routine microservice changes do not need it.
- **No traceability between stages.** Each artefact should reference the prior. Auditors will ask, "how did this attack scenario derive from your threat actor list?" You need to show the chain.

## Defensive baseline outputs

A well-run PASTA produces concrete artefacts that downstream teams should consume:

- **Risk register entries** — scored attack scenarios with treatment decisions, owned by a named accountable executive
- **Detection use cases** — feeding [[siem-detection-use-case-catalog]] and [[edr-rules-as-code-from-attack-patterns]]
- **Pentest scenarios** — for the next [[pentest-engagement-execution]] or [[red-team-vs-pentest-engagement-shape]] red team engagement
- **Tabletop scenarios** — feeding [[tabletop-exercise-design-and-execution]]
- **Architecture decisions** — secure design changes informed by stages 5–6
- **Control investment proposals** — quantified asks to finance, anchored in business impact

If your PASTA does not produce at least four of those six outputs, it was a documentation exercise.

## Workflow to study

1. Read UcedaVélez and Morana's book *Risk Centric Threat Modeling: Process for Attack Simulation and Threat Analysis* — the canonical source.
2. Pick a system you know well — a payment app, an EHR module, an authentication service.
3. Run stage 1 in isolation: spend 60 minutes writing the business objectives, regulatory ties, and risk appetite. Notice how this differs from "what are the components?"
4. Run stages 2 and 3 separately. Resist the urge to merge them.
5. For stage 4, pull a real threat intel report relevant to your sector (industry ISAC, government advisories, vendor reports) and extract three actors with TTPs.
6. For stage 6, build attack trees per [[attack-tree-methodology]] grounded in those three actors.
7. Score with a simple 5x5 first, then try FAIR on your top 3 scenarios. Compare.
8. Present the output to a non-security stakeholder. If their first question is "so what should we do?", your stage 7 was not strong enough.
9. Cross-reference outputs against [[appsec-threat-modeling]] and [[secure-sdlc-rollout-playbook]] integration points.

## Related

- [[threat-modelling-stride-deep]]
- [[threat-modelling-linddun-privacy]]
- [[attack-tree-methodology]]
- [[appsec-threat-modeling]]
- [[appsec-maturity-checklist]]
- [[secure-sdlc-rollout-playbook]]
- [[cti-collection-management]]
- [[detection-engineering-pyramid-of-pain]]
- [[siem-detection-use-case-catalog]]
- [[pentest-proposal-and-scoping]]
- [[tabletop-exercise-design-and-execution]]
- [[cvss-scoring-practitioner]]
- [[financial-sector-defender-playbook]]
- [[healthcare-sector-defender-playbook]]
- [[building-a-pci-dss-program-practitioner]]

## References

- https://owasp.org/www-community/Threat_Modeling_Process — OWASP overview of threat modelling methodologies including PASTA
- https://versprite.com/tag/pasta-threat-modeling/ — VerSprite (UcedaVélez's firm) publications on PASTA
- https://www.wiley.com/en-us/Risk+Centric+Threat+Modeling%3A+Process+for+Attack+Simulation+and+Threat+Analysis-p-9780470500965 — canonical book by UcedaVélez and Morana
- https://attack.mitre.org/ — MITRE ATT&CK, used in stage 4 threat analysis
- https://www.fairinstitute.org/ — FAIR Institute, common quantitative scoring used in stage 7
- https://owasp.org/www-project-threat-model/ — OWASP Threat Model project, broader methodology context
