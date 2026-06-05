---
title: SOC 2 auditor track (CPA-led)
slug: soc2-auditor-track
aliases: [soc2-auditor, aicpa-attest-track]
---

> **TL;DR:** SOC 2 is an AICPA attestation engagement, which means the report MUST be signed by a licensed CPA firm — the career path is therefore CPA-anchored even though the day-to-day work is largely IT and security testing. Non-CPA security specialists work under a CPA partner's supervision and contribute the technical depth that the CPA signature lacks. If you are choosing between this and the [[soc2-vs-iso27001]] world, or comparing to [[pci-qsa-career-track]] and the broader [[security-auditor-career-track]], understand the licensure model first — it shapes hiring, salary ceilings, and who gets to call themselves "lead auditor."

## Why it matters

SOC 2 is the dominant trust report for US-headquartered SaaS, and demand from enterprise procurement is what drives most of the work. Unlike ISO 27001 (issued by accredited certification bodies under ISO/IEC 17021) or PCI DSS (issued by QSACs under PCI SSC), SOC 2 lives inside the AICPA's attestation standards (AT-C 105 / 205 / 320). That has three practical consequences:

- The opinion letter must be signed by a CPA who is a partner in a CPA firm registered for attest work.
- The methodology, working papers, and quality review follow AICPA peer-review rules — not ISO/IEC 17021, not PCI SSC QA.
- The career ladder inside firms mirrors public accounting (Associate → Senior → Manager → Senior Manager → Partner), with "busy season" cycles tied to client fiscal year-ends.

Security engineers often discover this only after they accept the job and wonder why the partner with no AWS experience is signing their report. The model is not going to change — it is statutory.

## The attestation framework (what you are actually doing)

### What SOC 2 is

A SOC 2 report is an attestation engagement under SSAE 21 (which codified AT-C 105 and 205). The practitioner (CPA firm) issues an opinion on whether management's description of the system is fairly presented and whether controls were suitably designed (Type 1) or operated effectively over a period (Type 2) against the AICPA's Trust Services Criteria (TSC): Security (required), Availability, Confidentiality, Processing Integrity, Privacy (optional).

### Who can sign

Only a CPA firm enrolled in the AICPA Peer Review Program and licensed to perform attest engagements in the relevant state(s). The engagement partner must be a CPA in good standing. Non-CPAs cannot issue the report — full stop.

### Who actually does the work

Most of the testing — control walkthroughs, evidence sampling, configuration review, vulnerability management evidence, AWS/Azure/GCP control validation, change management sampling — is performed by staff who are often not CPAs. Many are IT auditors, ex-sysadmins, ex-SOC analysts, or recent CS/MIS grads. The CPA partner reviews, supervises, and signs.

### The "specialist" track for security people

AICPA explicitly contemplates the use of specialists (AT-C 105.A48–A58, AU-C 620 by analogy). A penetration tester, cloud security engineer, or cryptographer can be engaged as an internal or external specialist whose work supports the CPA's opinion. This is how non-CPA security pros build long careers in SOC 2 without ever sitting the CPA exam — they are positioned as IT/security subject-matter experts feeding evidence and judgment up to the signing partner.

## Employer landscape

### Specialist SOC 2 firms

- **Schellman** — large pure-play attestation firm, also a QSAC, FedRAMP 3PAO, ISO certification body. Strong technical bench.
- **A-LIGN** — multi-framework (SOC, ISO, FedRAMP, HITRUST, PCI), heavy automation tooling integration.
- **Sensiba** (formerly Sensiba San Filippo, now part of broader rollups) — mid-market SOC 2 plus full CPA practice.
- **Prescient Assurance**, **Insight Assurance**, **Johanson Group**, **BARR Advisory** — boutique-to-mid SOC 2 shops, often friendlier to non-CPA security hires.

### Big Four

Deloitte, PwC, EY, KPMG all run SOC 2 practices, usually inside Risk Advisory / Assurance. Pay is higher, brand carries, but you may rotate across SOX, internal audit, and other engagements. Specialization in pure SOC 2 is harder.

### Regional CPA firms

