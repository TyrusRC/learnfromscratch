---
title: Internal audit vs external audit
slug: internal-audit-vs-external-audit
aliases: [ia-vs-ea, audit-function-types]
---

> **TL;DR:** Internal audit (IA) is an in-house assurance function reporting functionally to the audit committee but employed by the company; external audit (EA) is an independent firm engaged to attest against a defined standard (financial statements, SOC 2, ISO 27001). They overlap in technique but differ sharply in independence, scope, cadence, and career arc. If you are deciding where to spend the next five years, read this alongside [[security-auditor-career-track]], [[soc2-auditor-track]], and [[ciso-vciso-track]].

## Why it matters

Most security practitioners encounter both flavors of audit without realizing they are structurally different jobs. A control owner gets a request from "audit" — is it the internal team that will help you fix the gap, or the external firm that will write the finding into a report your board reads? Mistaking one for the other costs goodwill and sometimes the engagement.

Choosing where to work matters too. Internal audit at a Fortune 500 is a stable, well-paid path with predictable hours. External audit at a Big Four firm is a pressure cooker that opens doors but burns people out in two to four years. Both feed into [[soc2-vs-iso27001]] work, into governance roles, and eventually into CISO seats — but the day-to-day is not the same.

## Independence model

### Internal audit

- **Employer:** the company being audited.
- **Functional reporting:** the audit committee of the board (independence safeguard).
- **Administrative reporting:** usually the CEO or CFO (source of recurring conflict).
- **Charter:** an internal audit charter approved by the audit committee defines scope, authority, and independence. The Institute of Internal Auditors (IIA) International Professional Practices Framework (IPPF) is the canonical reference.
- **Conflict pattern:** when the CFO controls the IA budget and performance reviews, "independence" becomes performative. Mature programs route compensation decisions through the audit committee chair.

### External audit

- **Employer:** an independent firm (Big Four, mid-tier like BDO/Grant Thornton/RSM, or boutique).
- **Independence rules:** strict — SEC, PCAOB, AICPA, and IESBA codes prohibit non-audit services to audit clients beyond narrow limits, restrict personal investments, and impose cooling-off periods for partners rotating off engagements.
- **Engagement letter:** binds scope, fee, deliverable, and limitations. Signed before fieldwork.
- **Conflict pattern:** fee pressure. The same firm that signs your opinion may also want consulting revenue. SOX and the EU Audit Regulation address this with rotation and prohibited-services lists.

## Scope

### Internal audit scope

- Operational audits (process efficiency, fraud risk).
- Financial controls (Sarbanes-Oxley 404 walkthroughs and testing in US-listed entities).
- IT audits (change management, access reviews, [[siem-detection-use-case-catalog]] coverage, cloud config).
- Compliance audits ([[hipaa-security-rule]], [[pci-dss-4-implementation]], [[nis2-implementation]], [[gdpr-incident-implications]] readiness).
- Special investigations (whistleblower reports, fraud).
- Advisory work (helping new control owners design controls — IIA allows this with safeguards).

### External audit scope

- **Financial statement audit:** opinion on whether statements fairly present financial position under GAAP/IFRS.
- **Integrated audit:** financial + internal control over financial reporting (ICFR) opinion under SOX 404(b).
- **SOC reports:** SOC 1 (ICFR for service organizations), SOC 2 (Trust Services Criteria — security, availability, confidentiality, processing integrity, privacy), SOC 3 (general-use marketing version). See [[soc2-vs-iso27001]] and [[soc2-auditor-track]].
- **ISO 27001 certification audits:** performed by accredited certification bodies, not CPA firms.
- **Agreed-upon procedures (AUP):** narrowly scoped, no opinion.

External audit scope is bounded by the engagement letter. Anything outside it gets a "not within the scope of our engagement" disclaimer.

## Reporting cadence

| Dimension | Internal audit | External audit |
|---|---|---|
| Plan horizon | Annual audit plan, refreshed quarterly | Annual engagement, sometimes multi-year |
| Fieldwork rhythm | Continuous; multiple concurrent audits | Compressed — interim (Q3) and year-end (Q1) for financial; rolling for SOC 2 Type II |
| Reporting cycle | Each audit produces a report; quarterly audit committee summary | One opinion at year-end; SOC 2 reports annually |
| Issue follow-up | IA tracks remediation continuously | EA re-tests at next audit; not a remediation partner |

