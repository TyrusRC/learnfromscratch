---
title: Cyber insurance — practitioner perspective
slug: cyber-insurance-practitioner
aliases: [cyber-insurance, cyber-liability-insurance]
---

> **TL;DR:** Cyber insurance has shifted from a "buy a policy, forget about it" line item to a forcing function for security investment. Underwriters now ask hard questions about MFA, EDR, tested backups, and supply-chain controls — and they will exclude or void coverage if you fluff the answers. Treat the application as an internal audit; treat the policy as a contract that will be litigated; and pre-wire the breach panel (IR, legal, PR) before you need it. Companion to [[ciso-vciso-track]], [[ransomware-affiliate-playbook]], [[ir-from-source-signals]], [[third-party-risk-management-practitioner]], and [[crisis-communications-cyber]].

## Why it matters

Cyber insurance sits at an awkward intersection of risk transfer, compliance, and operational security. For a CISO or vCISO it is one of the few mechanisms that translates security posture into a number a CFO understands — premium, retention, sublimit. For the security team it is a recurring deadline that forces honest answers about controls that have been promised on roadmaps for years.

The market lessons from 2020–2024 changed the shape of the product:

- **2020–2021 ransomware wave** (Conti, REvil, DarkSide) drove combined loss ratios above 70% for many carriers. Premiums spiked, sublimits for ransomware appeared, and the days of $5M towers with a $25k retention ended.
- **NotPetya (2017)** litigation (Mondelez vs Zurich, Merck vs Ace) reshaped war exclusion language. Insurers now use clearer "cyber operations" exclusions, and the buyer has to read them.
- **2022–2024 hardening** brought capacity back but with a much stricter security questionnaire. By 2024 the market softened modestly, but the questionnaire bar did not retreat.
- **DORA (Jan 2025)** and [[nis2-implementation]] pushed financial and critical-sector firms to formalise ICT risk programs, which interacts directly with how underwriters price.

If your organisation handles regulated data, processes payments ([[building-a-pci-dss-program-practitioner]]), or runs critical services, cyber insurance is no longer optional — but neither is the operational work it demands.

## Coverage classes and patterns

### First-party coverage

What the policy pays for *your* losses:

- **Incident response costs** — forensics, containment, legal counsel. Usually drawn from a panel (see below).
- **Business interruption (BI)** — lost revenue during downtime. Almost always has a waiting period (8–24 hours) and a measurement window. Contingent BI covers outages caused by *your* vendors — increasingly important after [[case-study-moveit-2023]] and [[case-study-solarwinds-2020]].
- **Data restoration** — cost to rebuild data and systems from backups (or from scratch when backups are bad).
- **Ransom / extortion payment** — coverage for the payment itself plus negotiation services. Many policies now sublimit this aggressively or require pre-approval. OFAC compliance is the carrier's problem and yours.
- **Regulatory fines and penalties** — covered where insurable by local law. GDPR fines are *not* insurable in some EU jurisdictions; check the wording against [[gdpr-incident-implications]].
- **Notification costs** — credit monitoring, call centres, mailings. Big driver of cost in US-style breach notification regimes.

### Third-party coverage

What the policy pays for *others'* losses you caused:

- **Privacy liability** — class actions, regulator-led actions.
- **Network security liability** — downstream impact when your compromise is a stepping stone (the [[case-study-okta-2023-support-system]] shape).
- **Media liability** — defamation, IP infringement on owned content. Often bundled.
- **PCI fines and assessments** — separate sublimit, often capped well below the tower. Read [[building-a-pci-dss-program-practitioner]] for context on what triggers these.

### Increasingly common add-ons

- **Reputational harm** post-breach revenue loss.
- **Social engineering / funds transfer fraud** — wire fraud cover. Sublimited; many carriers require dual-control attestations.
- **Bricking** — replacement of physical hardware rendered unusable by a cyber event.
- **Systems failure** (non-malicious outages) — for some carriers.

## The application process

### Modern questionnaire deep-dive

Underwriters' questionnaires in 2024 routinely cover:

- **MFA**: enforced for *all* remote access, *all* admin access, *all* email, *all* VPN, *all* critical SaaS. "Almost all" is not an acceptable answer. Conditional access bypass risk ([[conditional-access-bypass-modern]], [[aitm-evilginx-modern-phishing]]) means the bar is rising — phishing-resistant MFA (FIDO2) is being asked about on financial and tech accounts.
- **EDR**: not antivirus. Coverage of every endpoint and server, 24/7 monitoring (yours or MDR), with tamper protection. They will ask which vendor.
- **Backups**: tested restoration within last 12 months, immutable / offline copy, segregated credentials, retention period documented.
- **Email security**: DMARC at quarantine or reject, attachment sandboxing, link rewriting.
- **Privileged access**: PAM solution, just-in-time admin, separate admin accounts.
- **Vulnerability management**: critical patches within X days, scanning cadence, internet-facing inventory.
- **Network segmentation**: flat-network shops get penalised. OT segmentation is its own question for manufacturing ([[manufacturing-ot-defender-playbook]]).
- **Supply chain**: vendor inventory, TPRM program ([[third-party-risk-management-practitioner]]), software bill of materials for critical systems, response to incidents like [[cve-2024-3094-xz-utils-backdoor]].
- **Incident response**: documented plan, tabletop exercises in last 12 months ([[tabletop-exercise-design-and-execution]]), retainer with IR firm.

