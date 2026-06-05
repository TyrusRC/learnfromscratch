---
title: Security auditor — career track
slug: security-auditor-career-track
aliases: [auditor-career, security-auditor-track]
---

> **TL;DR:** Security auditors review controls — they do not design or implement them. You will spend most of your time gathering evidence, interviewing control owners, and writing reports that map findings to a framework like SOC 2, ISO 27001, or PCI DSS. The work is steady, the exit options are wide (in-house GRC, CISO track, consulting), but busy season is brutal and the role is closer to accounting than to hacking. Companion notes: [[ciso-vciso-track]], [[grc-analyst-career-track]], [[soc2-vs-iso27001]].

## Why it matters

Every regulated company — banks, healthcare, SaaS selling to enterprise, anyone touching cards or PHI — needs auditors to sign off on their control environment. That demand is durable and counter-cyclical: when budgets tighten, audit headcount usually grows because the board wants assurance, not more pen tests. If you want a security career with predictable hours (most of the year), clear promotion ladders, and a path into executive roles like [[ciso-vciso-track]], audit is one of the cleanest tracks in.

It is also one of the most misunderstood. New entrants often expect to "find vulnerabilities" the way a pen-tester does — see [[pentest-engagement-execution]] and [[red-team-vs-pentest-engagement-shape]]. That is not the job. The job is to determine whether the control the client claims to operate is **designed** appropriately and **operating** effectively, based on evidence the client provides. You write opinions, not exploits.

## What the role actually is

### Review vs design vs implement

A security engineer **implements** a control (deploys EDR, writes a detection — see [[detection-engineering-pyramid-of-pain]] and [[edr-rules-as-code-from-attack-patterns]]). A GRC analyst (see [[grc-analyst-career-track]]) often **designs** the control and writes the policy. An auditor **reviews** whether the control exists, is documented, and is working — and produces an opinion that a third party (customer, regulator, board) can rely on.

The independence requirement matters: if you helped design or implement a control, you generally cannot audit it. That is why most large companies separate internal audit from the security team organizationally, and why external auditors rotate engagement partners.

### Day-to-day work

A typical week looks something like:

- **Walkthroughs and interviews.** You sit with the control owner — say, the engineer responsible for [[cloud-ir-aws-cloudtrail]] log retention — and ask them to describe how the control works. You take notes, you confirm your understanding, you ask "what could go wrong."
- **Evidence collection.** You request screenshots, ticket exports, configuration snapshots, access reviews, sample logs. You spend a depressing amount of time chasing people in Slack for evidence they promised last week.
- **Sampling and testing.** For a population of, say, 400 production changes in scope, you pick a statistically defensible sample (often 25-40 items) and test each: was it approved, peer-reviewed, ticketed, deployed to the right environment?
- **Workpaper documentation.** Every test gets a workpaper: what you tested, how you tested it, what you concluded. This is what gets peer-reviewed and what defends your opinion if a regulator ever asks.
- **Findings and reporting.** Exceptions get written up, discussed with management, and either remediated, accepted, or escalated. You draft the final report.

Companion notes that show the **other side** of these interviews — what the auditee is doing — include [[pci-dss-4-implementation]], [[hipaa-security-rule]], and [[secure-sdlc-rollout-playbook]].

## Employer types

### Big Four (Deloitte, EY, PwC, KPMG)

The default starting place. Largest training budgets, strongest brand on a resume, deepest bench of methodologies. You will be a "Cyber Risk" or "Risk Assurance" associate, billed out at hundreds of dollars an hour while making a fraction of that. Expect heavy travel pre-COVID, more hybrid now, and busy season hours of 60-80/week from January through April. Promotion is up-or-out: ~2 years per level, with senior manager / director the typical ceiling unless you make partner.

### Specialist firms (A-LIGN, Schellman, Sensiba, Coalfire, BARR)

These do SOC 2, ISO 27001, HITRUST, PCI, FedRAMP at scale — many of them more SOC 2 reports than the Big Four combined. Smaller teams, more direct client contact earlier, less internal bureaucracy. Often better quality of life and comparable comp at senior levels. Worse brand recognition outside the industry, but excellent inside it. If your goal is to become a real subject-matter expert on [[soc2-vs-iso27001]] or FedRAMP, these are arguably the better choice than Big Four.

