---
title: Security awareness training program — building
slug: security-training-program-building
aliases: [security-training, awareness-program]
---

> **TL;DR:** Building a security awareness program is not "buy KnowBe4, assign annual module, done." It is a multi-year culture program with audience-segmented content, ethical phishing simulations, leadership buy-in, and measurement that goes beyond click-through rate. Done well, it complements technical controls against [[aitm-evilginx-modern-phishing]], [[mfa-fatigue-tradecraft]], [[deepfake-assisted-phishing]], and [[voice-cloning-liveness-bypass]]. Done poorly, it produces compliance theatre and resentful employees who learn nothing. This note is a practitioner companion to [[appsec-champions-program]] focused on the human risk side rather than the engineering side.

## Why it matters

Phishing, business email compromise, vishing, and now deepfake-assisted social engineering remain the top initial-access vector across most industries. No amount of EDR, MFA, or [[conditional-access-bypass-modern]] hardening removes humans from the loop — they still approve transactions, reset passwords, click links, and answer phones.

Regulators have noticed. PCI DSS 12.6 mandates a security awareness program, HIPAA Security Rule requires "security awareness and training" under 164.308(a)(5), NIS2 calls out cyber hygiene training for management, and ISO 27001 control A.6.3 requires information security awareness, education and training. Compliance is the floor; the ceiling is whether your finance team actually pauses before wiring USD 8M to a "CEO" voice on a Zoom call (see [[deepfake-assisted-phishing]]).

A program also reduces blast radius from incidents you will inevitably suffer — see [[case-study-okta-2023-support-system]], [[case-study-snowflake-2024]], and [[case-study-lastpass-2022]] for what happens when human-layer attacks succeed.

## Audience segmentation

Generic "all-staff" content is the number-one failure mode. Different audiences face different threats and need different content, framing, and frequency.

### General staff (the 80%)

Baseline: phishing recognition, password and MFA hygiene, physical security (tailgating, lost devices), data handling, reporting channels. Keep it short (5–10 minutes), scenario-based, and translated into local languages.

### Engineering and developers

Secrets management, [[secrets-in-code-detection-patterns]], dependency hygiene ([[npm-postinstall-and-typosquat-audit]], [[python-pypi-supply-chain-audit]]), [[github-actions-workflow-source-audit]], threat modeling ([[appsec-threat-modeling]]), and secure SDLC ([[secure-sdlc-rollout-playbook]]). This audience hates generic awareness content; pair them with an [[appsec-champions-program]] instead.

### Executives and board

Concise, scenario-driven. Topics: wire fraud authorization, deepfake CEO calls, travel risk, personal-device compromise, board-portal hygiene. Often delivered as one-on-one briefings or [[tabletop-exercise-design-and-execution]] rather than e-learning. Tie to [[ciso-vciso-track]] reporting cadence.

### Finance, AP, and treasury

The number-one BEC target. Train on: vendor-bank-account-change verification, out-of-band callback procedures, invoice fraud, [[oauth-device-code-phishing-m365]] indicators. Pair with hard process controls — training alone never stops BEC.

### Customer-facing (support, sales, success)

Targeted by [[apt-tradecraft-dprk-lazarus]], support-impersonation (see [[case-study-okta-2023-support-system]]), and social-engineering of help desks. Focus on identity verification scripts, escalation triggers, and refusing to bypass policy "just this once."

### Privileged / admin

IT admins, HR, legal — high-value targets with broader access. Cover [[mfa-fatigue-tradecraft]], session-hijack indicators, [[adcs-attacks]] basics, and incident-reporting expectations.

## Training modalities

### E-learning modules

The compliance backbone. Good for baseline knowledge and audit evidence. Bad when treated as the entire program. Modules should be short, scenario-led, mobile-friendly, and refreshed at least yearly.

### Phishing simulation

The single most discussed component, and the most often done badly. Done well it creates muscle memory; done badly it creates resentment and gamed metrics.

### In-person / lunch-and-learn

Highest engagement, hardest to scale. Best used for executive briefings, post-incident debriefs, and targeted role-based sessions.

### Gamified / interactive

Capture-the-flag style, escape rooms, choose-your-own-adventure scenarios. Engagement spikes; retention is mixed unless reinforced.

### AI deepfake simulation

New category (2024–2026). Vendors now ship synthetic-voice and synthetic-video simulations that train staff on [[voice-cloning-liveness-bypass]] and CEO-fraud scenarios. Use sparingly and with strong consent — see ethics below.

### Just-in-time nudges

Banner on external email, warning on first-time sender, prompt before downloading from a new vendor. Often more effective than annual training because it teaches at the moment of risk.

