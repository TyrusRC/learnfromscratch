---
title: SOC tier 1 / 2 / 3 progression
slug: soc-tier-1-tier-2-tier-3-progression
aliases: [soc-tiers, soc-analyst-progression]
---

> **TL;DR:** The Tier 1 / Tier 2 / Tier 3 SOC model still anchors most security operations job ladders, but it is fraying. Tier 1 is alert triage and escalation, Tier 2 is investigation and containment, Tier 3 is hunting and advanced IR. The model breeds burnout at T1 and slow growth into engineering, which is why many mature shops are flattening into detection-engineer / threat-hunter / IR-engineer roles instead. This note is a realistic field guide for analysts deciding where to sit and where to go next. Companion reading: [[soc-runbook-design]], [[soc-ticket-hygiene-mttr]], [[detection-engineering-pyramid-of-pain]], [[security-auditor-career-track]], and [[bug-bounty-as-career-track]].

## Why it matters

The tier model is how most SOCs are staffed, how budgets are justified, and how analysts are paid. Getting the mental map right matters because:

- It determines what work you are *allowed* to do (writing detections, touching production, talking to legal).
- It determines what skills you can build on the clock vs. what you must learn on personal time.
- It heavily predicts whether you burn out in 18 months or grow into a senior engineering role.
- It shapes which exits are realistic: detection engineering, red team, GRC, cloud security, or out of security entirely.

If you understand the model and its failure modes, you can pick the right shop, negotiate the right scope, and plan an exit before T1 grinds you down.

## The classic three-tier model

### Tier 1: alert triage and escalation

Day-to-day reality:

- Sit on a queue (SIEM, EDR, ticketing) and work alerts as they fire.
- Apply a runbook ([[soc-runbook-design]]): check enrichment, pivot to user / asset / process context, decide true positive / false positive / benign true positive.
- Escalate to T2 with a short narrative when scope exceeds the runbook.
- Close noise (commodity malware blocked at EDR, expected vuln scans, known service accounts) with a clean disposition.
- Shift work is common: 24x7 follow-the-sun or rotating nights / weekends.

What T1 should *not* be doing in a healthy SOC:

- Writing new detections (that is detection engineering, see [[detection-engineering-pyramid-of-pain]]).
- Free-form threat hunting without a hypothesis fed by T3 / CTI.
- Talking to legal, regulators, customers, or executive stakeholders during an incident.
- Touching production endpoints beyond pre-approved containment actions.

Typical comp (US, 2025-2026): USD 55-85k base, often with a shift differential. EU equivalent: EUR 35-55k. APAC managed-SOC roles can be much lower. Burnout half-life is about 12-24 months.

### Tier 2: investigation and containment

Day-to-day reality:

- Pick up escalations and run them to a verdict.
- Pull EDR telemetry, sysmon, proxy / DNS / authentication logs and reconstruct a timeline.
- Execute containment: isolate host, disable account, revoke tokens, block IOC at the edge.
- Lead small incidents end-to-end with a T3 / IR lead in the loop.
- Write the post-incident ticket clearly enough that T3 and detection engineering can act on it.
- Feed [[purple-team-feedback-loop]] outcomes back into runbooks and rules.

T2 is where you start to specialise: cloud IR (see [[cloud-ir-aws-cloudtrail]], [[cloud-ir-azure-activity-log]], [[cloud-ir-gcp-audit-logs]], [[cloud-ir-k8s-audit-logs]]), identity ([[bloodhound]], [[adcs-attacks]], [[kerberoasting]]), or phishing / BEC ([[aitm-evilginx-modern-phishing]], [[oauth-device-code-phishing-m365]]).

Typical comp: USD 85-130k base. 2-4 years experience.

### Tier 3: advanced investigation, hunting, IR leadership

Day-to-day reality:

- Lead major incidents: ransomware, data exfil, supply-chain ([[case-study-3cx-supply-chain]], [[case-study-solarwinds-2020]]).
- Drive threat hunts from hypotheses informed by [[cti-collection-management]] and adversary tradecraft notes ([[apt-tradecraft-chinese-mss]], [[apt-tradecraft-russian-svr-fsb]], [[apt-tradecraft-dprk-lazarus]], [[apt-tradecraft-iranian-irgc]], [[ransomware-affiliate-playbook]]).
- Write or review custom detections, often in partnership with a detection-engineering team ([[siem-detection-use-case-catalog]], [[edr-rules-as-code-from-attack-patterns]]).
- Own the relationship with legal, comms, and exec stakeholders during incidents.
- Run tabletop exercises and post-mortems; influence architecture.
- Mentor T1 / T2 and approve their growth into harder queues.

Typical comp: USD 130-200k base, more in FAANG / finance. Often a principal / staff IC track or a manager fork.

## Critique of the tier model

### Alert fatigue and T1 burnout

T1 queues are usually fed by under-tuned detections written by people who do not work the queue. The result is a soul-grinding loop of false positives and benign-true-positives where the analyst has no authority to fix the upstream rule. See [[soc-ticket-hygiene-mttr]] for the operational symptoms (rising MTTR, falling close-rate quality).

### Slow and arbitrary progression

Many shops gate T2 promotion on tenure rather than demonstrated skill, while paying T1 below market. Strong analysts leave for detection-engineering roles at peers within 18 months.

### Hand-off losses

