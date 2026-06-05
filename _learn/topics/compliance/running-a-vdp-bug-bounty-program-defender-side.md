---
title: Running a VDP / bug-bounty program — defender side
slug: running-a-vdp-bug-bounty-program-defender-side
aliases: [vdp-defender, bug-bounty-program-operation]
---

> **TL;DR:** Running a Vulnerability Disclosure Program (VDP) or Bug Bounty Program (BBP) from the defender side is a security operations function, not a marketing project. It is roughly 20% report acceptance and 80% triage logistics, internal stakeholder management, SLA discipline, and budget defense. Companions: [[hackerone-platform-deep]], [[bugcrowd-platform-deep]], [[bounty-triage-from-hunters-view]], [[pre-disclosure-embargo-and-cve-coordination]], [[disclosure-and-comms]], [[responsible-disclosure-across-jurisdictions]].

## Why it matters

Without a public path to report vulnerabilities, finders default to one of three options: drop on Twitter / X, sell to a broker, or sit on it. None of those benefit the defender. A VDP is the minimum viable "we will not sue you if you report a bug" signal. A BBP layers monetary incentives on top to attract more and better researchers, but also creates expectations, disputes, and budget pressure.

The mistake most programs make is treating launch as the milestone. Launch is easy. What kills programs is the operational tail: slow triage, scope confusion, low-paying decisions that go viral, and bounty hunters publicly accusing the company of bad faith. A poorly-run program produces worse outcomes than no program at all because it signals that the company does not take security seriously and burns researcher goodwill.

This note is operational. For the finder-side view see [[bounty-triage-from-hunters-view]] and the report-writing companions [[report-writing]] and [[report-writing-step-by-step]].

## VDP vs BBP — the actual distinction

### VDP — Vulnerability Disclosure Program

- No monetary payout. Safe-harbour, scope, contact channel, response SLA.
- Required-ish for US federal civilian agencies (CISA BOD 20-01) and increasingly expected under EU CRA / NIS2 (see [[nis2-implementation]]).
- Can be self-hosted: `security.txt` (RFC 9116) plus a `security@` mailbox plus a public policy page is a legitimate VDP.
- Volume tends to be lower and noisier (more "missing security header" reports, more SEO-spam reports), because there is no payment filter.

### BBP — Bug Bounty Program

- Money attached. Schedule of payouts by severity, often $50 to $25,000+ for crown-jewel critical findings.
- Almost always run on a platform: HackerOne, Bugcrowd, Intigriti, YesWeHack. Self-hosted BBPs exist (Google, Meta, Microsoft, Apple) but require a dedicated team.
- Volume is higher and noisier at the low end but higher quality at the top end. Top researchers will not engage with programs that do not pay.
- Creates a payment-dispute surface that VDPs do not have.

A common pattern is to start as a VDP for 12 to 24 months, mature your triage muscle, then layer a private BBP on top, then go public bounty.

## Platform vs self-hosted

### Platform-managed (HackerOne / Bugcrowd / Intigriti / YesWeHack)

- See [[hackerone-platform-deep]] and [[bugcrowd-platform-deep]] for the inside view.
- Pros: pre-existing researcher pool, triage-as-a-service available, payments handled (1099 / tax forms, sanctions screening, currency conversion), platform-provided SLA dashboards.
- Cons: percentage cut (platform fees stack on top of bounties, often 20% of bounty value or a flat retainer in the tens of thousands USD per year), researcher relationship is partially mediated by the platform, less control over triage quality.
- Triage-as-a-service: platform staff filter out the obvious junk and do first-pass severity. Useful for small security teams. Risk: their triage analysts may not know your stack and may misclassify findings.

### Self-hosted (security.txt + security@)

- Pros: no platform fees, direct relationship with researchers, full control.
- Cons: you do the spam filtering, you handle payments yourself (KYC, sanctions, 1099-MISC or W-8BEN), you build the dashboard, you carry full reputational risk for slow response.
- Realistic only if you have at least one full-time triage engineer or are tiny enough that volume is naturally low.

## Legal safe-harbour wording

The single most important clause in your policy. Without it researchers won't engage, because under CFAA (US), Computer Misuse Act (UK), and equivalents, accessing a system "without authorization" is a crime. A safe-harbour clause grants explicit authorization for in-scope testing.

Use the Disclose.io template (`disclose.io`) as a starting point — it has been legally reviewed and is widely recognized. Key elements:

- "We will not pursue civil action or initiate a complaint to law enforcement for accidental, good-faith violations of this policy."
- "We consider activities conducted consistent with this policy to constitute authorized conduct under the Computer Fraud and Abuse Act."
- DMCA safe-harbour for security research, if you ship software clients.
- Clear statement on third-party services: most safe-harbours only cover assets you own. Researchers testing your SaaS dependencies are on their own.

See [[responsible-disclosure-across-jurisdictions]] for the cross-border nuance — your safe-harbour clause does not bind foreign prosecutors, and researchers in jurisdictions with weaker computer-crime law (or, conversely, harsher law like some EU member states pre-CRA) need to know that.