Crowe, BDO USA, Grant Thornton, RSM, Moss Adams, Aprio, Wipfli, CohnReznick — all do SOC 2 alongside tax/audit. Good entry point if you can tolerate a more traditional accounting culture.

### In-house "auditee" side

Many SaaS companies hire ex-SOC 2 auditors into GRC, internal audit, or compliance engineering roles. This is the most common exit and often pays better than staying on the firm side.

## CPA path optionality (do you have to become a CPA?)

Short answer: no, but it caps your ceiling on the firm side.

### If you do not pursue the CPA

You can have a long, well-paid career as a senior IT/security auditor or specialist, especially at Schellman/A-LIGN-type firms. You will not sign reports. You will not make equity partner in the attest practice (firm-specific exceptions exist for non-attest partners). You can absolutely become a senior manager.

### Lighter credentials that help

- **AICPA Cybersecurity Risk Management certificate** — designed for non-CPAs and CPAs alike, focused on SOC for Cybersecurity / TSC fluency.
- **CITP (Certified Information Technology Professional)** — AICPA credential, requires CPA license; signals IT-audit specialization.
- **CISA** — near-universal for IT auditors; many SOC 2 firms list it as preferred.
- **CISSP / CCSP** — useful when you are pitched as a security specialist rather than an auditor.
- **Cloud certs (AWS Security Specialty, Azure SC-100)** — increasingly required given how much SOC 2 evidence is now cloud-config.

### If you go for the CPA

Requires 150 credit hours, the four-section CPA exam, and 1–2 years of experience under a licensed CPA depending on state. Most security people who do this route accept that the financial accounting and tax sections are the price of admission and grind through them. The payoff is the ability to sign reports and the partner track.

## How SOC 2 differs operationally from ISO 27001

See [[soc2-vs-iso27001]] for the full comparison; the operational deltas that matter to an auditor:

- **Point-in-time vs continuous** — SOC 2 Type 2 covers a defined audit period (commonly 6 or 12 months) and is re-issued annually. ISO 27001 is a 3-year certification cycle with surveillance audits.
- **US-centric** — SOC 2 is recognized primarily by US buyers. EU and APAC enterprises often want ISO 27001 instead or in addition.
- **More flexibility in controls** — SOC 2 has Trust Services Criteria but no fixed Annex A; the service org defines controls and the auditor opines on whether they meet the criteria. ISO 27001 has the Annex A control set as a baseline.
- **Report vs certificate** — SOC 2 produces a long narrative report (often 60–150 pages) with the auditor's opinion, system description, and test results. ISO 27001 produces a short certificate plus a confidential audit report.
- **Distribution** — SOC 2 reports are restricted-use (per AT-C 205) and shared under NDA; ISO certificates are public.

## Salary trajectory (US, realistic 2025–2026)

These are total compensation ranges seen at specialist firms and Big Four; regional CPA firms trend 10–20% lower, boutiques vary widely.

- **Associate / Staff (0–2 yrs)** — 70–95k base, modest bonus.
- **Senior (2–4 yrs)** — 95–135k base, 5–15% bonus, often a small overtime/utilization component.
- **Manager (4–7 yrs)** — 135–180k base, 10–25% bonus.
- **Senior Manager (7–10 yrs)** — 175–230k base, 20–35% bonus.
- **Partner / Principal (10+ yrs, CPA required for attest signing)** — 300k–700k+ total, with equity / buy-in dynamics.

Specialist (non-CPA) senior consultants and managers often match the manager band but plateau there unless they pivot to in-house or sales/solutions roles.

### Common transitions

- **Out:** GRC engineer at a SaaS, internal audit at a public company, security compliance lead, customer trust / TPRM, sales engineering for compliance automation vendors (Vanta, Drata, Secureframe, Anecdotes).
- **In:** ex-Big Four SOX IT auditors, ex-sysadmins, ex-SOC analysts, ex-consultants from boutique cyber shops, recent grads from MIS / accounting programs.

## Day-to-day reality

### Busy season

For SaaS clients on a calendar fiscal year, audit fieldwork concentrates Q4 and Q1 — many SOC 2 Type 2 reports cover Jan–Dec or Oct–Sep periods. Expect 55–70 hour weeks Nov–Mar at most firms. Off-season is genuinely slower.

