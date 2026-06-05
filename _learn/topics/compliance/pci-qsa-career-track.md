---
title: PCI QSA — Qualified Security Assessor career
slug: pci-qsa-career-track
aliases: [pci-qsa, qualified-security-assessor]
---

> **TL;DR:** A Qualified Security Assessor (QSA) is an auditor employed by a PCI SSC–registered QSA Company (QSAC) who is authorized to validate that merchants and service providers meet PCI DSS. The badge is on the company, not the individual — you can only practice as a QSA while employed by a QSAC. The job pays solidly (typically USD 90k–180k for individual contributors), demands a lot of travel and Q4 crunch, and is a fast track into security leadership if you can stomach the audit grind. Pair with [[pci-dss-4-implementation]] and [[security-auditor-career-track]] for the technical and career context, and [[building-a-pci-dss-program-practitioner]] for the other side of the table.

## Why it matters

If your company handles cardholder data and falls into Level 1 (or any service provider tier that requires a Report on Compliance), a QSA is the person who decides whether you get to keep accepting cards. That makes QSAs one of the more consequential auditor roles in security: their sign-off has direct revenue impact, and their findings drive remediation budgets that other compliance programs only dream of.

For a practitioner choosing a path, QSA work sits in a sweet spot:

- Technical enough that you stay close to networks, crypto, segmentation, logging, and appsec — not pure paperwork.
- Structured enough that the deliverable (the ROC) is well-defined and repeatable.
- Visible enough that you meet CISOs, network architects, and DevOps leads at dozens of companies a year. That Rolodex is the real exit value.

Compare and contrast with [[soc2-vs-iso27001]] for adjacent audit paths, and [[appsec-maturity-checklist]] / [[secure-sdlc-rollout-playbook]] for the controls QSAs frequently dig into.

## What a QSA actually does

### The product: Report on Compliance (ROC) and AOC

A QSA's billable output is the **Report on Compliance** — a long, structured document (hundreds to thousands of pages for big merchants) that walks through every PCI DSS requirement, describes the testing performed, and records a Pass / Not Applicable / Not Tested / Fail verdict. The companion **Attestation of Compliance (AOC)** is the short signed summary that gets shared with acquirers and customers.

QSAs also commonly produce:

- **Gap assessments** before the formal ROC engagement (sometimes called "readiness" or "pre-assessment").
- **SAQ validation** for smaller merchants who self-assess but want an assessor to review.
- **P2PE, 3DS, and Software Security Framework** assessments for vendors with specialized scopes.

### The day-to-day

In a typical week during fieldwork:

- Interview owners of in-scope systems (network, AD, key management, change management, dev, SOC).
- Sample evidence: configs, change tickets, access reviews, vuln scan reports, ASV scans, pentest reports, training records.
- Observe processes live (firewall rule change approvals, key ceremonies, incident response tabletops).
- Walk the CDE physically when feasible (datacenter, retail store, call center).
- Reconcile what you saw to what each PCI DSS sub-requirement actually asks for, and write it up in the assessor's reporting template.

Off-fieldwork weeks are quieter: scoping calls, drafting ROC sections, internal QA review, and remediation guidance for clients fixing the things you flagged.

## Who registers the QSA — companies, not people

This is the single most important structural point and the one most candidates get wrong.

- The **PCI Security Standards Council** publishes a register of **QSA Companies (QSACs)**. Individuals are listed under the company they work for.
- You **cannot moonlight as an independent QSA**. If you leave a QSAC, your authorization to sign ROCs pauses until you join another QSAC and the SSC updates the register.
- The QSAC must maintain insurance, quality management, and independence requirements. Solo consultants typically partner with a QSAC as a subcontractor under that QSAC's program.

The practical implication: pick your employer carefully. The brand on the AOC is theirs, not yours.

## Employer landscape

### Specialist assessor firms

These are the firms that live and breathe PCI plus adjacent frameworks (HITRUST, SOC 2, FedRAMP, ISO 27001):

- **Coalfire**, **Schellman**, **A-LIGN**, **Kirkpatrick Price**, **Trustwave** (Spider Labs side), **NCC Group**, **Bishop Fox** (PCI line), **TrustedSec**, **Optiv**.
- **Mandiant** / Google Cloud Security does PCI work mostly as part of broader assessments.

Pros: deep PCI bench, structured training, clear ladder (Associate -> QSA -> Senior QSA -> Manager -> Principal). Cons: utilization targets are real, busy season is brutal.

### Big Four and large consultancies