Tier hand-offs introduce context loss: T1 closes a ticket as benign, T2 never sees the cluster forming, T3 misses a low-and-slow campaign. Modern shops mitigate with shared cases, single-pane tooling, and "follow the alert" ownership.

### Modern alternatives

- **Detection engineer**: writes, tests, and tunes detections as code. Treats rules as software with CI, code review, and unit tests against [[atomic-red-team-emulation-deep]] outputs.
- **Threat hunter**: hypothesis-driven, time-boxed hunts informed by CTI and adversary emulation.
- **IR engineer / responder**: spends most cycles on the worst incidents and on automation of common containment.
- **DevSecOps / SRE-style SOC**: pager rotations, SLOs on detection coverage and MTTD / MTTR, postmortems, error budgets. Less "tier", more "on-call engineer". This is where the best US tech-company SOCs are heading.

## Defensive baseline: a healthy SOC

If you are evaluating an employer or running a SOC, look for:

- Detections owned by a detection-engineering function, not the queue.
- Runbooks ([[soc-runbook-design]]) maintained as code, version-controlled, reviewed.
- Quality metrics ([[soc-ticket-hygiene-mttr]]): MTTA, MTTD, MTTR, false-positive rate, escalation accuracy.
- CTI feeding hunts ([[cti-collection-management]]) and detections ([[detection-engineering-pyramid-of-pain]]).
- Purple-team loop ([[purple-team-feedback-loop]]) closing gaps quarterly.
- Career ladder with explicit promotion criteria and a non-managerial IC path.
- Hard limits on T1 shift length and consecutive nights.

## Workflow to study

Pick one path and commit for a quarter:

1. **Quarter 1 (T1 to T2 jump)**: master one EDR and one SIEM. Build a personal lab ([[building-a-research-home-lab]]) and run atomics ([[atomic-red-team-emulation-deep]]) to see what your detections catch. Document gaps.
2. **Quarter 2 (T2 to detection engineering)**: clone a public detection repo (Sigma, Splunk Security Content, Elastic detection rules). Write three new rules with tests against atomics. Submit a PR upstream.
3. **Quarter 3 (T2 to T3 / IR)**: pick one case study a month ([[case-study-snowflake-2024]], [[case-study-okta-2023-support-system]], [[case-study-moveit-2023]], [[case-study-lastpass-2022]], [[case-study-capital-one-2019]]) and rebuild the timeline from public sources. Write your own lessons-learned doc.
4. **Quarter 4 (specialise)**: pick one of cloud IR, identity, phishing, or ICS ([[ics-scada-protocols-attacks]]) and go deep enough to be the on-call expert.

## Common transitions

- **T1 to detection engineering**: highest-leverage exit. Requires Python / KQL / SPL fluency, version control, basic CI.
- **T2 to red team / pentest**: harder than people think; requires offensive depth ([[red-team-vs-pentest-engagement-shape]], [[pentest-engagement-execution]]). Often a sideways pay move at first.
- **T3 to IR consulting**: high pay, brutal hours, lots of travel.
- **Any tier to GRC**: stable hours, lower ceiling unless you go principal ([[security-auditor-career-track]]). Good fit if you like writing and stakeholder work.
- **Any tier to cloud security engineering**: hot market, often pays better than SOC.
- **Out of security**: SRE, platform engineering, data engineering. Your log-pipeline skills transfer well.
- **Bug bounty as a side or full track**: realistic but not for everyone, see [[bug-bounty-as-career-track]] and [[ctf-to-bug-bounty-transition]].

## Career advice that is actually honest

- T1 is a launchpad, not a career. Plan your exit before you start.
- Learn to write code. KQL, SPL, Python, a little Go. The analysts who get out of the queue are the ones who automate it.
- Keep a private incident journal. Sanitised summaries of every interesting ticket. This becomes your interview material and your promo packet.
- Pick a specialism early (cloud, identity, phishing, ICS, AI / agent risk like [[ai-agent-sandbox-design]] or [[llm-eval-pipeline-poisoning]]). Generalists plateau at T2.
- Read post-mortems weekly. Your own and other companies'.
- If your shop will not let you write detections after 12 months at T2, leave.
- Shift work damages health. Negotiate or rotate out by year three.
- Certs (GCIA, GCIH, GCFA, BTL1, CCD) matter for getting interviews, not for getting promoted. Code, write-ups, and incident war-stories matter for promotion.
- Who succeeds: curious, writes well, calm under pressure, codes a little, asks "why did this rule fire" not "what do I close it as".
- Who struggles: hates writing, treats alerts as quota, will not learn a scripting language, expects tenure to equal promotion.

## Related

- [[soc-runbook-design]]
- [[soc-ticket-hygiene-mttr]]
- [[detection-engineering-pyramid-of-pain]]
- [[security-auditor-career-track]]
- [[bug-bounty-as-career-track]]
- [[cti-collection-management]]
- [[siem-detection-use-case-catalog]]
- [[purple-team-feedback-loop]]
- [[ir-from-source-signals]]
- [[atomic-red-team-emulation-deep]]
- [[building-a-research-home-lab]]
- [[ctf-to-bug-bounty-transition]]

## References

- https://www.sans.org/white-papers/soc-survey-2024/
- https://www.gartner.com/en/documents/security-operations
- https://www.first.org/standards/frameworks/csirts/csirt_services_framework_v2.1
- https://attack.mitre.org/resources/
- https://detectionengineering.net/
- https://www.mandiant.com/resources/blog
