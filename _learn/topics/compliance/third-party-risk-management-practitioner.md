---
title: Third-party risk management — practitioner
slug: third-party-risk-management-practitioner
aliases: [tprm, vendor-risk-management]
---

> **TL;DR:** Third-Party Risk Management (TPRM) is the discipline of identifying, assessing, monitoring, and contractually constraining the risk that vendors, SaaS providers, contractors, and their sub-processors introduce to your organization. In 2024-2026, regulators (NIS2, DORA, NYDFS) have pushed TPRM from a procurement checkbox into a security-team accountability. Most major breaches now come *through* a vendor: see [[case-study-3cx-supply-chain]], [[case-study-snowflake-2024]], [[case-study-okta-2023-support-system]], [[case-study-lastpass-2022]]. This is a practitioner note — what you actually do day-to-day. Pairs with [[nis2-implementation]] and [[grc-analyst-career-track]].

## Why it matters

Your attack surface is no longer your own perimeter. The companies that lost data in 2023-2025 mostly did not get popped directly — their *vendor* did. The Snowflake-customer cluster, Okta support-case-file exfil, 3CX supply-chain trojan, MOVEit zero-day, LastPass developer-laptop pivot — every one is a TPRM story.

Regulators noticed. NIS2 Article 21(2)(d) requires "supply chain security." DORA (in force January 2025) makes ICT third-party risk a board-level financial-services obligation. NYDFS 23 NYCRR 500.11 mandates a written third-party service provider security policy. Even outside regulated sectors, customers now ask for your TPRM program before they sign — it shows up in [[soc2-vs-iso27001]] audits as a major control family (CC9.2 in SOC 2, A.5.19-A.5.23 in ISO 27001:2022).

Done well, TPRM stops a vendor compromise from cascading. Done as paperwork only, it gives you false assurance and a binder of stale questionnaires.

## Core concepts and process

### Vendor inventory

You cannot manage what you do not list. Step zero is a *complete* inventory: every SaaS subscription (including shadow IT), every contractor with system access, every API integration, every managed service. Sources to reconcile: AP/procurement records, SSO logs (Okta/Entra app registrations), expense reports, DNS egress, CASB. Expect to find 2-5x more vendors than procurement thinks you have.

Each entry minimally needs: vendor name, business owner, technical owner, data categories handled, integration type (SaaS, on-prem, API, professional services), contract end date, criticality tier.

### Tiering by criticality

Not every vendor gets the same scrutiny. Typical tiering:

- **Tier 1 / Critical** — handles regulated data (PCI, PHI, PII at scale), has production access, or business cannot operate without them for 24 hours. Examples: payroll, primary cloud provider, identity provider, payment processor. Full due diligence, annual reassessment, contractual right-to-audit, continuous monitoring.
- **Tier 2 / Important** — handles internal or limited customer data, partial business impact if down. Examples: HR SaaS, marketing automation, code-signing service. Standard questionnaire, biennial reassessment.
- **Tier 3 / Low** — public data only, easily replaceable, no system integration. Examples: stock-photo subscription, conference-booking tool. Light-touch — security baseline attestation only.

Tiering should drive *effort*. Spending three months on a stock-photo vendor while rubber-stamping your identity provider is a common antipattern.

### Due diligence questionnaires

Standard frameworks:

- **SIG (Shared Assessments)** — Standardized Information Gathering. SIG Lite ~150 questions, SIG Core ~850+. Industry default in financial services and large enterprises.
- **CAIQ (Cloud Security Alliance)** — Consensus Assessments Initiative Questionnaire. ~260 questions aligned to CCM. Default for cloud/SaaS providers.
- **Custom** — your own short-form, usually 30-80 questions targeted at your top concerns.

Pragmatic approach: accept the vendor's *existing* CAIQ or SIG submission if recent (less than 12 months), only send a custom questionnaire when you have specific gaps. Sending a 850-question SIG to a 10-person SaaS startup wastes everyone's time and gets perfunctory answers.

### Evidence types

Questionnaires are self-attestation — they are necessary but not sufficient. Ask for evidence:

- **SOC 2 Type II report** — independent auditor opinion over a 6-12 month observation window. Type I (point-in-time) is much weaker. Read the *exceptions* section, not just the cover page. CUEC (Complementary User Entity Controls) tells you what *you* still have to do.
- **ISO 27001 certificate** — check the scope statement carefully. A certificate that scopes only the HR office is worthless if you are buying their cloud product. Cross-reference at the certification body's public registry.
- **Pen-test summary / attestation letter** — annual external pen test by a reputable firm. Full report is rare (NDA-bound), but a summary should at least list scope, methodology, and high-level finding counts. See [[pentest-report-writing-deep]] for what a real report looks like.
- **BCP / DR plan and test results** — recovery time objective (RTO), recovery point objective (RPO), and *evidence of a recent test*.
- **Insurance certificates** — cyber liability and E&O minimums, with you named as additional insured for Tier 1.
- **Sub-processor list** — see 4th-party section below.