**Deloitte, PwC, EY, KPMG**, plus **Accenture Security**, **Protiviti**, **BDO**, **RSM**.

Pros: brand, cross-sell into other audit / advisory work, exposure to large complex environments, structured up-or-out career path. Cons: more billable-hour pressure, more "consulting" overhead, often slower technical specialization.

### Boutique QSACs

Small shops — sometimes 10 to 50 people — often founded by ex-Big Four or ex-Coalfire QSAs. More autonomy, less travel sometimes, lower utilization pressure, but smaller bench means you handle everything from scoping calls to invoicing.

### In-house ISA (Internal Security Assessor)

The **ISA** program is the in-house variant: you work for a single merchant or service provider, you take the SSC training, and you can run the internal pre-assessment and (depending on the scheme) sign portions of self-assessments. You cannot sign an external ROC for your employer — that still requires an independent QSA. ISAs typically sit inside the compliance, GRC, or security engineering org of a Level 1 merchant.

ISA is a good fit if you like depth on one environment and prefer stable hours to the consulting grind. Many ISAs eventually become QSAs (or vice versa).

## Becoming a QSA

### Prerequisites

You usually need:

- An InfoSec certification that the SSC accepts — CISSP, CISA, CISM, ISO 27001 LA, GIAC GSNA, or equivalent.
- Documented audit / assessment experience (typically 3+ years).
- Sponsorship by a QSAC — the company enrolls you in QSA training; you cannot self-enroll.

### The exam

The QSA qualification is delivered by the PCI SSC. Current structure:

- **Instructor-led training** (online or in-person) covering PCI DSS requirements, assessor reporting expectations, and the ROC template.
- **Knowledge exam** — multiple choice over the DSS, sampling, scoping, and the assessor program.
- **Practical reporting exercise** — write up sample testing for representative requirements; this is where many candidates struggle, because the SSC has a specific voice they want in ROCs.

### Maintenance

QSAs **re-qualify annually** — refresher training each year (released when a new DSS version drops and at routine cadence), and CPE-style continuing education tracked by your QSAC. Miss the refresher window and your QSA status lapses.

## Skills that matter on the job

A strong QSA is genuinely T-shaped:

- **Network** — segmentation, NGFW rule analysis, jump hosts, micro-segmentation patterns. You need to spot when a "segmented" CDE is actually one VLAN misconfig away from flat.
- **Cryptography** — TLS configs, key management lifecycle, HSM patterns, tokenization vs encryption tradeoffs, the basics of [[post-quantum-crypto-attack-surface]] becoming a near-future conversation.
- **Identity** — RBAC, JIT, MFA across admin paths, federation; familiarity with [[bloodhound]] / AD risk topics helps when you assess Windows environments.
- **AppSec** — secure SDLC ([[secure-sdlc-rollout-playbook]]), code review evidence, ASV scans, internal vuln management, pentest scope adequacy ([[pentest-proposal-and-scoping]]).
- **Logging & monitoring** — what a real SIEM use-case catalog looks like ([[siem-detection-use-case-catalog]]), how to evaluate whether DSS Requirement 10 is actually being met versus theatrically met.
- **Cloud** — AWS / Azure / GCP shared-responsibility reading, and how cloud-native logging feeds the CDE assessment ([[cloud-ir-aws-cloudtrail]], [[cloud-ir-azure-activity-log]], [[cloud-ir-gcp-audit-logs]]).

Soft skills that separate good from great:

- Writing — you ship documents for a living.
- Diplomacy — most of the job is telling smart people their control is insufficient without making them defensive.
- Time management — you will juggle 4 to 8 active engagements at any time.

## Salary and trajectory

Rough US ranges (2024–2026, adjust for region and firm):

- **Associate / Staff (pre-QSA, on the way)** — USD 75k–110k.
- **QSA (1–3 years post-qualification)** — USD 100k–145k base, plus utilization or signing bonus.
- **Senior QSA / Lead Assessor (4–7 years)** — USD 140k–190k.
- **Manager / Practice Lead** — USD 170k–230k+ with bonus.
- **Director / Partner** — USD 220k–400k+ at large firms; equity / partner draws at boutiques.

Europe, APAC, and LATAM run roughly 30–50 percent lower at the same band, with day-rate consulting models common in UK / DACH.

Bonus / variable comp is heavily tied to utilization (billable hours target, often 1500–1700 chargeable per year) and engagement margin.

## The honest reality