### Honest disclosure matters

The application is a warranty. Lying on it — or letting marketing-speak through — is the single most common path to a denied claim. The post-incident forensic report will reveal the actual state. Two patterns to avoid:

- "MFA is enforced" when in reality there are exceptions for service accounts, helpdesk break-glass, or that one legacy app. List the exceptions.
- "EDR on all endpoints" when domain controllers run a different agent or are excluded "for stability." Document the gap and the compensating control.

A CISO who fills the form themselves and writes a memo of caveats has saved their employer more in expected claim payouts than they will admit.

## Exclusions to read carefully

- **Act of war / cyber operations**: post-NotPetya these clauses are sharper. Lloyd's 2023 model wording carves out state-backed activity. State attribution is a litigation battlefield — see [[apt-tradecraft-russian-svr-fsb]] for context on why attribution is fuzzy.
- **Prior known facts**: anything you knew at bind time. If a pen test ([[pentest-report-writing-deep]]) flagged the exact vulnerability that later got exploited and you sat on it, expect a fight.
- **Gross negligence / wilful misconduct**: rarely a problem unless something egregious like ignoring a CISA Known Exploited Vulnerabilities alert for months.
- **Unpatched systems** sublimit or exclusion if patch beyond X days.
- **End-of-life software** exclusions.
- **Insider acts** — usually carved out, sometimes a sublimit.
- **Infrastructure failure** (upstream ISP, power, cloud provider outage) often excluded unless contingent BI is purchased.

## Retentions, sublimits, towers

- **Retention (deductible)**: scales with revenue. Mid-market shops often see $100k–$500k; large enterprises into the millions. Higher retention = lower premium but watch for separate retentions on ransomware or BI.
- **Sublimits**: ransomware, social engineering, regulatory fines, BI often capped well below the aggregate. The published "tower" of $20M may include only $5M for ransomware.
- **Coinsurance**: increasingly common — insurer pays 50–80% of certain losses, you pay the rest above retention.
- **Tower structure**: primary layer + excess carriers. Each excess layer has its own warranty representations. Misalignment across the tower is a litigation source.

## Market dynamics 2021–2024

- **2021–2022**: premiums up 50–100% YoY, capacity withdrawn from sectors like healthcare ([[healthcare-sector-defender-playbook]]) and public sector. Many policies dropped to 50% sublimit for ransomware.
- **2023**: market stabilised, new MGAs entered, premium increases moderated.
- **2024**: soft market for well-controlled buyers; loss ratios improved. But controls bar is now table stakes — without MFA + EDR + tested backups, you may not be quoted.
- **Capacity**: large complex risks still struggle for full $200M+ towers.

## Regulatory drivers

- **DORA** (EU, Jan 2025): financial sector ICT risk management is mandated, with third-party register requirements that overlap heavily with insurance underwriting. See [[nis2-implementation]] for sister framework.
- **SEC cyber disclosure rules** (US, 2023): material incident disclosure within 4 business days. Drives demand for crisis comms ([[crisis-communications-cyber]]) and structured IR.
- **State breach notification laws** drive first-party notification cost lines.
- **Sectoral regulators** ([[hipaa-security-rule]], [[pci-dss-4-implementation]]) interact with what is and isn't covered.

## Insurance as a control-investment forcing function

Used well, the renewal cycle becomes a free internal audit:

- **Pre-renewal gap analysis** 3 months out: walk the questionnaire honestly, score gaps, brief the exec sponsor.
- **Translate gaps into budget asks**: "without phishing-resistant MFA on admin accounts, our premium goes up $X and we lose the ransomware sublimit."
- **Use carrier-required controls** as your minimum security baseline. Aligns nicely with [[appsec-maturity-checklist]] and [[secure-sdlc-rollout-playbook]] in tech-heavy orgs.
- **Tabletop with broker present** — they will tell you which scenarios will be contested.

The CISO who builds the renewal into the annual planning cycle finds it easier to fund EDR rollout, PAM, and segmentation. See [[ciso-vciso-track]] for how this fits the broader role.

## Breach response coordination

When an incident hits, the policy dictates the workflow:

