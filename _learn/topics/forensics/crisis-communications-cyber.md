---
title: Crisis communications — cyber incidents
slug: crisis-communications-cyber
aliases: [crisis-comms-cyber, incident-communications]
---

> **TL;DR:** Crisis communications during a cyber incident is the discipline of telling stakeholders (employees, customers, regulators, board, media, partners) what they need to hear, when they need to hear it, in language that is factual and legally defensible. Most companies are bad at it because they treat comms as an afterthought to the technical IR workstream. The well-handled incidents (Maersk's NotPetya, CloudNordic's transparent customer comms) share traits: single spokesperson, factual discipline, no speculation, and rapid cadence. The badly-handled ones ([[case-study-equifax-2017]], [[case-study-lastpass-2022]]) share opposite traits: shifting narratives, missed disclosure deadlines, executive stock sales pre-announcement, and revision-after-revision blog posts that erode trust. This is a companion to [[tabletop-exercise-design-and-execution]] and [[gdpr-incident-implications]].

## Why it matters

The technical IR team can do everything right — contain the threat actor in 6 hours, fully eradicate, restore from backups — and the company can still lose more value from botched communications than from the breach itself. Equifax 2017 is the canonical example: the breach itself was bad, but the comms (delayed disclosure, executive stock sales, a hastily-stood-up consumer-lookup site on a typosquattable domain, arbitration clauses snuck into the relief offer) turned a serious incident into a generational reputation event and a $1.4B+ settlement.

Crisis comms is also where regulatory exposure compounds fastest. Miss the [[gdpr-incident-implications]] 72-hour notification window and you're looking at a separate enforcement action on top of the breach. Miss the SEC 8-K 4-business-day window after a determination of materiality and you have an SEC enforcement matter. Send a holding statement that contradicts what shows up in discovery later and plaintiffs' counsel uses it against you in class action.

For practitioners, comms is not "PR's problem." Incident responders feed the facts that comms turns into statements. If the IR lead can't articulate "what we know, what we don't know, and what we're doing" cleanly every 4 hours during an active incident, comms will fill the void with assumptions.

## Classes and patterns

### Stakeholder mapping

Before any incident, map who you will need to talk to and who owns each channel. Common groupings:

- **Employees** — internal comms / HR / CEO email. They will leak to media if you don't communicate, so they need accurate info fast, often before customers.
- **Customers** — account managers (B2B) or email + status page (B2C). B2B customers often have contractual notification clauses with tighter timelines than regulators.
- **Regulators** — DPO/privacy counsel handles GDPR/CCPA; general counsel handles SEC; sector regulators (NYDFS, OCC, FCA, MAS, FFIEC) have their own forms and timelines. See [[nis2-implementation]], [[pdpa-singapore]], [[dpdp-india]].
- **Board and executive leadership** — CEO, board chair, audit committee. They need decision-quality briefings, not raw IOCs.
- **Media** — PR firm or in-house comms. Inbound press inquiries hit within hours of any leak.
- **Partners and suppliers** — anyone whose data or systems touch yours. Includes downstream customers if you're a SaaS provider (see [[case-study-okta-2023-support-system]]).
- **Law enforcement** — FBI/IC3 in US, NCA in UK, local cyber units. Usually voluntary but recommended for ransomware.
- **Cyber insurance carrier** — must notify within hours-to-days per policy or risk coverage denial.
- **Investors and analysts** (public companies) — IR team coordinates with general counsel on Reg FD timing.

### Holding statements

A holding statement is what you publish when you know something is wrong but don't yet have facts to share. Template structure:

1. Acknowledge: "We are investigating reports of unauthorized access to [system]."
2. Action: "Upon detection, we engaged [external IR firm] and notified law enforcement."
3. Commitment: "We will provide updates as we learn more. Affected customers will be notified directly."
4. Channel: "For questions, contact [dedicated email or page]."

What a holding statement does NOT do: speculate on cause, name a threat actor, confirm data exfiltration before you have evidence, or commit to a numeric impact ("fewer than X records") that you'll have to revise upward.

### Factual discipline — the "what we know" framework

Every external statement and every internal briefing follows three buckets:

- **What we know** — only facts confirmed by evidence (logs, forensics, threat actor communications). Cite source if internal.
- **What we don't know yet** — explicitly list the open questions. This is uncomfortable but prevents the "but you said..." problem later.
- **What we're doing about it** — current containment, eradication, and recovery actions. Names of external firms engaged.

When in doubt, undersell impact in early statements and revise downward later, never upward. [[case-study-lastpass-2022]] revised upward across multiple blog posts over months, which is how trust dies.

### Spokesperson designation

Designate ONE external spokesperson per audience and rehearse them. Default pattern:

- CEO for major media and customers.
- CISO or CTO for technical press and customer technical teams.
- General counsel for regulators.
- HR/internal comms lead for employees.

