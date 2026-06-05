---
title: CISO and vCISO — career and engagement track
slug: ciso-vciso-track
aliases: [ciso-track, vciso-track, fractional-ciso]
---

> **TL;DR:** The CISO role is mostly strategy, board reporting, budget, vendor management, and incident leadership — not hands-on technical work. The vCISO (virtual / fractional) variant sells that same function part-time across multiple clients, and is now a viable lane for senior practitioners who do not want a single-employer C-suite seat. Career trajectory, compensation, and personal legal liability all changed sharply after the SEC SolarWinds case and the Uber CISO conviction. Companion to [[security-auditor-career-track]], [[soc2-vs-iso27001]], [[nis2-implementation]], and [[case-study-solarwinds-2020]].

## Why it matters

If you are an engineer or pentester planning a 10–20 year arc, "become a CISO" is one of the few non-IC ceilings that still pays well and still exists. But the job has drifted further from technical work and closer to a hybrid of risk officer, lawyer-adjacent, and chief-of-staff for security. Understanding what a CISO actually does — versus what LinkedIn says — is the difference between aiming at a role you will enjoy and aiming at one that will burn you out in 24 months.

The vCISO model is the other reason this matters now. Mid-market companies (50–500 employees) increasingly cannot hire a full-time CISO but are forced to name one for [[soc2-vs-iso27001]] audits, cyber insurance, [[nis2-implementation]], or US state privacy laws. That demand created a real consulting market for fractional CISOs charging hourly or monthly retainers.

## What a CISO actually does

The day-to-day breakdown for a typical mid-to-large company CISO:

- **Strategy and roadmap (20–25%)** — multi-year security plan, capability gaps, build vs buy decisions, alignment with business strategy.
- **Board and exec reporting (15–20%)** — quarterly board decks, risk metrics, regulatory updates, breach notifications. Translating technical risk into financial and reputational terms.
- **Budget and vendor (15–20%)** — annual budget defense, tool consolidation, contract negotiation, vendor risk reviews, MSSP / consultant relationships.
- **People and org (15%)** — hiring, retention, performance, org design, succession planning.
- **Risk and compliance oversight (10–15%)** — owning the risk register, signing off on exceptions, working with internal audit, regulator interactions.
- **Incident leadership (5–10% normally, 100% during a breach)** — not running the keyboard; running the room. Working with legal counsel, PR, regulators, and the board during [[ir-from-source-signals]] events.
- **Hands-on technical (0–5%)** — reading the occasional report, sanity-checking an architecture decision. Most CISOs have not written production code in years.

If you love deep technical work, this ratio is the warning. The career track that ends at CISO does not end at "senior engineer with a fancy title" — it ends at executive management of a risk function.

### Reporting lines and what they mean

Who the CISO reports to shapes the job more than the company size does.

- **CIO** — traditional model. Security is treated as part of IT. Easier to get things done in IT systems, harder to push back when IT priorities conflict with security. Still common in mature enterprises.
- **CTO** — common in tech-first companies. Good for product security and [[secure-sdlc-rollout-playbook]] traction. Risk: security gets framed as engineering tax.
- **CFO** — risk-management framing. Often appears in financial services. Easier to get budget for compliance and insurance topics, harder for offensive / detection investment.
- **General Counsel** — increasingly common post-[[gdpr-incident-implications]] and post-SEC rules. Strong on regulatory and breach response, weak on technical architecture authority.
- **CEO direct** — the prestige reporting line. Comes with real authority and real exposure. Increasingly demanded by candidates negotiating after high-profile breaches.
- **COO or Chief Risk Officer** — risk-org framing. Common in banks, insurance, healthcare.

In practice, "CISO" without CEO or board access is often a director-level job with an inflated title.

## Startup CISO vs Fortune 500 CISO — different jobs

These are not the same role.

### Startup / scale-up CISO (50–500 employees)

- Hands-on enough to read PRs, deploy tooling, run tabletop exercises personally.
- One to three direct reports, often including the only AppSec or GRC engineer.
- Budget in the low hundreds of thousands to low millions.
- Primary pressures: [[soc2-vs-iso27001]] audit, sales-led security questionnaires, customer trust calls, the first real incident.
- Compensation: USD 180k–300k base + equity that may or may not matter.
- Job satisfaction: high if shipping matters to you and the CEO trusts you.

### Mid-market CISO (500–5,000 employees)

- Mostly managerial. Five to twenty reports.
- Real budget (USD 2–10M typical), real tool sprawl, real legacy.
- Primary pressures: regulatory map (multiple regimes), M&A diligence, cyber insurance renewal, [[pentest-debrief-and-followup]] from annual engagements.
- Compensation: USD 250k–450k base + bonus + equity refreshers.

