---
title: APPI — Japan Act on the Protection of Personal Information
slug: appi-japan
aliases: [japan-appi, jp-privacy]
---

> **TL;DR:** Japan's Act on the Protection of Personal Information (APPI) is the country's omnibus privacy law, enforced by the Personal Information Protection Commission (PPC). The 2020 and 2022 amendments brought it closer to GDPR territory — extraterritorial scope, mandatory breach notification, stronger cross-border transfer rules, pseudonymisation, and meaningfully higher fines. If you run security for any business touching Japanese residents' data, treat APPI like a peer of [[gdpr-incident-implications]], [[pdpa-singapore]], [[lgpd-brazil]], and [[dpdp-india]] — same shape, different procedural muscle memory.

## Why it matters

APPI is no longer the gentle, advisory regime it was a decade ago. The 2020 amendments (in force June 2022) and 2022 follow-on changes pushed Japan into a recognisably modern privacy posture. Practically:

- **Extraterritorial reach.** Foreign businesses processing personal information of people in Japan as part of supplying goods/services are in scope, even with no Japan establishment.
- **Mandatory breach reporting.** A subset of incidents must be reported to the PPC and notified to data subjects.
- **Cross-border friction.** Transfers outside Japan require recognised adequacy (a PPC whitelist), contractual safeguards, or explicit consent with disclosure.
- **Pseudonymisation tier.** A specific legal category ("pseudonymously processed information") with relaxed handling rules but real obligations.
- **Real fines.** Corporate maximums climbed materially with the 2022 amendments — no longer purely reputational.

If you've built your IR runbooks around [[gdpr-incident-implications]], you mostly need to bolt on PPC-specific timing and language rather than re-architect — but the deltas matter. See also [[responsible-disclosure-across-jurisdictions]] for how multi-jurisdictional incidents interact.

## Regulator and structure

### The PPC

The Personal Information Protection Commission (PPC, 個人情報保護委員会) is the independent supervisory authority. It:

- Investigates incidents and complaints
- Issues guidelines (binding in practice; courts defer heavily)
- Maintains the cross-border adequacy whitelist
- Coordinates with sector regulators

### Sector overlays

APPI is the floor; some sectors layer obligations on top:

- **FISC (Financial Industry Information Systems Center)** publishes the *FISC Security Guidelines* widely treated as de facto mandatory for banks/insurers/payments — overlaps with [[pci-dss-4-implementation]] for card data.
- **FSA (Financial Services Agency)** enforces sector-specific cyber/privacy supervision.
- **METI (Ministry of Economy, Trade and Industry)** and **MIC (Ministry of Internal Affairs and Communications)** publish sector guidance — historically influential for telecoms and e-commerce.
- **Medical/My Number** has its own statute (My Number Act) for the national ID — treat as a separate regime, not just APPI.

## Key obligations (operator view)

### Defined data classes

APPI distinguishes:

- **Personal information** — identifies a living individual.
- **Personal data** — personal information held in a structured database.
- **Retained personal data** — personal data the business can disclose/correct/delete (most operational obligations attach here).
- **Special care-required personal information (要配慮個人情報)** — race, creed, social status, medical history, criminal record, victimisation — opt-in consent required to collect.
- **Pseudonymously processed information (仮名加工情報)** — restructured so re-identification needs additional info; relaxed internal-use rules but no third-party transfer except to processors.
- **Anonymously processed information (匿名加工情報)** — irreversibly de-identified per PPC standards; freer to share.

### Core duties

- **Purpose specification** — state the purpose of use, don't drift beyond it without consent.
- **Acquisition fairness** — no deception; special-care data needs explicit consent.
- **Accuracy and retention minimisation** — keep data accurate, delete when purpose ends.
- **Security control measures** — organisational, human, physical, technical safeguards. PPC guidelines map cleanly to [[appsec-maturity-checklist]] and [[secure-sdlc-rollout-playbook]] practices.
- **Supervision of employees and processors** — including offshore.
- **Subject rights** — disclosure, correction, suspension of use, deletion, data portability (electronic-format disclosure since 2022).
- **Record-keeping for third-party transfers** — who got what, when, and why.

### Breach notification

Triggered when a leak/loss/damage involves any of:

1. Special care-required data
2. Data that could cause financial loss if misused (e.g. credit card numbers)
3. Likely unauthorised purpose (deliberate exfiltration)
4. More than 1,000 affected individuals

Process:

- **Prompt report** to PPC within roughly 3–5 days (報告) with what's known.
- **Final report** within ~30 days (60 days for category 3 — unauthorised purpose).
- **Notification to affected individuals** "without delay" — substitutable with public notice if individual contact is impractical.

Build the PPC timing into your IR playbook alongside the GDPR 72-hour clock. See [[ir-from-source-signals]] for upstream detection plumbing and [[cloud-ir-aws-cloudtrail]] / [[cloud-ir-azure-activity-log]] / [[cloud-ir-gcp-audit-logs]] for evidence collection.

## Cross-border transfers

Three lawful bases:

1. **Whitelisted jurisdiction.** PPC has recognised the EEA and the UK as providing equivalent protection — transfers there are unrestricted (with caveats). No US adequacy.
2. **Equivalent-safeguards contract.** Binding internal rules or contractual clauses obliging the recipient to meet APPI-equivalent standards, plus ongoing supervision and a yearly review.
3. **Informed consent.** Explicit consent that discloses the destination country, that country's privacy regime, and the recipient's measures — onerous in practice.