Anyone else who gets a press inquiry says "I'll refer that to [name]." No exceptions. The fastest way to a contradictory public record is two executives improvising answers in separate interviews.

### What to disclose vs withhold — counsel-driven

Default to over-disclose on impact to affected parties, under-disclose on attacker TTPs and ongoing investigation details. Counsel makes the final call because:

- Attorney-client privilege over forensic findings can be lost if details are shared publicly before privilege analysis.
- Regulatory disclosures are sworn — wrong facts have personal liability for officers signing.
- Insurance coverage can be voided by public statements that conflict with policy notification language.
- Class action plaintiffs use every public statement as evidence. "Reasonable" or "industry-standard" claims become discovery questions.

Things typically withheld in early phase: specific malware family (until confirmed), threat actor attribution, exact technical IOCs that would tip the actor, names of affected enterprise customers (until they consent), ransom amount, whether ransom was paid.

### Social media monitoring during incident

Stand up a monitoring cell within hours. Track:

- Brand mentions on X/Twitter, LinkedIn, Reddit, Mastodon, Bluesky.
- Leak sites and ransomware blogs (does the actor publish a victim listing).
- Telegram and Discord channels (extortion negotiations and victim shaming).
- Employee posts (LinkedIn "looking for opportunities" spikes are leading indicators).
- Customer subreddits and Slack/Discord communities.
- Journalists' DMs and tip lines (Brian Krebs, Catalin Cimpanu, Lawrence Abrams, Joe Tidy, Kim Zetter, etc.).

Goal is not to respond on social, it's to detect narrative drift early and update spokespeople. Companion to [[cti-collection-management]].

## Regulatory disclosure timelines

Memorize the major ones because they drive incident-command tempo.

| Regulation | Trigger | Window |
|------------|---------|--------|
| SEC Item 1.05 8-K (US public companies) | Determination of materiality | 4 business days |
| GDPR Article 33 | Awareness of personal data breach | 72 hours to supervisory authority |
| GDPR Article 34 | High risk to data subjects | Without undue delay to subjects |
| NIS2 (EU) | Significant incident | 24 hours early warning, 72 hours notification, 1 month final report |
| NYDFS 500.17 | Determination of cybersecurity event | 72 hours |
| HIPAA Breach Notification | Discovery, 500+ affected | 60 days to individuals and HHS; immediate media notice |
| DORA (EU financial) | Major ICT incident | Initial 4 hours after classification, intermediate 72 hours |
| CIRCIA (US critical infra, when active) | Substantial cyber incident | 72 hours; 24 hours for ransom payment |
| PDPA Singapore | Notifiable breach | 3 days to PDPC |
| UK GDPR / DPA 2018 | Personal data breach | 72 hours to ICO |
| Australian Privacy Act NDB | Eligible breach | 30 days |

Materiality determinations are themselves comms events. The SEC has signaled it will pursue companies for delaying the "determination" to game the 4-day clock.

## Workflow to study

### Pre-incident preparation (weeks)

1. Build the stakeholder map and assign owners. Refresh quarterly.
2. Pre-draft 5-10 holding statement templates by scenario: ransomware, data exfil, business email compromise, third-party breach (see [[third-party-risk-management-practitioner]]), insider, DDoS extortion.
3. Pre-draft regulatory notification templates with placeholders for jurisdiction-specific elements.
4. Establish out-of-band comms channels. If your primary email and Slack are compromised, what's the fallback? Signal groups, personal email list, dial-in bridge with rotating PIN.
5. Stand up a dark site or pre-built incident page on a separate domain (not a subdomain) that can be activated in minutes.
6. Run [[tabletop-exercise-design-and-execution]] that includes comms injects (media call, customer escalation, regulator outreach).

### During incident (hours to weeks)

1. War room with technical IR (see [[soc-runbook-design]]), legal, comms, and an exec sponsor in one bridge.
2. Cadence: situation report every 4 hours initially, daily after stabilization.
3. Internal-first principle: tell employees before customers when possible, customers before regulators when permitted, regulators before media.
4. Single source of truth document tracking every public statement, every regulator filing, and the underlying facts at time of statement.
5. Log inbound press inquiries with timestamp, journalist, outlet, deadline, and response.
6. Track stakeholder commitments ("we will notify by X date") in a register and meet them.

### Post-incident (months)

1. Public after-action statement once investigation concludes. Be specific about root cause and remediation.
2. Customer-facing technical write-up for B2B accounts. CloudNordic and Cloudflare have good templates.
3. Internal lessons-learned that updates the playbook, templates, and tabletop scenarios.
4. Regulator follow-up filings, breach roster updates as numbers firm up.
5. Litigation hold maintenance — comms artifacts are discoverable.

## Case examples

### Well-handled