- **Travel.** Pre-pandemic this was 50–80 percent travel for fieldwork. Today many assessments are partially remote, but in-person walkthroughs are still expected for retail and datacenter scopes. Expect 25–60 percent travel.
- **Q4 / Q1 crunch.** Most merchants' fiscal years end Dec 31, so ROCs cluster Jan–Mar. Sixty-hour weeks in busy season are normal.
- **Repetition.** You will assess Requirement 8 (access control) for the 200th time and have to bring the same energy. People who need novelty get burned out; people who enjoy pattern-matching across environments thrive.
- **Politics.** Findings cost clients real money. Expect pushback. Your QSAC backs your judgment, but you must defend it with evidence.

### Who succeeds

- Engineers who can read a config and a contract.
- People who like writing more than coding.
- Ex-pentesters who got tired of the road but want to stay technical (some find QSA work even more travel; others land at firms with stable client portfolios).

### Who struggles

- People who want to build, not assess.
- People who need fast feedback loops — a ROC cycle is months long.
- People who interpret "the standard says X" as a moral failing in the client; clients will smell that and resist.

## Comparison to ISO 27001 Lead Auditor

| Dimension | PCI QSA | ISO 27001 LA |
|---|---|---|
| Scope | One standard, deep | One standard, broad ISMS framing |
| Authorization | Held by QSAC | Held by Certification Body (CB) |
| Renewal | Annual SSC refresher | CB-specific, often 3-year cycle + CPE |
| Output | ROC + AOC | Audit report + certificate |
| Technical depth | High (network, crypto, appsec) | Medium (mostly process & ISMS) |
| Travel | Medium–High | Medium |
| Pay (US) | Slightly higher mid-career | Comparable; depends on CB |

Many senior auditors hold both, plus SOC 2 ([[soc2-vs-iso27001]]) and HITRUST credentials. Cross-framework fluency is the moat at the Senior / Manager level.

## Common transitions out

- **CISO / Head of GRC at a merchant or fintech.** You already know what good looks like from 40+ environments.
- **Compliance lead at a SaaS vendor selling into regulated markets.** Especially attractive at Series B–D startups needing first ROC.
- **Cloud security architect** with a regulated-industry tilt.
- **Partner / Director at a QSAC or Big Four** — the up-or-out path.
- **Independent consultant** — common after Manager grade; you subcontract to a QSAC for assessor work and bill advisory work directly.

## Workflow to break in

1. Get one or two anchor certs: **CISSP or CISA** first; **CISM** or **ISO 27001 LA** later.
2. Pick a target QSAC tier (specialist vs Big Four vs boutique) and study their public ROC samples and blog content.
3. Apply for an **Associate / Senior Consultant** role at a QSAC. Most firms hire pre-QSA and sponsor the qualification once you've shadowed 1–2 engagements.
4. Read PCI DSS v4.x end-to-end ([[pci-dss-4-implementation]]) plus the Report on Compliance Reporting Template and ROC Frequently Asked Questions.
5. Build a home lab that mirrors a tiny CDE: segmented network, hardened jump host, centralized logging, a fake payment app. Practice writing a ROC section against it; see [[building-a-research-home-lab]].
6. Shadow internal audits if you can't get external — ISA training is a great stepping stone if your current employer takes cards.
7. Network at PCI SSC Community Meetings (North America, Europe, APAC).

## Related

- [[pci-dss-4-implementation]]
- [[building-a-pci-dss-program-practitioner]]
- [[security-auditor-career-track]]
- [[soc2-vs-iso27001]]
- [[hipaa-security-rule]]
- [[nis2-implementation]]
- [[gdpr-incident-implications]]
- [[appsec-maturity-checklist]]
- [[secure-sdlc-rollout-playbook]]
- [[pentest-proposal-and-scoping]]
- [[siem-detection-use-case-catalog]]
- [[building-a-research-home-lab]]

## References

- PCI Security Standards Council — Qualified Security Assessor (QSA) program overview: https://www.pcisecuritystandards.org/assessors_and_solutions/qualified_security_assessors
- PCI SSC — Internal Security Assessor (ISA) program: https://www.pcisecuritystandards.org/assessors_and_solutions/internal_security_assessors
- PCI SSC — Document library (DSS v4.x, ROC Reporting Template, AOC templates): https://www.pcisecuritystandards.org/document_library/
- PCI SSC — Assessor qualification requirements and code of conduct: https://www.pcisecuritystandards.org/program_training_and_qualification/qualification_requirements/
- Coalfire — PCI assessment service overview (representative QSAC practice): https://www.coalfire.com/services/cybersecurity-compliance/pci
- Schellman — PCI QSA service overview (representative QSAC practice): https://www.schellman.com/pci-compliance