### In-house internal audit

Banks, insurers, large tech, healthcare. You audit your own employer. Better hours, no travel, less variety, but you get to see the same systems year after year and develop genuine depth. Often the bridge into a CISO-adjacent role — see [[ciso-vciso-track]]. Pay is lower than external for the first few years but catches up with seniority, and the benefits and stability are usually better.

### Boutique / freelance

Once you have 8-10 years experience and a CISA / CISSP, freelance SOC 2 auditing through firms like Prescient Assurance is a viable lifestyle play. Lower comp ceiling, much higher autonomy.

## Career path and timeline

A typical Big Four / specialist firm ladder:

- **Associate / Staff (years 0-2).** Execute test procedures handed to you. Pass CISA exam in year 1-2. Salary: USD 65-90k base + bonus in US tier-1 cities; GBP 35-50k in London; EUR 40-55k in Frankfurt/Paris; SGD 55-75k in Singapore; USD 25-40k in major LatAm hubs.
- **Senior / Senior Associate (years 2-5).** Run individual engagements, manage 2-4 juniors, draft reports. Salary: USD 90-130k base in US; GBP 55-80k London; SGD 80-110k Singapore.
- **Manager (years 5-8).** Own a portfolio of clients, sell follow-on work, manage 10-20 people across engagements. First real exposure to business development. Salary: USD 140-200k base + 15-30% bonus in US.
- **Senior Manager (years 8-12).** Own a service line or vertical. Significant sales pressure. USD 200-280k base + bonus.
- **Director / Partner (years 12+).** Equity partner roles at Big Four can clear USD 500k-1.5M total comp, but the bar is sales, not technical skill. Most people exit before this point.

In-house track is flatter: Auditor → Senior Auditor → Audit Manager → Director of Internal Audit → VP/Chief Audit Executive, with comp scaling more slowly but more predictably.

## Comparison to other security careers

| Track | Hours | Travel | Tech depth | Exit options | Burnout driver |
|---|---|---|---|---|---|
| External audit | Brutal busy season, calm summer | Moderate-high | Medium | GRC, CISO, in-house audit | Busy season + up-or-out |
| Internal audit | Steady 40-50 | Low | Medium | CISO, risk officer | Repetition, politics |
| GRC analyst — see [[grc-analyst-career-track]] | Steady | Low | Low-medium | Audit, CISO | Policy churn, vendor reviews |
| Pen-tester — see [[bug-bounty-as-career-track]] | Project-driven, intense bursts | High historically | High | Red team, research, founder | Report-writing fatigue, scope grind |
| SOC analyst — see [[ir-from-source-signals]] | Shift work | None | Medium | Detection eng, IR, threat intel | Alert volume, shift schedule |
| Detection engineer | Steady | Low | High | Security eng, research | Tool churn, on-call |

Audit pays comparably to GRC at the junior level, pulls ahead at manager level, and trails specialized technical roles (red team leads, principal detection engineers) at the top.

## Defensive baseline — what makes a successful auditor

This is the closest thing this note has to "defensive baseline" — habits that protect your career.

- **Document everything.** If it is not in the workpaper, it did not happen. The same discipline that makes a good IR report — see [[pentest-report-writing-deep]] — makes a good audit workpaper.
- **Learn one framework deeply before going wide.** Pick SOC 2 or ISO 27001 — see [[soc2-vs-iso27001]] — and become the person on your team who can recite the criteria from memory.
- **Read the underlying technology.** Auditors who can read a [[cloud-ir-aws-cloudtrail]] log, understand [[bloodhound]] output, or speak to [[adcs-attacks]] earn credibility with engineering teams. Auditors who only speak in control language get ignored and get bad evidence.
- **Treat evidence requests like API calls.** Be specific, time-boxed, and idempotent. "Please send the access review for prod-db, performed between 2026-01-01 and 2026-03-31, in CSV with reviewer name and decision per row."
- **Protect your independence.** Never advise on a control you will audit. This is the single fastest career-ender in audit.

## Workflow to study

### Month 1-3: foundations

