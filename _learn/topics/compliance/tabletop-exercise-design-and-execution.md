---
title: Tabletop exercise design and execution
slug: tabletop-exercise-design-and-execution
aliases: [tabletop-exercise, ttx-design]
---

> **TL;DR:** A tabletop exercise (TTX) is a discussion-based simulation that stress-tests your incident response plan, decision rights, and cross-functional muscle memory - not your tools. Good TTX design starts from the org's risk register, pulls in execs, IR, legal, comms, and key vendors, and forces real decisions under realistic time pressure. Run a hot-wash immediately and a cold-wash a week later, then track action items to closure. See [[ir-from-source-signals]] for the technical side and [[purple-team-feedback-loop]] for how TTX findings feed back into detection engineering.

## Why it matters

Most orgs have an incident response plan that nobody has read since the auditor signed off. The first time the CFO finds out they are the one who decides whether to pay a ransom is at 2am during a real ransomware event. That is the failure mode TTX exists to prevent.

Tabletop exercises:

- Validate that decision rights and escalation paths actually work end-to-end.
- Expose missing playbooks (extortion negotiation, regulator notification timelines, customer comms templates).
- Build relationships between teams that only meet during a crisis - SOC, legal counsel, outside breach coach, PR firm, cyber insurer.
- Satisfy regulatory and contractual obligations: DORA Article 25 requires financial entities to test digital operational resilience, NYDFS 23 NYCRR 500.16 mandates IR plan testing, HIPAA Security Rule requires periodic evaluation (see [[hipaa-security-rule]]), and PCI DSS 4.0 12.10.2 requires annual IR plan review and testing (see [[pci-dss-4-implementation]]).
- Surface the gap between the written plan and what people would actually do.

A TTX is cheap. A real incident where the General Counsel and CISO disagree about disclosure timing in front of the board is not.

## TTX vs other exercise types

Common confusion - these are different things:

- **Tabletop (TTX)** - discussion-based, no real systems touched. Focus on decisions, comms, governance. 2-4 hours typical.
- **Functional exercise** - some real actions taken in a controlled environment (e.g., actually invoke the DR failover runbook in a sandbox).
- **Full-scale drill** - production-like simulation, on-call paged, real ticketing, real comms cadence. Can run 8-24 hours.
- **Red team engagement** - adversary emulation against live infrastructure with limited defender knowledge. See [[red-team-vs-pentest-engagement-shape]].
- **Purple team** - collaborative attacker/defender exercise focused on detection coverage. See [[purple-team-feedback-loop]] and [[atomic-red-team-emulation-deep]].

TTX is the cheapest and highest-leverage starting point. You do not need a red team budget to find out your CEO does not know who their breach coach is.

## Participant selection

The biggest design mistake is running a TTX that is only the security team. The whole point is to exercise cross-functional decisions.

### Core roster

- **Executive sponsor** - CEO, COO, or CFO. Owns "pay or do not pay" type decisions, public statements, and resource authorization. Without an exec in the room, you cannot test the decisions that matter most.
- **CISO / security lead** - owns technical response coordination and the IR plan.
- **IR / SOC lead** - actually runs the technical investigation. Brings ground truth about what is detectable.
- **General Counsel or external breach counsel** - owns privilege, regulator notification, contractual notification obligations. Critical for GDPR 72-hour clock (see [[gdpr-incident-implications]]) and sector rules.
- **Head of Communications / PR** - owns customer, employee, media, and investor messaging.
- **IT / Infrastructure lead** - owns containment actions that affect uptime (isolating segments, rotating credentials, pulling backups).
- **HR** - if the scenario involves insider threat, employee impact, or staff comms.
- **Privacy officer / DPO** - mandatory if personal data is implicated.

### Extended roster (scenario-dependent)

- **Cyber insurance carrier contact** and breach coach (most policies require notification within hours; many TTXs discover the team has the wrong phone number).
- **Critical vendors** - MSSP, EDR vendor, cloud provider TAM, identity provider. For supply-chain scenarios like [[case-study-3cx-supply-chain]] or [[case-study-solarwinds-2020]], invite the affected vendor's incident liaison if the relationship exists.
- **Customer success / account management** - for B2B orgs, they will be fielding the calls.
- **Regulatory affairs** - sector-specific (financial services, healthcare, critical infrastructure under [[nis2-implementation]]).
- **Board observer** - annually, to give the audit committee chair a feel for the process.

### Who to leave out

- Junior analysts you want to "expose to executives" - they will not speak up and you will not get useful data. Run a separate technical drill for them.
- People with no decision authority and no comms role. They dilute the discussion.

## Scenario design