- **Notify the carrier within hours** (often a contractual deadline) — usually via a 24/7 hotline.
- **Use panel counsel** ("breach coach") — privileged communications hub. They will engage other panel vendors.
- **Panel IR firms**: Mandiant, CrowdStrike, Charles River Associates, Kroll, Unit 42, Arete, Stroz Friedberg, Coveware (for negotiation). Pre-approval of preferred firms during binding lets you keep your own [[ir-from-source-signals]] team in the loop.
- **Negotiation**: Coveware, GroupSense, Arete handle ransom negotiation. Carrier may insist on these.
- **Public communications**: panel PR firms (e.g., Edelman, Brunswick) — but coordinate with internal team ([[crisis-communications-cyber]]).

A practical pattern: in peacetime, run a [[tabletop-exercise-design-and-execution]] with the broker and panel coach in the room. You will learn faster than from any policy reading.

## Defensive baseline that maps to underwriting

If you want to be insurable at reasonable cost in 2024–2025:

- MFA everywhere, phishing-resistant for admins.
- EDR on every endpoint and server with 24/7 monitoring.
- Immutable + offline backup, restoration tested annually.
- Documented IR plan, tabletop in last 12 months, retainer in place.
- Vendor risk program with concentration-risk awareness.
- Email security with DMARC reject, sandboxing, link rewriting.
- Patch SLA for internet-facing services in single-digit days.
- Privileged access management for admin accounts.
- Internet-facing inventory accurate within 30 days.

## Workflow to study

1. **Read your current policy end-to-end**, including exclusions and definitions. Most CISOs have not.
2. Get a copy of last year's **application and supplemental questionnaires**. Walk them against reality with the relevant control owners.
3. Shadow the **broker meeting** for the next renewal. Ask the broker to mark up the questionnaire with what carriers care about most.
4. Map each questionnaire item to evidence — same hygiene as [[audit-evidence-sampling-and-scoring]].
5. Run a **tabletop** scenario that exercises the carrier hotline, breach coach engagement, and IR firm handoff.
6. Read 2–3 industry **incident reports** ([[case-study-moveit-2023]], [[case-study-lastpass-2022]], [[case-study-snowflake-2024]]) and trace which coverage lines would have been hit.
7. Run a **dry renewal** internally 90 days before bind. Identify the 2–3 controls you want delivered before submission.

## Common organisational mistakes

- **Under-coverage** — buying $5M because that's the budget when realistic BI losses are $40M.
- **Under-disclosure** on application — gives the carrier a clean rescission path.
- **Treating the policy as a checkbox** — never reading the wording until claim time.
- **No IR retainer** — engaging an IR firm during an active incident is slower and costlier than via panel.
- **Ignoring the supply chain question** — your vendors' incidents trigger your contingent BI, and you have no visibility.
- **Marketing-language answers** — "robust", "industry-leading" are not answers and will be picked apart.
- **Single-buyer (CISO-only) renewal** — Legal, Finance, Risk, IT all need to sign the application. Disconnects show in the policy.
- **Forgetting the broker** — a strong broker is worth more than the cheapest premium.

## Vendor marketing vs reality

- "Cyber insurance pays for everything." It pays for what the wording says. Read it.
- "Sublimits don't really matter." Tell that to a ransomware victim with a $1M sublimit on a $40M tower.
- "Carriers always pay." They pay when the application is accurate, the controls were as represented, and the exclusion doesn't bite.
- "Just use the carrier's IR firm." Sometimes the panel firm is excellent (Mandiant, Unit 42). Sometimes it's a smaller shop you have never worked with. Pre-approve known partners during binding.

## References

- https://www.lloyds.com/news-and-insights/risk-reports — Lloyd's market reports on cyber.
- https://www.naic.org/cipr_topics/topic_cyber_risk.htm — NAIC cyber insurance data calls (US).
- https://www.eiopa.europa.eu/browse/digital-finance-and-innovation/cyber-resilience_en — EIOPA cyber resilience and insurance work.
- https://www.cisa.gov/resources-tools/resources/cyber-insurance — CISA primer on cyber insurance basics.
- https://www.coveware.com/blog — Coveware quarterly ransomware reports, useful for benchmarking ransom and downtime.
- https://www.advisen.com/ — Loss data and benchmarking (industry standard data source).

## Related

- [[ciso-vciso-track]]
- [[ransomware-affiliate-playbook]]
- [[ir-from-source-signals]]
- [[third-party-risk-management-practitioner]]
- [[crisis-communications-cyber]]
- [[tabletop-exercise-design-and-execution]]
- [[nis2-implementation]]
- [[gdpr-incident-implications]]
- [[building-a-pci-dss-program-practitioner]]
- [[case-study-moveit-2023]]
- [[case-study-lastpass-2022]]
- [[case-study-snowflake-2024]]
- [[financial-sector-defender-playbook]]
- [[healthcare-sector-defender-playbook]]
- [[appsec-maturity-checklist]]