### What you actually do

- Kickoff and walkthrough meetings to update the system description.
- Sampling — pulling 25 change tickets, 40 access provisioning events, 15 terminations, etc., from client systems.
- Evidence review in client-shared folders or platforms like Vanta / Drata / AuditBoard.
- Cloud control testing — IAM policies, logging configs, encryption settings (see [[cloud-ir-aws-cloudtrail]], [[cloud-ir-azure-activity-log]], [[cloud-ir-gcp-audit-logs]] for the same evidence sources from a detection angle).
- Drafting test workpapers and exceptions.
- Report drafting — system description edits, criteria mapping, exceptions language.

### Who succeeds

People who can read a cloud config and a SOC 2 criterion in the same sitting, write cleanly, push back politely on engagement partners about technical accuracy, and tolerate repetitive evidence collection. Curiosity about how the client's stack actually works helps a lot.

### Who struggles

People who want to break things — SOC 2 is not pentesting (see [[pentest-engagement-execution]] if that is your itch). People who hate writing. People who cannot stomach the sampling-and-evidence rhythm. People who expect the CPA partner to defer to their technical judgment on a signature decision.

## Defensive baseline (if you sit on the auditee side)

If you are the security engineer being audited rather than the auditor:

- Treat SOC 2 evidence as a year-round program, not a Q4 scramble. Automate evidence collection from ticketing, IdP, cloud, and EDR.
- Map your controls to TSC once, then re-use across [[hipaa-security-rule]], [[pci-dss-4-implementation]], and ISO 27001 where overlaps exist.
- Keep your system description honest — overstating controls is how you get qualified opinions.
- Track exceptions as security findings; feed them into your [[appsec-maturity-checklist]] and [[secure-sdlc-rollout-playbook]] backlogs.

## Workflow to study

1. Read AICPA's TSP Section 100 (2017 TSC with 2022 points of focus revisions) end to end. This is the actual rulebook.
2. Read AT-C 105 and AT-C 205 to understand the attestation framework.
3. Download two or three public SOC 3 reports (the public-facing version) from major SaaS vendors to see report structure.
4. Sit a SOC 2 Type 2 mock engagement at a boutique firm — ask explicitly to rotate across security, change management, and access management testing.
5. Pick a cloud provider and learn the evidence patterns deeply — AWS Config, CloudTrail, IAM Access Analyzer, Security Hub. Most SOC 2 evidence today is cloud-config evidence.
6. Decide on CPA vs specialist track within 18 months — the 150-hour requirement makes deferring the CPA expensive if you change your mind later.
7. If you are CPA-bound, schedule REG and AUD first; FAR and BEC/discipline can come later.

## Related

- [[soc2-vs-iso27001]]
- [[security-auditor-career-track]]
- [[pci-qsa-career-track]]
- [[appsec-maturity-checklist]]
- [[secure-sdlc-rollout-playbook]]
- [[hipaa-security-rule]]
- [[pci-dss-4-implementation]]
- [[cloud-ir-aws-cloudtrail]]
- [[cloud-ir-azure-activity-log]]
- [[cloud-ir-gcp-audit-logs]]

## References

- AICPA, "Trust Services Criteria for Security, Availability, Processing Integrity, Confidentiality, and Privacy" — https://www.aicpa-cima.com/resources/download/2017-trust-services-criteria-with-revised-points-of-focus-2022
- AICPA, "SOC 2 — SOC for Service Organizations: Trust Services Criteria" overview — https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2
- AICPA, "Statement on Standards for Attestation Engagements (SSAE) No. 21" — https://us.aicpa.org/research/standards/auditattest/ssae
- AICPA Cybersecurity Risk Management certificate — https://www.aicpa-cima.com/cpe-learning/course/cybersecurity-fundamentals-for-finance-and-accounting-professionals-certificate
- Schellman, "SOC 2 services" — https://www.schellman.com/soc-2
- A-LIGN, "SOC 2 audit" — https://www.a-lign.com/services/soc-2