The 2020 amendments specifically tightened (2) and (3): you must disclose information about the destination regime, not just get a generic checkbox. For US-based SaaS this typically means processor-style contractual safeguards plus annual due diligence.

## Pseudonymisation in practice

The pseudonymisation regime ("仮名加工情報") is a pragmatic middle path:

- Internal analytics on pseudonymised data don't trigger purpose-change consent obligations.
- You **cannot transfer to third parties** except entrusted processors.
- The mapping/re-identification key must be segregated with access controls.
- Breach notification thresholds still apply if re-identification is feasible.

Useful for ML feature stores, A/B testing platforms, and product analytics — but don't confuse it with the irreversible anonymisation tier.

## Penalty regime

Post-2022 amendments:

- **Corporate fines** up to JPY 100 million (~USD 650k) for serious violations — PPC order non-compliance, illicit provision of personal information databases.
- **Individual fines and imprisonment** for officers/employees who exfiltrate.
- **PPC administrative orders** — public, reputationally heavy.
- **Civil liability** under tort law for affected individuals (class-action style litigation is rare but growing).

For context: still below GDPR's 4% global turnover ceiling, but the orders are public and the reputational damage in Japan is severe — large companies treat PPC orders as board-level events.

## Defensive baseline for security teams

If you're the security person on the hook, focus on these:

### Data inventory and classification

- Tag datasets containing Japanese-resident personal information.
- Separately tag special-care-required fields (medical, criminal history, etc).
- Track pseudonymised vs anonymised tier and where the re-id keys live.

### Access governance

- Role-based access with audit trails matching PPC's "technical safeguards" guidance.
- Quarterly access reviews for retained personal data systems.
- Mandatory MFA for anything touching special-care data — see [[aitm-evilginx-modern-phishing]] and [[conditional-access-bypass-modern]] for what your MFA actually needs to survive.

### Vendor/processor management

- Contract clauses obliging APPI-equivalent handling.
- DPA-style addenda for offshore processors (most SaaS).
- Annual security review (questionnaire + evidence) — pairs with [[soc2-vs-iso27001]] artefacts the vendor likely already has.

### IR readiness

- PPC-specific runbook entry: prompt report template, final report template, affected-individual notice template (Japanese-language).
- Pre-identified Japanese counsel.
- Forensics retention policy that survives the 60-day clock for category 3 incidents.
- Tabletop including a "1,001 affected individuals" scenario — the threshold is real and surprisingly easy to cross.

### Cross-border architecture

- Document data flows out of Japan with destination country and legal basis.
- Where possible, region-pin processing in Japan or whitelisted EEA/UK.
- For US destinations, lean on processor contracts plus published security posture.

## Comparison to GDPR

| Dimension | GDPR | APPI |
|---|---|---|
| Scope test | Establishment / targeting / monitoring | Establishment / supply of goods or services to people in Japan |
| Lawful bases | Six explicit (consent, contract, legitimate interest, etc.) | Purpose specification + consent for special-care + opt-out for ordinary third-party transfer |
| Breach clock | 72 hours to DPA | ~3–5 days prompt + 30/60 days final |
| Fines ceiling | EUR 20M or 4% turnover | JPY 100M per offence (no turnover multiplier) |
| Adequacy | Commission decisions | PPC whitelist (EEA + UK) |
| Special category | Art. 9 list | Special care-required list (similar but narrower) |
| DPO | Mandatory in many cases | Not mandatory; "person responsible" recommended |
| Pseudonymisation | Defined, optional tool | Defined legal category with own rules |

Practical takeaway: a GDPR-ready programme is ~70% of the way to APPI compliance — bolt on PPC reporting templates, Japanese-language subject communications, and the pseudonymised-data tier handling.

## Workflow to study

1. Read PPC's English summary of APPI and the 2020/2022 amendment overviews end-to-end.
2. Walk a real product data flow through the APPI definitions — what's "personal data" vs "retained personal data" vs "pseudonymously processed"?
3. Map your existing GDPR breach runbook to PPC timing — note where you'd diverge.
4. Identify cross-border transfers in your architecture and document the lawful basis for each.
5. If finance/payments — pull the FISC Security Guidelines table of contents and compare to [[pci-dss-4-implementation]].
6. Tabletop a breach scenario crossing the 1,000-individual threshold; practice drafting the PPC prompt report in plain Japanese (or with translation).
7. Review METI's data governance guidance for sector specifics if you're in e-commerce or IoT.
8. Subscribe to PPC enforcement notices — short, public, instructive.

## Related

- [[gdpr-incident-implications]]
- [[pdpa-singapore]]
- [[lgpd-brazil]]
- [[dpdp-india]]
- [[hipaa-security-rule]]
- [[pci-dss-4-implementation]]
- [[nis2-implementation]]
- [[soc2-vs-iso27001]]
- [[responsible-disclosure-across-jurisdictions]]
- [[appsec-maturity-checklist]]
- [[secure-sdlc-rollout-playbook]]
- [[ir-from-source-signals]]

## References

- PPC — Act on the Protection of Personal Information (English): https://www.ppc.go.jp/en/legal/
- PPC — Guidelines and amendments overview: https://www.ppc.go.jp/en/aboutus/roles/international/
- JIPDEC PrivacyMark and APPI guidance: https://privacymark.org/
- FISC — Security Guidelines on Financial Information Systems: https://www.fisc.or.jp/english/
- METI — Data governance and privacy guidance: https://www.meti.go.jp/english/policy/
- IAPP — Japan data protection overview: https://iapp.org/resources/article/japan-data-protection-overview/