## Three lines of defense

The IIA's "Three Lines Model" (updated 2020 from "Three Lines of Defense") is the standard mental model:

1. **First line — operational management:** owns and manages risk day-to-day. Security engineers, SOC analysts, dev teams, control owners.
2. **Second line — risk and compliance functions:** sets policy, monitors, advises. GRC team, CISO office, privacy office. Independent from first line but still management.
3. **Third line — internal audit:** independent assurance to the board on whether lines one and two are working.

External audit sits **outside** the three lines as an independent assurance provider to shareholders and regulators. Confusing IA with EA, or putting IA inside the second line (e.g., having IA write policy), breaks the model.

## Defensive baseline for control owners

You will be audited. The baseline that survives both IA and EA scrutiny:

- **Documented control description.** What does the control do, when, by whom, with what evidence?
- **Evidence repository.** Tickets, log exports, signed approvals, screenshots dated and source-attributable. Store immutably — auditors ask for samples by date range.
- **Population completeness.** Auditors test samples drawn from a complete population. If you cannot prove the population is complete, samples are meaningless.
- **Exception log.** Track every deviation, who approved, why. Hiding exceptions guarantees a finding when discovered.
- **Management response template.** Know how to write a response that accepts, mitigates, or risk-accepts a finding without sounding defensive.
- **Walkthrough rehearsal.** Before fieldwork, walk a peer through the control end-to-end. Gaps surface here, cheaply.

## Career implications

### Internal audit career arc

- **Entry:** staff auditor, often from a Big Four secondee or fresh from school. $70k-$95k US base in 2025.
- **Senior auditor (3-5 years):** $95k-$130k. Leads audits, drafts reports.
- **Audit manager (6-10 years):** $130k-$180k. Owns a portfolio, manages staff, presents to audit committee subcommittees.
- **Director/Senior Director (10-15 years):** $180k-$260k. Owns the audit plan, reports to the Chief Audit Executive (CAE).
- **CAE / Chief Audit Executive (15+ years):** $260k-$500k+ at large enterprises, equity in private companies. Reports to audit committee chair.
- **Travel:** moderate. Site visits a few times per year unless you cover a global footprint.
- **Lifestyle:** generally 40-50 hour weeks, predictable. Peaks during plan approval and SOX testing seasons.
- **Who thrives:** people who like depth, organizational knowledge, and not having to chase new clients. Patience for committee politics.
- **Who struggles:** people who want variety, ownership of outcomes (IA recommends, management decides), or who find the "always the outsider in the room" dynamic isolating.

### External audit career arc

- **Associate (0-2 years):** $65k-$85k US base + overtime. 60-80 hour busy seasons.
- **Senior associate (2-5 years):** $85k-$115k. Runs sections of the audit, supervises associates.
- **Manager (5-8 years):** $130k-$180k base + bonus. Owns engagements, manages clients.
- **Senior manager (8-12 years):** $180k-$260k + bonus. Pipeline development begins.
- **Partner (12-15+ years):** $400k-$1M+ depending on book and firm. Buy-in required at most firms.
- **Travel:** high historically; lower post-pandemic but still 25-50% for many.
- **Lifestyle:** busy season is brutal (Jan-March for calendar-year audits, plus interim work). Off-season is reasonable.
- **Who thrives:** competitive personalities who want variety, fast progression, and a credentialing engine. Partner track rewards rainmakers, not technicians.
- **Who struggles:** people who want depth in one company, balanced hours, or who dislike client service dynamics. Attrition is high — 50%+ of associates leave within 4 years.

### Common transitions

- **EA → IA:** very common at senior associate or manager level. Trade compensation ceiling for hours.
- **EA → industry control owner / SOX PMO:** the "exit the Big Four" path.
- **EA → GRC / security:** technical EA staff who passed [[soc2-auditor-track]] engagements often pivot into security GRC, then into [[ciso-vciso-track]].
- **IA → CISO / Chief Risk Officer:** the IT audit lead becomes a credible CISO candidate at risk-mature firms.
- **IA → external consulting:** mid-career IA leaders sometimes leave for advisory practices.

## How technical auditors fit

### Inside internal audit