### Fortune 500 / global CISO

- Pure executive. May not have written a query in five years.
- Org of 100–1,000+, multiple deputies (deputy CISO for product, for infra, for GRC, for IR).
- Budget USD 50M–500M+. Politics with peer execs is the real job.
- Primary pressures: regulators across many jurisdictions, nation-state adversaries (see [[apt-tradecraft-russian-svr-fsb]], [[apt-tradecraft-chinese-mss]]), supply-chain ([[case-study-3cx-supply-chain]]), board scrutiny, personal liability exposure.
- Compensation: USD 500k–1.5M+ base, total comp commonly USD 2–6M with equity. Top names at the largest banks and tech firms exceed USD 10M.

These markets do not feed into each other smoothly. A great startup CISO does not always survive an F500 environment; an F500 deputy CISO often struggles with the chaos of a 100-person company.

## The vCISO model

vCISO is the consulting equivalent: one practitioner, multiple client companies, fractional commitment.

### Typical engagement shapes

- **Retainer** — fixed monthly fee for a fixed number of hours (often 20–60 hours/month). Includes monthly leadership meeting, quarterly board presentation, vendor reviews, audit support.
- **Project-based** — auditor prep, post-breach interim CISO, M&A integration.
- **Hourly overflow** — USD 250–600/hour for ad-hoc work on top of a retainer.
- **Embedded / interim** — three to twelve months as the named CISO during search.

### Who buys vCISO services

- 30–300 person companies, especially SaaS, that need someone named on the SOC 2 letter and the cyber insurance form.
- Companies between CISOs — interim coverage during a search.
- Regulated mid-market firms ([[hipaa-security-rule]], [[pci-dss-4-implementation]], [[nis2-implementation]]) without budget for a full security org.
- Portfolio companies of PE / VC firms where the fund mandates security oversight.

### Economics

A solo vCISO with 4–6 retainer clients at USD 6–15k/month each plus project work can clear USD 400k–700k revenue. Boutique firms package three to five vCISOs under shared GRC and pentest delivery and scale to 30+ clients per partner.

The honest downside: client churn, sales effort, no equity upside, and you carry the personal liability of being named CISO across multiple companies (see below).

## How engineers transition in

There is no single path. Common ones:

- **Deputy CISO → CISO** — the cleanest. Two to four years as deputy at a recognizable company, then promoted internally or recruited externally.
- **Head of AppSec or Head of SecOps → CISO** — works when paired with explicit board-communication coaching. Many strong technical leaders fail the first board meeting and never recover.
- **VP Engineering → CISO** — after a breach, or when the company realizes security needs an engineering-fluent owner. Works in tech-first companies.
- **External hire from consulting (Big 4, boutique)** — common but often resented by the in-house team if the new CISO has no production experience.
- **Auditor / GRC → CISO** — works in regulated industries where compliance is the dominant pressure. See [[security-auditor-career-track]].
- **Government / military → CISO** — common in defense, finance, critical infrastructure. Strong on process and clearances, sometimes weak on modern cloud-native engineering.

Realistic timeline: 12–20 years of cumulative security and adjacent experience before a first real CISO seat at a non-trivial company. Startups will hire a CISO with less, but the job there is different (see above).

## Personal liability and the post-SolarWinds reality

This is the part the recruiter brochure leaves out.

- **SEC v. SolarWinds / Tim Brown (2023)** — the SEC charged the CISO personally with fraud over alleged misstatements about security posture. Most of the charges were later dismissed, but the message was sent. CISOs now negotiate D&O insurance, indemnification, and SEC-disclosure protocols before signing. See [[case-study-solarwinds-2020]].
- **US v. Joe Sullivan / Uber (2022)** — the former Uber CISO was convicted of obstruction and misprision of a felony over the 2016 breach payout and concealment. First criminal conviction of a CISO in this context.
- **SEC cyber disclosure rule (2023)** — public companies must disclose material cyber incidents within four business days. CISOs are now in the materiality determination conversation, often with personal exposure if the call is wrong.
- **NIS2 personal accountability** — in the EU, [[nis2-implementation]] introduces personal liability for management of essential entities. The CISO may not be the named legally-liable person, but is functionally in the firing line.

Practical implications when negotiating a CISO offer:

- Written indemnification from the company, surviving termination.
- Separate D&O coverage extending to the CISO (not just board members).
- Explicit authority to disclose material incidents (in writing, in the role description).
- Direct board access — not filtered through a peer exec.
- Clear escalation rights if asked to misrepresent security posture.