## Platform vendors (honest take)

- **KnowBe4** — market leader, huge content library, strong phishing-sim engine, sales-driven. Content can feel dated; some modules are cringe. Reporting is solid.
- **Proofpoint Security Awareness (formerly Wombat)** — enterprise feel, integrates with Proofpoint email security telemetry. Good if you already run Proofpoint.
- **Hoxhunt** — Finnish, behaviour-change focused, gamified continuous phishing rather than annual modules. Strong engagement metrics; less of a compliance bookkeeping tool.
- **Wizer** — bite-sized video content, freemium tier, popular with mid-market and startups. Lightweight; not a full LMS.
- **Mimecast Awareness Training** — short comedic videos (the Trevor Noah-era style), bundled with Mimecast email. Polarizing — staff either love it or roll their eyes.
- **Living Security, Arctic Wolf, Infosec IQ, Curricula (now Huntress)** — credible alternatives depending on size, region, and price point.

Vendor marketing claim: "We reduce phishing click rate by 90%." Reality: any vendor will reduce a fresh baseline click rate substantially in year one. The hard part is sustaining behaviour at year three and shifting *report rate* upward, not just driving click rate to zero.

## Phishing simulation: cadence and content

### Cadence

Monthly is the sweet spot for most orgs. Quarterly is too sparse to build habits; weekly burns out staff and trains them to ignore "anything that looks weird is probably a test." Vary the day and time.

### Difficulty progression

Start easy (obvious spelling errors, mismatched domains). Progress to realistic lures based on current threat intel — see [[cti-collection-management]]. Eventually include red-team-grade simulations modelled on [[aitm-evilginx-modern-phishing]] and [[tycoon2fa-and-modern-phish-kits]].

### Content design

Tie lures to real org context: HR systems, payroll provider, the actual M365 tenant brand. Avoid lures that exploit emotional manipulation around layoffs, bonuses, or bereavement — they "work" but destroy trust. Some orgs have banned bonus-themed simulations after staff revolts (notably the West Midlands Trains backlash in 2021).

### Failure consequences

The correct response to a click is *more training, never punishment*. Termination-for-clicking policies are counterproductive — they drive non-reporting, which is far worse than clicking.

## Ethics of simulation

This deserves its own section because most programs get it wrong.

- **Consent and notice** — staff should know simulations happen, even if not when. Hidden, never-disclosed campaigns invite legal and works-council pushback (especially in Germany, France, and other EU jurisdictions with strong worker representation).
- **Fairness** — do not single out individuals publicly. Aggregate metrics, named coaching.
- **No blame** — the goal is to reduce risk, not to catch people out. "Wall of shame" approaches fail.
- **Topic boundaries** — avoid lures around health, family bereavement, layoffs, or anything that exploits acute personal stress.
- **Localisation** — translate, and adapt cultural references. A US-style "IRS audit" lure is meaningless in Singapore.

When in doubt, run simulation policy past HR, legal, and works council *before* launch, not after the first complaint.

## Measurement

Click-through rate (CTR) is the easiest metric and the most over-used. A mature program tracks:

- **Click rate** — trending down over time, segmented by department.
- **Report rate** — trending up. A team with a 5% click rate and 60% report rate is far healthier than one with 1% click and 5% report.
- **Time to first report** — minutes from send to first user report. Faster reporting shortens [[ir-from-source-signals]] and [[soc-runbook-design]] response.
- **Repeat clickers** — focused coaching cohort, not punishment cohort.
- **Real incident correlation** — did awareness training reduce successful BEC, credential phishing, or [[mfa-fatigue-tradecraft]] incidents? Hard to attribute cleanly, but the only metric leadership actually cares about.

Report into the [[ciso-vciso-track]] and risk committee quarterly. Tie to [[grc-analyst-career-track]] compliance evidence for PCI 12.6, HIPAA, ISO A.6.3.

## Regulatory drivers

- **PCI DSS 4.0 control 12.6** — formal awareness program required, with role-based content and at least annual training. See [[building-a-pci-dss-program-practitioner]] and [[pci-dss-4-implementation]].
- **HIPAA Security Rule 164.308(a)(5)** — security awareness and training for all workforce members. See [[hipaa-security-rule]] and [[healthcare-sector-defender-playbook]].
- **ISO 27001 A.6.3** — awareness, education, and training. Auditors expect attendance records and effectiveness measures, not just slide decks. See [[building-an-iso27001-isms-practitioner]].
- **NIS2 Article 20 and 21** — management-body cyber-training duty, plus organisation-wide hygiene. See [[nis2-implementation]].
- **SOC 2** — CC1 and CC2 controls touch awareness; auditors look for evidence. See [[soc2-vs-iso27001]].
- **GDPR** — Article 39 calls for DPO-led awareness; relevant for [[gdpr-incident-implications]].
- **Regional**: [[pdpa-singapore]], [[appi-japan]], [[lgpd-brazil]], [[dpdp-india]] all have training expectations under their security obligations.