- Read the AICPA Trust Services Criteria and one full sample SOC 2 Type 2 report end to end.
- Read ISO 27001:2022 + ISO 27002 control list.
- Skim [[pci-dss-4-implementation]] and [[hipaa-security-rule]] so you recognize the controls.
- Start studying for CISA (the entry-level audit cert that actually matters).

### Month 4-9: technical context

- Stand up a home lab — see [[building-a-research-home-lab]] — with AWS, an IdP, an EDR. Audit your own environment against SOC 2 CC criteria.
- Read [[secure-sdlc-rollout-playbook]] and [[appsec-maturity-checklist]] so you understand what "good" looks like on the engineering side.
- Practice writing one workpaper a week using publicly available evidence (your own GitHub, your own cloud account).

### Month 10-18: get hired and survive year one

- Apply to Big Four cyber risk practices, specialist firms, and in-house IA teams in parallel.
- During interviews, ask about busy season hours, utilization targets, and how disagreements with engagement managers are escalated — these answers tell you more than the comp letter.
- In year one, focus on: passing CISA, never missing a workpaper deadline, and finding one senior who will mentor you.

### Year 2-3: specialize

- Pick a vertical (FinServ, healthcare, SaaS, FedRAMP) and stick with it long enough to know the systems.
- Add a second cert: CISSP for breadth, CCSK / CCSP for cloud, or HITRUST CCSFP if you go healthcare.
- Start contributing to proposals and methodology updates — that is what gets you promoted to manager.

## Who succeeds vs who burns out

**Succeeds:** former accountants who already speak audit, engineers who like writing more than coding, people who can stay calm during a client argument over a finding, people who treat documentation as craft rather than chore.

**Burns out:** people who entered audit hoping to "do security" and resent the paperwork; people who cannot say no to scope creep; people who internalize every client pushback as personal; people who try to white-knuckle four consecutive busy seasons without taking real vacation in between.

## Transitions in and out

**Into audit:**
- *Engineering -> audit.* Common and welcomed. Your technical depth shortens walkthroughs and earns engineering respect. Be ready for a pay cut at the associate level that pays back at manager.
- *Accounting -> cyber audit.* The traditional path. You already know audit; you need to learn the technology — start with [[detection-engineering-pyramid-of-pain]] and [[ir-from-source-signals]].
- *Consulting (non-audit) -> audit.* Easy if your background includes risk or compliance.

**Out of audit:**
- *Audit -> in-house GRC / [[grc-analyst-career-track]].* Most common exit at the senior / manager level. Better hours, comparable comp.
- *Audit -> CISO / [[ciso-vciso-track]].* The cleanest path if you also pick up technical security and business acumen. Many CISOs at regulated firms come through internal audit.
- *Audit -> founder.* The SOC 2 / compliance-automation startup space (Drata, Vanta, Secureframe, Thoropass) was largely built by ex-auditors who got tired of the manual evidence chase.
- *Audit -> regulator.* Federal Reserve, FFIEC, OCC, FCA, MAS all hire experienced auditors and pay surprisingly competitively when you include pension.

## Related

- [[grc-analyst-career-track]]
- [[ciso-vciso-track]]
- [[soc2-vs-iso27001]]
- [[pci-dss-4-implementation]]
- [[hipaa-security-rule]]
- [[nis2-implementation]]
- [[gdpr-incident-implications]]
- [[secure-sdlc-rollout-playbook]]
- [[appsec-maturity-checklist]]
- [[bug-bounty-as-career-track]]
- [[ctf-to-bug-bounty-transition]]
- [[building-a-research-home-lab]]

## References

- ISACA — CISA certification and review manual: https://www.isaca.org/credentialing/cisa
- AICPA — SOC 2 Trust Services Criteria: https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2
- IIA — International Standards for the Professional Practice of Internal Auditing: https://www.theiia.org/en/standards/
- AICPA — SSAE 18 / SSAE 21 attestation standards: https://us.aicpa.org/research/standards/auditattest/ssae.html
- Robert Half — annual Technology Salary Guide (audit and risk roles): https://www.roberthalf.com/us/en/insights/salary-guide
- ISO — ISO/IEC 27001:2022 overview: https://www.iso.org/standard/27001