Scenarios should be derived from the organization's risk register, not from "what was in the news last week." If your top three risks are ransomware affecting manufacturing OT, third-party SaaS compromise affecting customer data, and insider data theft, those are your three TTX scenarios for the year.

### Common scenario archetypes

- **Ransomware with double extortion** - encryption + data theft + public leak threat. Forces decisions on payment, regulator notification, customer comms, and operational recovery. Use realistic affiliate tradecraft - see [[ransomware-affiliate-playbook]].
- **Supply chain compromise** - your build pipeline, an SBOM-relevant dependency, or a SaaS provider is the initial vector. Patterned on [[case-study-3cx-supply-chain]], [[case-study-solarwinds-2020]], or [[case-study-moveit-2023]].
- **Cloud identity compromise** - SSO/IdP token theft leading to data exfil. Patterned on [[case-study-okta-2023-support-system]] or [[case-study-snowflake-2024]]. Pulls in [[cloud-ir-aws-cloudtrail]] and [[conditional-access-bypass-modern]] type discussions.
- **Insider data theft** - departing employee, contractor with elevated access. HR-heavy, employment law nuances.
- **OT / safety event** - relevant for manufacturing, energy, water. See [[ics-scada-protocols-attacks]]. Safety-of-life decisions are different from data-loss decisions.
- **Regulatory breach with multi-jurisdiction notification** - GDPR + state breach laws + sector regulator + contractual customer notification all firing at once.
- **AI / model compromise** - prompt injection leading to data exfil, or model supply chain. See [[llm-eval-pipeline-poisoning]] and [[ai-agent-sandbox-design]].

### Scenario realism rules

- Use threat actor TTPs that match your actual risk - do not run a nation-state APT scenario at a 200-person SaaS company.
- Anchor in your real environment: real IdP, real EDR, real cloud provider, real critical vendors. Generic "the SIEM" loses everyone.
- Include ugly facts: a backup that is 14 days old instead of 24 hours, an EDR exclusion that someone added two years ago, the CISO is on vacation, the on-call legal counsel is new.
- Make the regulatory clock visible - GDPR 72 hours, SEC 4-business-day materiality disclosure for public US issuers, DORA major incident reporting.

## Inject design

Injects are the timed events that drive the exercise forward. A good TTX has 6-12 injects across 2-3 hours.

### Inject structure

Each inject should contain:

- **Time** - relative to T0 (incident detection). "T+45min" not "10:45am."
- **Channel** - how the information arrives: SOC alert, vendor call, journalist email, regulator inquiry, ransom note, social media post, customer complaint.
- **Content** - the actual artifact (mock SIEM screenshot, mock email, mock TOR ransom page, mock regulator letter).
- **Expected decision points** - what the facilitator is listening for. Not shown to participants.

### Inject pacing

A typical ransomware TTX might look like:

- T+0: SOC detects mass file modification on file server (SIEM alert mock).
- T+15min: EDR isolates 12 endpoints; user reports "files have weird extensions."
- T+30min: Backup admin reports backup repo is also encrypted.
- T+45min: Ransom note discovered, $4.2M demand, 72-hour countdown.
- T+90min: Journalist emails press@ asking for comment on "data breach affecting Customer X."
- T+2h: Threat actor posts sample data on leak site.
- T+4h (compressed): Customer X CISO calls demanding answers.
- T+24h (compressed): Regulator inquiry arrives.
- T+48h (compressed): Internal staff leak to social media.

Compressing time is fine - announce it clearly ("we are now fast-forwarding 20 hours").

## Facilitation pattern

- **Facilitator** - drives the timeline, delivers injects, keeps discussion on decisions not technical rabbit-holes. Often an external consultant for credibility, especially with execs.
- **Scribe** - captures decisions, action items, gaps, disagreements. Output is the raw material for the after-action report.
- **Subject matter experts (SMEs)** - on call to answer "could this actually happen?" or "what would CloudTrail show?" Do not let them take over the room.
- **Observers** - silent, taking notes for their function. Audit, internal controls, board reps.

Ground rules to state at the start:

- This is a no-fault learning exercise. Findings do not become performance feedback.
- Assume the scenario as presented; do not argue facts.
- When in doubt, make the decision you would actually make today, not the decision the plan says you should make.
- Silence is a finding. If nobody knows who decides X, that is what we are here to discover.

## Debrief: hot-wash and cold-wash

### Hot-wash (immediately after)

30-45 minutes, same room, same people. Three questions:

- What went well?
- What did not?
- What surprised you?

Capture raw. Do not start prioritizing yet - people are tired and emotional.

### Cold-wash (one week later)