- IT audit team within IA covers infrastructure, applications, cloud, and increasingly DevSecOps.
- Data analytics teams build continuous auditing pipelines (full-population analysis vs. sampling).
- Security audit overlap: IA may test [[detection-engineering-pyramid-of-pain]] coverage, [[purple-team-feedback-loop]] effectiveness, or [[appsec-maturity-checklist]] adherence.
- Reports up through the audit director to the CAE.

### Inside external audit

- IT audit ("ITRA" or "Risk Assurance") is a separate service line at most firms.
- SOC 2 and ISO 27001 readiness/attestation sit here, alongside SOX ITGC testing.
- Penetration testing inside the firm is usually in a non-audit advisory practice — independence rules prevent the same partner team from auditing and pentesting the same client.
- Technical staff are often the "translation layer" between assurance partners and client engineering teams.

## Co-sourcing arrangements

Pure in-house IA is rare at smaller companies and at firms with specialized technical scope. Common patterns:

- **Full outsource:** IA function delivered by an external firm under a multi-year contract. Common for sub-$1B revenue companies.
- **Co-sourcing:** core IA team supplemented by external specialists for specific audits (e.g., cloud, AI, [[ics-scada-protocols-attacks]] OT environments).
- **Guest auditor:** SME from another business unit joins an audit for a single engagement. Cheap, requires independence carve-outs.

Independence concern: the same firm cannot perform external audit and provide IA outsourcing to the same SEC registrant. PCAOB and EU Audit Regulation enforce this.

## Common conflicts

- **IA reporting to CFO administratively.** When the CFO is the audited party (revenue recognition, expense controls), this is a structural conflict. Mitigations: audit committee chair sets IA compensation, CAE has direct access to the chair without CFO presence.
- **Management restricting IA scope.** "We do not have time for that audit this year." Solved by an audit committee-approved plan that cannot be edited unilaterally.
- **EA selling consulting to audit client.** Restricted by SOX 201 and EU rules; firms often have "audit-only" tiers for large clients.
- **EA partner tenure.** Lead audit partner rotation required every 5 years (US) / 7 years (EU). Firm-level rotation required in EU public-interest entities.
- **IA pulled into operational decisions.** When IA helps design a control, they cannot independently audit it next year. IIA permits advisory work with documented safeguards and rotation.

## Workflow to study

1. Read the IIA IPPF (free) for the IA framework, the AICPA SSAE 18 / SOC reporting framework for EA, and the PCAOB auditing standards if US-listed companies are in scope.
2. Sit in on an audit committee meeting if you can. Watch how findings are presented and how management responses are negotiated. The dynamics surprise most engineers.
3. Read a real SOC 2 Type II report end-to-end (vendor portals expose these to customers). Note the section II description, section III testing matrix, and section IV management response.
4. Walk a control end-to-end with both an internal auditor and an external auditor. Compare the questions. EA chases the standard; IA chases the risk.
5. Try writing a finding. The hardest skill is being clear, factual, and non-accusatory in 200 words.

## Certifications relevant to each

- **Internal audit:** CIA (Certified Internal Auditor — IIA), CISA (ISACA, IT audit), CRMA (risk assurance).
- **External audit:** CPA (jurisdictional — required for signing partners on US financial audits), ACA/ACCA in UK and commonwealth, CISA for IT audit staff, ISO 27001 Lead Auditor for certification bodies.
- **Both:** CFE (fraud), CISSP (for security audit roles), CCSP / cloud certifications, CIPP/E for privacy audits intersecting [[gdpr-incident-implications]].

## References

- IIA — Three Lines Model (2020): https://www.theiia.org/en/content/position-papers/2020/the-iias-three-lines-model/
- IIA International Professional Practices Framework: https://www.theiia.org/en/standards/2024-standards/
- AICPA — SOC for Service Organizations: https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2
- PCAOB Auditing Standards: https://pcaobus.org/oversight/standards/auditing-standards
- EU Regulation 537/2014 (Audit Regulation): https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32014R0537
- ISACA — CISA certification overview: https://www.isaca.org/credentialing/cisa

## Related

- [[security-auditor-career-track]]
- [[ciso-vciso-track]]
- [[soc2-auditor-track]]
- [[soc2-vs-iso27001]]
- [[pci-dss-4-implementation]]
- [[hipaa-security-rule]]
- [[nis2-implementation]]
- [[gdpr-incident-implications]]
- [[appsec-maturity-checklist]]
- [[secure-sdlc-rollout-playbook]]