### Continuous monitoring tools

Point-in-time assessment goes stale fast. Continuous-monitoring platforms scrape external signals — exposed services, leaked credentials, TLS misconfig, patching cadence, dark-web mentions:

- **SecurityScorecard** — letter grades A-F across 10 factor groups.
- **BitSight** — numeric ratings 250-900, popular in financial services.
- **RiskRecon** (Mastercard) — issue-level findings with asset context.
- **Panorays**, **UpGuard**, **Black Kit** — adjacent players.

Reality check: these tools are useful as *change detection* (sudden grade drop = investigate) and a forcing function in vendor conversations. They are not ground truth. A vendor with an A rating can still get popped via a phishing-induced [[aitm-evilginx-modern-phishing]] flow that no external scanner can see.

### Contract clauses

Security gets baked in at contract negotiation — *before* signature, when you have leverage. Non-negotiables for Tier 1:

- **Right-to-audit** — you (or your nominated auditor) may audit security controls with reasonable notice. Often softened to "right to receive SOC 2 reports and respond to a reasonable security questionnaire annually" — that is acceptable.
- **Breach notification** — vendor must notify within 24-72 hours of confirmed incident affecting your data. Specify *what* triggers notification (confirmed unauthorized access, not just suspected). GDPR Article 33 has 72-hour clock running from *your* awareness, so vendor delay eats your budget; see [[gdpr-incident-implications]].
- **Sub-processor disclosure and approval** — list of current sub-processors and notice before adding new ones, with right-to-object.
- **Data return / destruction** at contract end with attestation.
- **Minimum security standards** — encryption in transit and at rest, MFA on admin access, logging retention, vulnerability management SLAs.
- **Insurance minimums** and indemnification scope for security incidents.
- **Liability cap carve-outs** — security incidents often have a higher cap or are uncapped. This is the single most negotiated clause.
- **Cooperation in IR** — vendor will reasonably cooperate with forensic investigation, preserve logs, and provide artifacts.

### 4th-party visibility

Your vendor's vendors are *your* fourth parties. Snowflake was a fourth party to many companies whose customer data leaked in 2024. Okta's downstream support-system breach hit *their* customers' customers.

Practical steps:

- Ask Tier 1 vendors for their sub-processor list and update SLA.
- For SaaS, check the public sub-processor / trust page (most major vendors publish this).
- Map *your* critical fourth parties — usually the same handful keep appearing (AWS, Azure, GCP, Cloudflare, Datadog, Twilio, Stripe).
- Concentration risk: if 40% of your Tier 1 vendors all sit on one cloud region, a single AWS us-east-1 incident is a business-continuity event regardless of any one vendor's controls.

### Regulatory drivers

- **NIS2** (EU, transposition deadline October 2024, slipping through 2025) — Article 21(2)(d) requires supply-chain security as part of cybersecurity risk-management measures. Essential entities must assess supplier vulnerabilities and overall product security. See [[nis2-implementation]].
- **DORA** (EU financial services, enforced January 17 2025) — Chapter V is entirely on ICT third-party risk. Mandatory contractual provisions in Article 30, register of information about contractual arrangements, oversight framework for "critical ICT third-party service providers" (the big cloud providers).
- **NYDFS 23 NYCRR 500.11** — covered entities must have a written third-party service provider security policy: due diligence, minimum cybersecurity practices, periodic assessment, contractual provisions. Updated November 2023 with more teeth.
- **PCI DSS 4.0** — Requirement 12.8 and 12.9 on third-party service providers; see [[pci-dss-4-implementation]].
- **HIPAA** — Business Associate Agreements (BAAs) are TPRM by another name; see [[hipaa-security-rule]].

### Interaction with procurement

TPRM that fights procurement loses. The pattern that works:

1. TPRM owns the *risk decision*, procurement owns the *commercial process*.
2. Security review is a gate in the procurement workflow (Coupa, Ariba, ServiceNow VRM) — not an email thread.
3. SLAs on security review: Tier 3 in 3 business days, Tier 2 in 10, Tier 1 in 20. Miss the SLA and the business goes around you.
4. A "fast-track" path for low-risk SaaS under a spend threshold (often $10-25k) — name the vendor, attest no regulated data, accept the standard terms, go.
5. Renewals are reassessment triggers, not auto-approvals.

### Vendor breach IR coordination

When a vendor announces a breach:

1. Confirm whether *your* data or systems are in scope — do not rely solely on the vendor's first statement, which is often optimistic.
2. Pull your integration footprint: API keys issued, accounts provisioned, data shared, network paths.
3. Rotate all credentials and tokens issued to that vendor, even if vendor says no rotation needed.
4. Review your own logs for the indicators-of-compromise window the vendor provides (and the period *before*, since vendors usually underestimate dwell time — see [[case-study-solarwinds-2020]]).
5. Engage legal early on regulatory notification clocks.
6. Document everything for the post-incident review and possible regulator inquiry.

## Defensive baseline — what a working TPRM program looks like