## Scope definition and scope drift

### Defining scope at launch

- List in-scope assets explicitly (domains, mobile apps, API endpoints, IP ranges).
- List out-of-scope assets explicitly (marketing sites on third-party CMS, vendor-hosted helpdesk, recently acquired companies still in IT integration).
- List out-of-scope vulnerability classes: rate limiting on contact forms, SPF / DMARC misconfig without exploitation, self-XSS, missing security headers without proven impact, clickjacking on unauthenticated pages, etc.
- List banned testing techniques: DoS / volumetric, social engineering of employees, physical intrusion, automated scanning above N requests per second.

### Scope drift

The most common operational failure. Three patterns:

1. **Acquisition drift** — company buys Acme Corp, their assets are now technically yours, but they are not in your VDP scope. Researchers find a bug on `acme.example.com`, you say out-of-scope, they argue the parent company is in scope. Update scope within 90 days of any acquisition.
2. **Subdomain drift** — `*.example.com` is in scope, marketing spins up `campaign-2026.example.com` on a sketchy third-party WordPress host, researcher finds RCE, the third-party vendor threatens to sue. Maintain an asset inventory and an exclusion subdomain list.
3. **API version drift** — `api.example.com/v3` is in scope, legacy `api.example.com/v1` deprecated but still reachable. Researchers will hit it. Decide in advance whether legacy gets bounties.

## Triage staffing — in-house vs platform

### In-house triage

- Best signal-to-noise. Your engineers know your stack and can validate severity quickly.
- Expensive in engineer-hours. Estimate 0.5 FTE per 30 to 50 reports per month at a public BBP, more during launch surge.
- Triage engineers burn out. Rotate. The role is psychologically draining (hostile researchers, dupe arguments, weekend escalations).

### Platform-managed triage

- HackerOne H1 Triage / Bugcrowd ASE / Intigriti Managed Service.
- They filter out informational and N/A, validate reproducibility, assign initial severity.
- You still need an internal owner who decides on bounty amount, drives remediation, and signs off on disclosure.
- Quality varies by platform analyst pool. Audit a sample of their decisions quarterly.

### Hybrid

- Platform handles tier-1 (spam, dupes, informationals). In-house handles tier-2+ (validation, severity calls, bounty decisions, remediation).
- Most mature programs run this model.

## SLAs that actually matter

Publish them. Hit them. Track them publicly on the platform's dashboard if possible.

| Stage | Realistic SLA | Aggressive SLA |
|---|---|---|
| Initial response (human acknowledgement) | 5 business days | 24 hours |
| Triage decision (valid / invalid / dupe) | 14 days | 3 business days |
| Severity confirmed | 21 days | 5 business days |
| Bounty paid (post-triage) | 30 days | 7 days |
| Vulnerability resolved (P1 / critical) | 30 days | 7 days |
| Vulnerability resolved (P3 / medium) | 90 days | 30 days |

Researchers compare programs publicly. A 90-day "time to bounty" is reputationally fatal. See [[bounty-triage-from-hunters-view]] for what they see.

## Bounty schedule design

- Publish a table by severity (Critical / High / Medium / Low) with ranges, not single numbers. Ranges give triage flexibility.
- Critical for a fintech or healthcare program should start at $5,000 minimum to be competitive. Top-tier crown-jewel critical at $25,000 to $50,000.
- Bonus modifiers: chained exploit, novel technique, high-quality report (a multiplier for clean reproduction steps, see [[report-writing-step-by-step]]).
- Avoid "up to" without a floor. Researchers read "up to $10,000" as "we will pay you $500."
- Use [[cvss-scoring-practitioner]] as a starting point for severity but document where you override CVSS for business context.

## Internal stakeholders

This is where programs die quietly.

- **Engineering** — owns remediation. Carve out engineering capacity for security bug fix work *before* launch, not after. A common failure: the security team accepts a critical, engineering says "next quarter," the researcher publishes after the disclosure embargo expires.
- **Legal** — owns safe-harbour, NDA-on-payout if applicable, sanctions screening (you cannot pay researchers in OFAC-sanctioned countries), tax reporting.
- **PR / comms** — owns external disclosure, CVE assignment coordination. Pre-disclosure embargoes matter (see [[pre-disclosure-embargo-and-cve-coordination]] and [[disclosure-and-comms]]).
- **Finance** — owns the bounty budget. Budget by quarter, with a 50% contingency for unexpected criticals.
- **Executive sponsor** — VP-level. Needed for budget defense and for backing the program when an embarrassing bug surfaces.

## Measurement — signal vs noise

Track and report quarterly:

- Reports received, valid percentage. Valid rate below 15% suggests scope or program description is unclear.
- Severity distribution. If you never see criticals, scope may be too narrow.
- Time-to-X for each SLA stage. Mean and p90.
- MTTR per severity for engineering remediation. Distinct from triage SLA.
- Repeat-finder retention — what percentage of top-20 researchers submit again in the next quarter? Drop-off signals friction.
- Bounty payout vs budget. If you are 200% over budget on criticals, that is good news, not bad — pay the bounties.
- Duplicate rate. High dupes mean either popular bug class or slow triage letting reports stack up.