Engineers used to thinking "the company will defend me" should read the Sullivan trial transcript before accepting a CISO seat.

## Burnout and tenure

Industry surveys consistently put median CISO tenure at 18–26 months. Realistic causes:

- On-call posture, 24x7 escalation, especially during ransomware season ([[ransomware-affiliate-playbook]]).
- Politics with peer execs who view security as friction.
- Board pressure during incidents combined with media exposure.
- Limited authority to actually fix the root causes flagged by every [[appsec-maturity-checklist]] review.
- Personal liability stress post-2023.

Who succeeds long-term:

- People who genuinely enjoy executive communication and operate calmly in crisis.
- People with strong deputies and willingness to delegate hands-on work.
- People who treat the role as a 3–5 year tour, not a forever job, and rotate companies deliberately.

Who struggles:

- Deep technical specialists who took the title for the comp.
- People who cannot say "no" to the board or "yes" to legal at the right moments.
- People without a peer network of other CISOs to compare notes with.

## Defensive baseline — if you are the CISO today

A short, practical list of things a working CISO should be able to point to within their first 90 days:

- A documented risk register reviewed quarterly with named owners.
- An incident response plan exercised at least annually with the exec team and outside counsel ([[ir-from-source-signals]]).
- Board-level reporting cadence with a stable metric set (not 50 different dashboards).
- A current asset and identity inventory (the silent killer behind most breaches).
- Detection coverage mapped to ATT&CK at least at the tactic level ([[detection-engineering-pyramid-of-pain]], [[siem-detection-use-case-catalog]]).
- A vendor risk process that reflects real third-party exposure ([[case-study-snowflake-2024]], [[case-study-okta-2023-support-system]]).
- Written exception process — exceptions are signed, dated, and expire.
- D&O coverage and indemnification confirmed in writing.

## Workflow to study this track

A six-month self-study path for an engineer considering this direction:

1. **Months 1–2 — financial fluency.** Read a corporate finance primer. Learn to read a 10-K and a board deck. Understand opex vs capex, accruals, headcount accounting.
2. **Months 2–3 — risk frameworks.** ISO 31000, NIST CSF 2.0, FAIR. Map them onto a company you know.
3. **Months 3–4 — regulatory landscape.** [[soc2-vs-iso27001]], [[hipaa-security-rule]], [[pci-dss-4-implementation]], [[gdpr-incident-implications]], [[nis2-implementation]], state privacy laws. Build a one-page regulatory map for a hypothetical client.
4. **Months 4–5 — incident leadership.** Read the post-mortems for [[case-study-solarwinds-2020]], [[case-study-equifax-2017]], [[case-study-moveit-2023]], [[case-study-lastpass-2022]], [[case-study-capital-one-2019]]. Note who made which decisions and what worked.
5. **Months 5–6 — executive communication.** Practice writing board memos. Find a mentor who is a sitting CISO and review their last redacted board deck.
6. **Ongoing.** Join a CISO peer group (regional ISSA, local CISO roundtable, vendor-hosted CISO dinners). The network is most of the job market.

## Related

- [[security-auditor-career-track]]
- [[soc2-vs-iso27001]]
- [[nis2-implementation]]
- [[hipaa-security-rule]]
- [[pci-dss-4-implementation]]
- [[gdpr-incident-implications]]
- [[case-study-solarwinds-2020]]
- [[case-study-equifax-2017]]
- [[case-study-okta-2023-support-system]]
- [[case-study-snowflake-2024]]
- [[appsec-maturity-checklist]]
- [[secure-sdlc-rollout-playbook]]
- [[ir-from-source-signals]]
- [[pentest-debrief-and-followup]]
- [[bug-bounty-as-career-track]]

## References

- SEC, "SEC Charges SolarWinds and Chief Information Security Officer with Fraud, Internal Control Failures" (2023): https://www.sec.gov/newsroom/press-releases/2023-227
- US Department of Justice, "Former Chief Security Officer Of Uber Convicted Of Federal Charges" (2022): https://www.justice.gov/usao-ndca/pr/former-chief-security-officer-uber-convicted-federal-charges-covering-data-breach
- SEC, "Cybersecurity Risk Management, Strategy, Governance, and Incident Disclosure" final rule (2023): https://www.sec.gov/rules/final/2023/33-11216.pdf
- NIST, "Cybersecurity Framework 2.0": https://www.nist.gov/cyberframework
- ENISA, "NIS2 Directive overview": https://www.enisa.europa.eu/topics/cybersecurity-policy/nis-directive-new
- IANS Research and Artico Search, "CISO Compensation and Budget Benchmark" reports: https://www.iansresearch.com/resources/ciso-compensation-benchmark