- **Maersk NotPetya (2017)** — CEO Soren Skou did public interviews early, was transparent about the wipe-and-rebuild scope (45,000 PCs, 4,000 servers), didn't blame customers or vendors. The company recovered reputationally faster than the technical recovery.
- **CloudNordic (2023)** — Danish hosting provider lost all customer data to ransomware with no recoverable backups. Public statement was brutally honest: "All customer data is lost, we cannot recover it, we recommend customers find alternative providers." Brutal but trusted.
- **Cloudflare 2023 Okta-related incident** — published a detailed timeline within days, named the upstream cause ([[case-study-okta-2023-support-system]]), showed the detection-and-response sequence.
- **Norsk Hydro (2019)** — daily press briefings during LockerGoga ransomware, refused to pay, transparent about manual operations workarounds.

### Badly-handled

- **Equifax (2017)** — see [[case-study-equifax-2017]]. Delayed disclosure, executive stock sales between detection and announcement, typosquattable consumer-lookup site, arbitration clause walked back under pressure, multiple revisions of impact numbers.
- **LastPass (2022)** — see [[case-study-lastpass-2022]]. Initial blog post downplayed impact, subsequent revisions over four months kept expanding scope (vault data exfiltrated, including encrypted password fields plus unencrypted URL fields). Each revision destroyed more trust than the underlying facts warranted.
- **Uber (2016, disclosed 2017)** — CISO paid attackers as a "bug bounty" to suppress disclosure. Resulted in criminal conviction of the CISO and a permanent case study in what not to do.
- **SolarWinds (2020)** — see [[case-study-solarwinds-2020]]. CEO comments blaming an intern for a weak password became a meme and a reputational liability separate from the breach.

## Defensive baseline

- Pre-drafted holding statements for the top 5 scenarios, reviewed by counsel.
- Documented stakeholder map with owner, channel, and fallback contact.
- Pre-built dark site or incident page.
- Annual tabletop with comms injects, separate from technical purple-team work (see [[purple-team-feedback-loop]]).
- Out-of-band comms tested quarterly.
- Cyber insurance notification process documented and rehearsed.
- Counsel relationship pre-established with breach response firm.
- Forensic firm on retainer with privilege protections agreed in advance.

## Practitioner reality check

Crisis comms looks easy in slides and is brutal in practice. Realistic effort:

- Building the program from zero: 3-6 months of part-time effort across security, comms, legal, HR.
- Tabletop with comms injects: 2-4 weeks prep, half-day exercise, 1-2 weeks after-action.
- During a real incident: comms lead works 16-hour days for the first week, expect to be the bottleneck on every external statement.

Who succeeds: people who can write clearly under time pressure, hold a line against executives who want to spin, and translate technical findings into stakeholder-relevant language. Legal background helps. Pure PR background without security context tends to produce statements that satisfy media but anger regulators.

Vendor marketing vs reality: "AI-powered crisis comms platforms" don't exist meaningfully. The tooling is a shared doc, a war room bridge, and a stakeholder tracker. The judgement is human. Buy table-stakes monitoring (Meltwater, Brandwatch, or similar) and spend the rest of the budget on retainers with a PR firm experienced in cyber, breach counsel, and a forensics firm.

## References

- [https://www.sec.gov/news/press-release/2023-139](https://www.sec.gov/news/press-release/2023-139) — SEC final rule on cybersecurity disclosure
- [https://edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-92022-personal-data-breach-notification-under_en](https://edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-92022-personal-data-breach-notification-under_en) — EDPB breach notification guidelines
- [https://www.enisa.europa.eu/topics/cybersecurity-policy/nis-directive-new](https://www.enisa.europa.eu/topics/cybersecurity-policy/nis-directive-new) — ENISA NIS2 resources
- [https://www.cisa.gov/topics/cybersecurity-best-practices/organizations-and-cyber-safety/cyber-incident-response](https://www.cisa.gov/topics/cybersecurity-best-practices/organizations-and-cyber-safety/cyber-incident-response) — CISA incident response guidance
- [https://krebsonsecurity.com/category/data-breaches/](https://krebsonsecurity.com/category/data-breaches/) — Krebs on Security breach archive
- [https://blog.cloudflare.com/thanksgiving-2023-security-incident/](https://blog.cloudflare.com/thanksgiving-2023-security-incident/) — Cloudflare 2023 disclosure as comms template

## Related

- [[tabletop-exercise-design-and-execution]]
- [[case-study-lastpass-2022]]
- [[case-study-equifax-2017]]
- [[case-study-okta-2023-support-system]]
- [[case-study-solarwinds-2020]]
- [[case-study-moveit-2023]]
- [[case-study-snowflake-2024]]
- [[gdpr-incident-implications]]
- [[nis2-implementation]]
- [[ciso-vciso-track]]
- [[third-party-risk-management-practitioner]]
- [[policy-and-standards-writing]]
- [[soc-runbook-design]]
- [[purple-team-feedback-loop]]
- [[ir-from-source-signals]]
- [[ransomware-affiliate-playbook]]
