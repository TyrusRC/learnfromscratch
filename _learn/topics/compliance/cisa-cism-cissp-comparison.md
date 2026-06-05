---
title: CISA / CISM / CISSP / CRISC — practitioner comparison
slug: cisa-cism-cissp-comparison
aliases: [cisa-cism-cissp, security-management-certs-compare]
---

> **TL;DR:** CISA, CISM, CISSP and CRISC are the four certifications that consistently show up on management, audit and senior-IC security job descriptions, and picking the wrong one for your career stage wastes 6-12 months and a few thousand dollars. CISA is for auditors, CISM for managers, CISSP for broad senior ICs moving into leadership, and CRISC for risk practitioners — most people pick one anchor cert and stop. See the companion notes [[security-auditor-career-track]], [[ciso-vciso-track]] and [[grc-analyst-career-track]] for what the day-to-day actually looks like in each lane.

## Why it matters

If you work in security long enough, three things happen. Recruiters start filtering by certs in the job-description's "required" line. Procurement and customers start asking your employer "does the security lead hold CISSP/CISM?" as part of vendor due-diligence (especially for [[soc2-vs-iso27001]] audits). And your own promotion conversations start including phrases like "we'd like to see you finish CISSP before we move you to the manager track."

Certifications are not knowledge. Most working senior engineers can pass CISSP cold, and most CISSP holders cannot actually run an incident response. But they are screening signals, and ignoring them at the staff/manager career stage is a self-inflicted wound. The flip side is also true — junior engineers who chase CISSP before they have the prerequisite experience often end up as "CISSP Associates" with no real leverage, having spent 9 months studying for a test that would have been easier and more valuable two years later.

This note is the practitioner's lookup table. Pick the cert that matches the role you actually want, not the one with the most LinkedIn prestige.

## The four (plus two) certifications

### CISA — Certified Information Systems Auditor (ISACA)

Target role: IT auditor, internal auditor with IT focus, [[soc2-vs-iso27001]] / [[pci-dss-4-implementation]] assessor, third-party risk reviewer. The cert most often listed as **required** (not preferred) on Big Four audit-practice job postings and internal-audit team postings.

Exam: 150 multiple-choice questions, 4 hours, online or testing-centre proctored. Five domains: audit process, governance, acquisition/development/implementation, operations, protection of information assets. Pass mark is a scaled score of 450/800.

Experience: 5 years of IS audit/control/security work. Up to 3 years can be waived with a degree or other ISACA certs. You can pass the exam first and complete experience within 5 years.

Cost (2026): ISACA member exam fee ~USD 575, non-member ~USD 760, plus membership (~USD 135/yr) and annual maintenance fee (~USD 45 member / USD 85 non-member). CPE: 20 hours/year, 120 hours over 3 years.

Verdict: If your job title is, or will be, "auditor" — this is the anchor cert. If you are an engineer who happens to do internal control work, CISA is still useful but secondary.

### CISM — Certified Information Security Manager (ISACA)

Target role: Security manager, security programme lead, BISO, head of security at small/mid orgs, vCISO consultant. Heavily favoured in European and APAC job postings; in the US it competes with CISSP for management roles.

Exam: 150 MCQ, 4 hours. Four domains: governance, risk management, programme development, incident management. Same scaled scoring as CISA.

Experience: 5 years in info-sec management, with at least 3 in management roles. Up to 2 years waivable with CISSP, CISA, or a security degree.

Cost: Same fee structure as CISA. CPE: 120 hours over 3 years.

Verdict: The cert to chase when you've been a manager for 2-3 years and want to move to senior manager / head-of-security. Lighter content than CISSP, but the governance/incident-management framing actually maps to the job. Pairs well with the [[ciso-vciso-track]] path.

### CISSP — Certified Information Systems Security Professional (ISC2)

Target role: Senior IC, security architect, security manager, anyone whose CV needs to clear automated recruiter filters in the US/UK/AU markets. Still the single most "asked-for" cert in job postings globally, despite being a mile wide and an inch deep.

Exam: Computer Adaptive Test (CAT) format in English — 125-175 questions, 3 hours, adaptive scoring. Non-English versions are linear 250-question, 6-hour. Eight domains (the CBK): security and risk management, asset security, security architecture and engineering, network security, IAM, security assessment and testing, security operations, software development security.

Experience: 5 years cumulative paid work in 2+ of the 8 domains. 1 year waivable with a degree or approved cert (CISA, CISM, OSCP, GIAC, etc.). Pass the exam without experience and you become an "Associate of ISC2" until you complete experience within 6 years.

Cost (2026): Exam USD 749, annual membership fee USD 135. CPE: 40 hours/year minimum, 120 hours over 3 years.

Verdict: If you want any senior security role in a US-headquartered company, you will eventually get asked about CISSP. Get it once, maintain it, stop thinking about it. The exam tests "how a manager thinks about security" — not technical depth.

### CRISC — Certified in Risk and Information Systems Control (ISACA)

Target role: Risk analyst, IT risk manager, GRC lead, third-party risk, enterprise risk team. The cert that shows up on [[grc-analyst-career-track]] job postings, especially in financial services and regulated industries.

Exam: 150 MCQ, 4 hours. Four domains: governance, IT risk assessment, risk response/reporting, IT and security.

Experience: 3 years in at least 2 of the 4 domains, with at least 1 year in domain 1 or 2. No waivers.

Cost: Same ISACA fee structure as CISA/CISM.

Verdict: Niche but valuable for the specific risk-management career path. Often paired with CISA (audit + risk) or CISM (management + risk). Less recognised outside ISACA-aware industries.

### CGEIT and CDPSE (brief mentions)