Smaller group: facilitator, CISO, IR lead, scribe, one or two execs. Review the hot-wash notes with distance. Now prioritize:

- **Plan gaps** - playbooks that do not exist or are wrong.
- **Decision-rights gaps** - cases where nobody knew who decides.
- **Capability gaps** - tooling, staffing, vendor contracts.
- **Comms gaps** - missing templates, wrong contact lists, no holding statement.
- **Training gaps** - people who need familiarization with specific tools or procedures.

## Action item ownership and tracking

The most common TTX failure mode is a great exercise that produces a report that nobody reads. Prevent this:

- Every action item has a named owner (a person, not a team) and a due date.
- Items go into the same tracker as security program work (Jira, Linear, whatever - not a one-off spreadsheet).
- CISO reports closure rate to the audit committee or risk committee quarterly. Tie to [[appsec-maturity-checklist]] and [[secure-sdlc-rollout-playbook]] cadences.
- The next TTX explicitly tests whether the previous action items closed the gap.

## Frequency cadence

Realistic cadence for most orgs:

- **IR team / SOC tabletops** - quarterly. Technical and tactical. 90 minutes each. Different scenario each time.
- **Cross-functional TTX with execs** - annually at minimum, semi-annually for regulated industries. 3-4 hours.
- **Board-observed exercise** - annually, paired with the audit committee cyber update.
- **Sector-specific drills** - per regulator. Financial services under DORA, healthcare under HIPAA, energy under NERC CIP have their own requirements.
- **Post-incident replay** - after any significant real incident, run a TTX-style retrospective with the same playbook to validate fixes.

## Regulatory drivers

Practitioner framing (not legal advice - work with counsel on specifics):

- **DORA (EU financial)** - Article 24-26 require regular testing of ICT operational resilience including scenario-based exercises. Threat-led penetration testing (TLPT) for significant entities.
- **NYDFS 23 NYCRR 500** - Section 500.16 requires written IR plan and periodic testing.
- **NIS2** - see [[nis2-implementation]]. Member state implementations specify exercise frequency for essential and important entities.
- **PCI DSS 4.0** - 12.10.2 requires annual IR plan review and testing.
- **HIPAA Security Rule** - periodic evaluation requirement covers IR testing.
- **SEC cyber disclosure (US public companies)** - 8-K materiality disclosure within 4 business days drives TTX scenarios that practice the materiality determination process with legal + finance + CISO.
- **GDPR** - 72-hour supervisory authority notification clock. Practice it.

Document the exercise: scenario, participants, date, findings, action items, closure. Auditors and regulators will ask.

## Workflow to study

- Pull your top 3-5 risk register entries. Pick the one most likely to break decision-making, not just technical response.
- Draft a one-page scenario: threat actor, initial vector, business impact, timeline.
- Build 8-10 injects across the chosen duration. Get an SME to sanity-check realism.
- Confirm participant list and exec sponsor. Get calendars locked 4-6 weeks out.
- Pre-brief execs on the format (they hate surprises in front of peers) but not the scenario.
- Run the exercise. Facilitate, do not lecture.
- Hot-wash same day. Cold-wash one week later. After-action report within two weeks.
- Track action items to closure. Report progress quarterly.
- Repeat with a new scenario, ideally rotating across the risk register.

## Related

- [[ir-from-source-signals]]
- [[ransomware-affiliate-playbook]]
- [[case-study-3cx-supply-chain]]
- [[case-study-moveit-2023]]
- [[purple-team-feedback-loop]]
- [[ciso-vciso-track]]
- [[gdpr-incident-implications]]
- [[nis2-implementation]]
- [[pci-dss-4-implementation]]
- [[hipaa-security-rule]]
- [[atomic-red-team-emulation-deep]]
- [[red-team-vs-pentest-engagement-shape]]

## References

- CISA Tabletop Exercise Packages (CTEP) - https://www.cisa.gov/resources-tools/services/cisa-tabletop-exercise-packages
- NIST SP 800-84 Guide to Test, Training, and Exercise Programs for IT Plans and Capabilities - https://csrc.nist.gov/pubs/sp/800/84/final
- NIST SP 800-61r3 Computer Security Incident Handling Guide - https://csrc.nist.gov/pubs/sp/800/61/r3/final
- ENISA Good Practice Guide on National Exercises - https://www.enisa.europa.eu/publications/good-practice-guide-on-national-exercises
- DORA (Regulation EU 2022/2554) on digital operational resilience - https://eur-lex.europa.eu/eli/reg/2022/2554/oj
- NYDFS 23 NYCRR Part 500 cybersecurity requirements - https://www.dfs.ny.gov/industry_guidance/cybersecurity