## Modern AI-assisted training

Two distinct trends in 2024–2026:

1. **AI-generated lures for simulation** — vendors use LLMs to generate personalised, contextual phishing emails per recipient, mirroring real attacker tradecraft. Engagement-wise, this is the only way simulations keep up with modern attacker capability.
2. **AI tutors and adaptive content** — staff who fail a module get a conversational follow-up rather than a longer module. Early data is promising for retention.

Beware vendors who slap "AI" on the box without changing pedagogy. Ask for evidence of behavioural lift, not feature lists.

## Workflow to study (building a program from zero)

1. **Baseline** — run an unannounced phishing simulation and a knowledge-survey to set honest baselines. Do not skip; without baseline, year-three claims are meaningless.
2. **Policy and consent** — write a one-page program policy covering simulation use, ethics, data handling, and consequences. Get HR, legal, works council sign-off.
3. **Audience map** — segment as above. Identify champions per segment.
4. **Pick platform** — RFP three vendors against your real use cases, not feature lists. Negotiate on multi-year content refresh, not just licence cost.
5. **Year one** — monthly simulations starting easy, quarterly modules, monthly nudges, leadership briefings.
6. **Year two** — increase simulation difficulty, role-specific tracks live, tabletop exercises ([[tabletop-exercise-design-and-execution]]) for execs.
7. **Year three** — measure report rate as primary metric, integrate with SOC ([[soc-runbook-design]]) reporting workflow, run deepfake-scenario tabletops.
8. **Continuous** — incident-driven micro-learning. After any phishing incident, a 3-minute lesson goes out within 48 hours.

Realistic timeline: 18–36 months to shift culture meaningfully. Anyone promising six months is selling something.

## Common failure modes

- **Annual click-through training only** — compliance theatre, zero behaviour change.
- **No leadership buy-in** — execs skip their own training, staff notice, program dies.
- **Punitive culture** — non-reporting becomes the norm; SOC loses signal.
- **Vendor monoculture** — same KnowBe4 video every year, staff disengage.
- **No post-incident learning loop** — incidents happen, nothing changes in content.
- **Ignoring engineering and finance specifics** — generic content for high-risk roles.
- **Translating English content literally** — local staff disengage from content that doesn't speak to their context.
- **Measuring only click rate** — misses the report-rate story entirely.
- **Forgetting contractors and temps** — often the targeted population in supply-chain attacks; see [[third-party-risk-management-practitioner]].

## Who succeeds in running these programs

Hybrid backgrounds win: someone who has worked in L&D, internal comms, or HR *plus* understands the threat landscape. Pure technical security folks often build programs that resonate only with engineers. Pure L&D folks build content that misses the threat picture. The role often sits under the [[ciso-vciso-track]] but partners daily with HR, internal comms, and legal.

## References

- https://www.knowbe4.com/phishing-security-test
- https://www.sans.org/security-awareness-training/resources/managing-human-risk-report/
- https://www.cisa.gov/topics/cybersecurity-best-practices/cybersecurity-awareness-program-toolkit
- https://www.nist.gov/itl/applied-cybersecurity/nice/nice-framework-resource-center
- https://www.pcisecuritystandards.org/document_library/
- https://www.enisa.europa.eu/topics/cybersecurity-education/awareness-raising

## Related

- [[appsec-champions-program]]
- [[aitm-evilginx-modern-phishing]]
- [[deepfake-assisted-phishing]]
- [[voice-cloning-liveness-bypass]]
- [[mfa-fatigue-tradecraft]]
- [[oauth-device-code-phishing-m365]]
- [[tycoon2fa-and-modern-phish-kits]]
- [[conditional-access-bypass-modern]]
- [[tabletop-exercise-design-and-execution]]
- [[ciso-vciso-track]]
- [[grc-analyst-career-track]]
- [[building-a-pci-dss-program-practitioner]]
- [[building-an-iso27001-isms-practitioner]]
- [[hipaa-security-rule]]
- [[nis2-implementation]]
- [[case-study-okta-2023-support-system]]
- [[case-study-snowflake-2024]]
- [[case-study-lastpass-2022]]
- [[third-party-risk-management-practitioner]]
- [[healthcare-sector-defender-playbook]]
- [[financial-sector-defender-playbook]]