## Common operational failure modes

- **Slow triage damaging reputation.** Researcher posts "no response in 60 days from X" thread, other researchers stop submitting. Fix: enforce 5-business-day acknowledgement as a hard SLA.
- **Scope confusion.** Researcher submits valid critical on out-of-scope asset, you reject with no bounty, they argue publicly. Fix: pay a goodwill bounty even on out-of-scope criticals, then formally expand scope.
- **Payment disputes.** "Why is this a medium and not a critical?" Most disputes are about severity / dollar amount. Fix: publish severity rubric with examples. See [[cvss-scoring-practitioner]] and [[demonstrating-impact]].
- **Dupe handling badly.** Closing a report as duplicate of an internal finding the researcher cannot see feels like bad faith. Fix: share the internal ticket date or at least a screenshot redacted. See [[dupe-mental-model]].
- **Disclosure surprise.** Researcher publishes a write-up before remediation. Fix: agree disclosure timeline at validation time, document it in the ticket.
- **Researcher account compromise.** A high-rep researcher's platform account gets phished, attacker submits a fake critical and walks with a five-figure bounty. Verify payment changes via out-of-band channels.

## Program maturity tiers

| Tier | Description | Annual budget (USD, ballpark) |
|---|---|---|
| 0 | No program. `security@` goes to a shared inbox no-one reads. | $0 |
| 1 | VDP, security.txt, safe-harbour policy published. Volunteer triage. | $0 to $20k |
| 2 | VDP on a platform, formal SLAs, half-FTE triage. | $30k to $80k |
| 3 | Private BBP, invited researchers, full-FTE triage, modest bounty pool. | $100k to $300k |
| 4 | Public BBP, dedicated triage team, six-figure top bounties, live hacking events. | $500k to $2M |
| 5 | Multi-program (web, mobile, hardware, on-prem appliance), VRP-style payouts, public bug-bounty page like Google / Meta / Apple. | $3M+ |

Most companies should aim for Tier 2 or Tier 3. Tier 4 only makes sense for consumer-facing platforms with a meaningful attack surface.

## Workflow to study

1. Read the public policies of three programs at different maturity tiers — for example GitLab, Shopify, and a federal agency VDP (CISA's own program is public).
2. Map each section of their policy back to this note: safe-harbour, scope, exclusions, severity rubric, SLAs, payment terms.
3. Draft a VDP policy for your own org. Run it past legal. Iterate.
4. Stand up `security.txt` per RFC 9116 and a `security@` mailbox. Confirm both reach a human within 24 hours via a test message from an external address.
5. Run a 90-day VDP pilot. Measure volume, valid rate, time-to-acknowledge.
6. Decide whether to graduate to platform-hosted VDP or private BBP. Prepare budget for next FY.

## Vendor marketing vs reality

- Platforms will pitch you on researcher count ("over 1 million researchers!"). The number that matters is active researchers in your stack — typically 50 to 200 even for a large public program.
- "Triage-as-a-service quality" is highly variable. Audit at least 20 of their close decisions per quarter.
- "Continuous pentest" pitched on top of bounty is mostly rebranding. Real continuous coverage requires your own [[appsec-threat-modeling]] discipline and a competent in-house team (see [[appsec-maturity-checklist]] and [[secure-sdlc-rollout-playbook]]).
- Live hacking events (HackerOne H1-events, Bugcrowd live) are useful for surge testing and PR, expensive ($200k+ all-in), and depend heavily on event scope quality.

## Related

- [[hackerone-platform-deep]]
- [[bugcrowd-platform-deep]]
- [[bounty-triage-from-hunters-view]]
- [[pre-disclosure-embargo-and-cve-coordination]]
- [[disclosure-and-comms]]
- [[responsible-disclosure-across-jurisdictions]]
- [[report-writing]]
- [[report-writing-step-by-step]]
- [[dupe-mental-model]]
- [[demonstrating-impact]]
- [[cvss-scoring-practitioner]]
- [[appsec-maturity-checklist]]
- [[secure-sdlc-rollout-playbook]]
- [[nis2-implementation]]

## References

- https://www.rfc-editor.org/rfc/rfc9116.html — `security.txt` specification
- https://disclose.io/ — open-source safe-harbour and VDP policy templates
- https://www.cisa.gov/news-events/directives/binding-operational-directive-20-01 — CISA BOD 20-01 mandating VDPs for US federal civilian agencies
- https://www.hackerone.com/resources/reporting/the-hacker-powered-security-report — annual HackerOne data on program economics
- https://www.bugcrowd.com/resources/reports/inside-the-mind-of-a-hacker/ — Bugcrowd researcher-side benchmarks useful for setting bounty schedules
- https://hackerone.com/resources/hackerone/vulnerability-disclosure-policy-basics — sample VDP policy structure