**CGEIT** — Certified in the Governance of Enterprise IT. Niche, board/exec-advisor cert. Skip unless you are a consultant selling IT governance work to boards.

**CDPSE** — Certified Data Privacy Solutions Engineer. ISACA's privacy-engineering cert. Younger and less recognised than CIPP/E or CIPM (IAPP). Worth it if you are an ISACA-stack person who needs a privacy credential; otherwise, CIPP/E is the market standard. See [[gdpr-incident-implications]] for the regulatory context.

## Patterns and process

### Which to pick by career stage

- **0-3 years total experience:** Don't chase any of these yet. Get Security+, a vendor cert (AWS Security, Azure SC-200), or a technical cert like eJPT/PNPT. Build the 5 years of work experience the management certs need.
- **3-5 years, IC track:** CISSP Associate if you want to clear US recruiter filters early. CRISC if you've drifted into risk/GRC work. Don't bother with CISM yet — you don't have the management experience.
- **5-8 years, IC senior:** CISSP. This is the sweet spot.
- **5-8 years, manager:** CISM (if in EU/APAC or finance) or CISSP (if in US tech). Many people do both, but the marginal value of the second is low.
- **5-8 years, audit/assessor:** CISA. Non-negotiable for the Big Four track.
- **8+ years, head of security / vCISO:** You probably already have one. Adding CISM on top of CISSP is the common combo for [[ciso-vciso-track]] consulting work because clients ask for both.

### Employer screening behaviour

Distinguishing "required" from "preferred" in job postings is the key skill:

- **Required (will not interview without):** CISA for Big Four IT audit; CISSP for US federal contractor roles (DoD 8570/8140 IAT-III, IAM-II/III); CISM increasingly for EU regulated-industry CISO roles.
- **Preferred (helps but not blocker):** CISSP for most US senior IC roles; CISM/CRISC for risk/manager roles in finance.
- **Decorative (no real screening effect):** Anything mentioned alongside 4+ other certs in a long "or equivalent" list.

Run this test before studying: search 30-50 current job postings for the role you actually want and count how often each cert appears in the **required** section. Study for the one that wins.

### Study workflow

1. **Pick one cert.** Do not stack-study. CISSP and CISM have ~30% content overlap but the exam framing is different enough that splitting attention hurts both.
2. **Buy the official ISACA review manual or the ISC2 OSG.** Skim cover to cover once. This is the "shape of the test" pass.
3. **Practice questions are the actual study.** Boson, Pocket Prep, or the official ISACA QAE database. Target 70-75% on practice tests before booking the exam.
4. **For CISSP specifically:** the exam asks "what would a CISO do" — not "what is technically correct." Re-read your wrong answers through that lens. The Sybex OSG and Destination Certification's mind maps are the consensus best supplements.
5. **Book the exam to force the deadline.** Most people who fail give themselves 6+ months and lose momentum. 8-10 weeks of focused study is the sweet spot for someone with relevant experience.
6. **CPE maintenance — set a calendar reminder.** Track CPEs as you go (conference talks, training courses, reading [[detection-engineering-pyramid-of-pain]]-grade technical content, writing blog posts). Backfilling at audit time is painful.

## Defensive baseline (what to actually do)

- **Don't pay out of pocket if you can avoid it.** Most employers reimburse one cert per year. Ask before you book.
- **Don't list "in progress" certs on LinkedIn until you've passed.** Recruiters auto-filter on the cert name and treat "studying for CISSP" as noise.
- **Maintain or let lapse — decide deliberately.** Holding 3 certs at 120 CPE/3yrs each is a real annual time cost. If you've moved fully into engineering and the cert isn't doing screening work for you, let it lapse.
- **Watch for the "associate" trap.** ISC2 Associate of CISSP only converts to full CISSP when you log 5 years of work. Don't pay annual fees on an Associate status you're not going to convert.

## Reality check

- **Salary uplift is real but modest.** Average reported uplift for adding CISSP to an existing senior security role is 5-10% in the US, less in EU. The bigger effect is "gets you to the interview" rather than "raises the offer."
- **Day one after passing feels anticlimactic.** Nothing changes immediately. The benefit shows up in your next job search or promotion cycle.
- **Who succeeds:** people who treat the cert as a screening hack to maintain access to roles they're already qualified for.
- **Who struggles:** people who think the cert will compensate for missing experience, or who chase 4+ certs trying to "stand out." Stacking certs reads as "no operational experience" to senior hiring managers.
- **The hardest cert is not always the most valuable.** OSCP is significantly harder than CISSP but doesn't open the same management doors. Match the cert to the door you want.

## Related

- [[security-auditor-career-track]]
- [[ciso-vciso-track]]
- [[grc-analyst-career-track]]
- [[soc2-vs-iso27001]]
- [[pci-dss-4-implementation]]
- [[hipaa-security-rule]]
- [[nis2-implementation]]
- [[gdpr-incident-implications]]
- [[appsec-maturity-checklist]]
- [[bug-bounty-as-career-track]]

## References

- ISACA certification catalogue — <https://www.isaca.org/credentialing>
- ISC2 CISSP exam outline (current revision) — <https://www.isc2.org/certifications/cissp>
- US DoD 8140 / 8570 approved baseline certifications — <https://public.cyber.mil/wid/cwmp/dod-approved-8570-baseline-certifications/>
- ISACA CPE policy reference — <https://www.isaca.org/credentialing/how-to-earn-cpe>
- ISC2 Cybersecurity Workforce Study (annual salary and cert data) — <https://www.isc2.org/research>
- Destination Certification CISSP MasterClass mind maps (community study consensus) — <https://destcert.com/cissp-mindmaps/>