- Inventory reconciled quarterly against AP, SSO, and CASB.
- Tiering reviewed annually and at material change.
- Standard questionnaire mapped to a single internal control framework (NIST CSF or ISO 27001 Annex A).
- Evidence repository with expiry tracking — SOC 2 reports go stale after 12-15 months.
- Continuous monitoring on all Tier 1, sampled Tier 2.
- Pre-approved security addendum that any vendor can sign without negotiation.
- IR runbook for vendor breach scenario, tested annually.
- Metrics reported to risk committee: open Tier 1 findings, overdue reassessments, vendors with expired evidence, breach-notification SLA compliance.

## Common gaps

- **Inventory drift** — shadow IT SaaS bought on a corporate card never enters the program.
- **Questionnaire fatigue** — vendors copy-paste answers; reviewers rubber-stamp.
- **Evidence not validated** — accepting an ISO 27001 certificate without reading the scope statement.
- **No 4th-party view** — surprised when your vendor's sub-processor breach becomes your incident.
- **Contract clauses won but never invoked** — right-to-audit never used, breach-notification SLA never measured.
- **TPRM siloed from IR** — vendor breach hits and nobody knows who owns the response.
- **Reassessment cadence ignored** — initial review thorough, year two is a checkbox, year three never happens.

## Workflow to study

1. Read NIST SP 800-161r1 (Cybersecurity Supply Chain Risk Management Practices) — long but the canonical reference.
2. Get familiar with one questionnaire framework end-to-end (SIG Lite is easiest entry).
3. Read a real SOC 2 Type II report — many vendors publish redacted versions; learn to spot exceptions and CUECs.
4. Walk through DORA Articles 28-30 even if you are not in EU finance — it is where regulation is heading.
5. Study [[case-study-3cx-supply-chain]] and [[case-study-snowflake-2024]] as TPRM case studies, not just technical incidents.
6. Build a vendor inventory for your own org from procurement + SSO + DNS — the gap will surprise you.
7. Sit in on a vendor security review meeting if you can — the negotiation dynamics matter as much as the technical content.

## Career reality

TPRM roles sit between GRC, security, and procurement. Titles vary: Third-Party Risk Analyst, Vendor Risk Manager, Supplier Security Lead, ICT Third-Party Risk Officer (DORA-driven).

Typical compensation in 2025-2026 (USD, US market, base salary):

- Analyst (0-3 years): $70-95k
- Senior analyst / manager (3-7 years): $100-140k
- Lead / program manager (7-12 years): $140-180k
- Director / Head of TPRM (regulated industry, financial services): $180-260k+

Lower in non-regulated industries; meaningfully higher in tier-one banks and insurers, especially with DORA-relevant experience.

Day-to-day reality: lots of questionnaire review, vendor calls, contract redlining, chasing evidence, getting overridden by the business when they really want a tool. Less hands-on technical work than detection or pentest paths.

Who succeeds: people who can hold a security position while staying commercially pragmatic, write clearly, read contracts without flinching, and build relationships across procurement, legal, and engineering. Who struggles: people who treat every vendor as an adversary, or who treat the questionnaire as the goal rather than the means.

Common transitions in: GRC analyst, internal audit, procurement-with-security-interest, junior SOC analyst tired of shift work. Common transitions out: broader GRC leadership, CISO-track roles, compliance officer roles, consultancy (Big 4 advisory pays well for DORA/NIS2 experience). See [[grc-analyst-career-track]].

## Related

- [[case-study-3cx-supply-chain]]
- [[case-study-snowflake-2024]]
- [[case-study-okta-2023-support-system]]
- [[case-study-lastpass-2022]]
- [[case-study-solarwinds-2020]]
- [[case-study-moveit-2023]]
- [[nis2-implementation]]
- [[grc-analyst-career-track]]
- [[soc2-vs-iso27001]]
- [[pci-dss-4-implementation]]
- [[hipaa-security-rule]]
- [[gdpr-incident-implications]]

## References

- NIST SP 800-161 Rev. 1 — Cybersecurity Supply Chain Risk Management Practices: https://csrc.nist.gov/pubs/sp/800/161/r1/final
- Shared Assessments — SIG questionnaire: https://sharedassessments.org/sig/
- Cloud Security Alliance — CAIQ: https://cloudsecurityalliance.org/research/cloud-controls-matrix/
- EU DORA Regulation 2022/2554 (consolidated text): https://eur-lex.europa.eu/eli/reg/2022/2554/oj
- NYDFS 23 NYCRR 500 — Cybersecurity Requirements: https://www.dfs.ny.gov/industry_guidance/cybersecurity
- ENISA — Good Practices for Supply Chain Cybersecurity: https://www.enisa.europa.eu/publications/good-practices-for-supply-chain-cybersecurity

See also: [[csa-star-cloud-security]], [[hitrust-csf-implementation]], [[cmmc-2-dod-contractor]], [[fedramp-authorization-process]], [[iso-27701-privacy-extension]]
