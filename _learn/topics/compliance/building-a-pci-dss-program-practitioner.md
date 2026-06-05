---
title: Building a PCI DSS compliance program — practitioner playbook
slug: building-a-pci-dss-program-practitioner
aliases: [build-pci-program, pci-dss-program-practitioner]
---

> **TL;DR:** PCI DSS is not a paperwork exercise — it is a continuous control program that lives or dies on how aggressively you scope the cardholder data environment (CDE) and how honestly you operate the controls between assessments. This note is the practitioner playbook for security-team members standing up or rescuing a PCI program: merchant-level math, SAQ selection, scope reduction via tokenization and hosted payment pages, the PCI DSS 4.0 transition, Targeted Risk Analysis for the customised approach, the new 6.4.3 / 11.6.1 script-protection controls, QSA preparation, and the operational cadence that keeps you compliant on day 364. Companion to [[pci-dss-4-implementation]], [[pci-qsa-career-track]], [[secure-sdlc-rollout-playbook]], and [[soc2-vs-iso27001]].

## Why it matters

If your organization touches a Primary Account Number (PAN) — even briefly, even in a call recording, even on a paper form scanned to SharePoint — you are in PCI scope. The card brands (Visa, Mastercard, Amex, Discover, JCB) delegate enforcement to acquiring banks, who pass it down via merchant agreements. Non-compliance does not result in a friendly letter; it results in monthly fines from your acquirer (typically 5k–100k USD/month escalating), forensic investigator (PFI) bills after a breach, and in the worst case losing your ability to process card payments. For startups, that last one is existential.

The practitioner reality: most organizations treat PCI as an annual project led by a stressed compliance manager who chases evidence two weeks before the Qualified Security Assessor (QSA) shows up. That model fails PCI DSS 4.0 because the new requirements explicitly demand continuous evidence, documented Targeted Risk Analyses, and proof that controls operated all year. The shift from project to program is the single biggest change you need to drive.

## Scoping and the merchant level math

### Determining merchant level and SAQ

Merchant level is set by your acquirer based on annual Visa/Mastercard transaction volume:

- **Level 1**: >6M transactions/year (any single brand) or any merchant the brand designates after a breach. Requires annual Report on Compliance (RoC) by a QSA plus quarterly Approved Scanning Vendor (ASV) scans.
- **Level 2**: 1M–6M. Annual Self-Assessment Questionnaire (SAQ) plus ASV scans; some acquirers demand RoC.
- **Level 3**: 20k–1M (e-commerce only). SAQ + ASV.
- **Level 4**: <20k e-commerce or <1M total. SAQ; acquirer discretion on ASV.

Service providers have their own tiering (Level 1 = >300k transactions stored/processed/transmitted; Level 2 = everything else).

The SAQ type you can use depends on how cards enter your environment:

- **SAQ A**: fully outsourced e-commerce, redirect or iframe to PSP. ~22 questions in 4.0.
- **SAQ A-EP**: e-commerce where your server affects the payment page (e.g., a JavaScript-driven checkout that loads PSP fields). Massively more controls than SAQ A.
- **SAQ B / B-IP**: standalone dial-out / IP-connected payment terminals.
- **SAQ C / C-VT**: payment apps connected to internet / virtual terminals.
- **SAQ P2PE**: validated P2PE solution.
- **SAQ D**: everything else, including all service providers. ~300+ requirements. This is what you want to avoid.

Picking the right SAQ is the single highest-leverage decision. Engineering a redirect-based checkout to qualify for SAQ A instead of SAQ A-EP can save 6–12 months of effort.

### Scoping the CDE

The CDE is everything that stores, processes, or transmits cardholder data, plus everything connected to or that could impact the security of those systems. The PCI SSC's *Information Supplement: Guidance for PCI DSS Scoping and Network Segmentation* is the bible here.

Categories of systems:

1. **CDE systems** — touch CHD directly (payment app, HSM, tokenization vault, call-recording with PAN).
2. **Connected-to / security-impacting** — jump hosts, AD domain controllers authenticating CDE admins, monitoring systems collecting CDE logs, the HSM management station. Often missed and a top QSA finding.
3. **Out of scope** — fully segmented, no path in or out.

Walk every PAN flow end-to-end: customer browser → CDN → load balancer → web tier → payment service → PSP → settlement files → SFTP → finance system → BI warehouse. Sniff with tcpdump on representative segments to catch shadow flows. Interview customer service, finance, and ops — paper forms and call recordings are the classic forgotten flows.

### Aggressive scope reduction

Every system you remove from the CDE is one you do not need to harden, monitor, segment-test, log-review, and evidence quarterly. Tactics:

- **Tokenization** — replace stored PAN with tokens from a PSP vault. The token must not be reversible by your systems.
- **Hosted Payment Page (HPP) / redirect** — PAN never touches your servers. Qualifies you for SAQ A.
- **Iframe with PSP-served fields** — also SAQ A if implemented correctly (no script on your domain handling fields).
- **PSP / PayFac outsourcing** — Stripe, Adyen, Braintree, Worldpay handle the CDE.
- **P2PE-validated terminals** — encrypted at swipe, decrypted only at PSP. Removes the POS network from scope.
- **Network segmentation** — VLANs, firewalls, microsegmentation (Illumio, Guardicore) to isolate any residual CDE. Segmentation must be tested annually (every 6 months for service providers) per Requirement 11.4.5.

Document the residual flows in a Cardholder Data Flow Diagram (CDFD) and a network diagram showing CDE boundaries. These two diagrams will be the first thing the QSA asks for.

## PCI DSS 4.0: what changed and how to transition

The 3.2.1 retirement date was 31 March 2024. As of 31 March 2025, the previously "best practice" requirements became mandatory. Practitioner takeaways:

### Customised approach and Targeted Risk Analysis

4.0 introduces two ways to meet each requirement: the **defined approach** (do exactly what the standard says) and the **customised approach** (achieve the stated objective via your own controls, documented and validated by a QSA). The customised approach requires a **Targeted Risk Analysis (TRA)** for every requirement that allows it, plus separate TRAs for frequencies you set yourself (Req 12.3.1).

In practice: most organizations stay with the defined approach for 90%+ of requirements. The customised approach is genuinely useful for cloud-native controls that do not map neatly to the old language (e.g., serverless logging via CloudTrail + EventBridge instead of a traditional SIEM agent).

### New controls worth flagging

- **Req 3.5.1.2** — disk-level encryption alone is no longer sufficient for PAN on non-removable media. You need separate logical access controls or stronger crypto.
- **Req 5.4.1** — anti-phishing technical controls (DMARC enforcement; see [[dmarc-spf-dkim-deep]]).
- **Req 6.4.3** — payment page scripts must be inventoried, integrity-verified, and justified. Subresource Integrity (SRI) attributes on every external script, plus a documented list of authorized scripts.
- **Req 8.3.6** — passwords minimum 12 characters (was 7).
- **Req 8.4.2 / 8.5.1** — MFA on all access into the CDE (was admin-only) and all remote access.
- **Req 11.6.1** — change-and-tamper detection on payment pages. CSP reporting, monitoring tools (Source Defense, Jscrambler, Akamai Page Integrity Manager), or a homegrown DOM-diff against a known-good baseline.
- **Req 12.3.x** — formal Targeted Risk Analyses for every periodic activity.

### Gap analysis approach

Run a 3.2.1 → 4.0 delta workshop with the system owners for each in-scope system. For each new or changed requirement, mark Met / Partially Met / Not Met with evidence reference and owner. The output drives your remediation backlog and the project plan to the QSA visit.

## Defensive baseline for the residual CDE

Even after maximum scope reduction, the CDE you keep needs real security, not just a checked box:

- **Network**: ingress/egress filtering, segmentation tested twice yearly, no flat trust with corporate IT. Jump hosts with session recording.
- **Identity**: separate CDE admin accounts, phishing-resistant MFA (FIDO2 / WebAuthn — see [[conditional-access-bypass-modern]] for why TOTP is no longer enough), JIT elevation.
- **Logging**: every CDE system to a centralized SIEM with 1 year online + 1 year cold storage. Daily review, alerts on key events (Req 10.4). Tie this into your [[siem-detection-use-case-catalog]].
- **Vulnerability management**: internal + ASV external scans quarterly, all high/critical findings remediated. Annual pentest of CDE perimeter and segmentation; see [[pentest-proposal-and-scoping]].
- **Change management**: every CDE change ticketed, peer-reviewed, with rollback plan. Tie into your [[secure-sdlc-rollout-playbook]].
- **Script protection** (e-commerce): CSP with `script-src` allowlist + `report-uri`, SRI on all third-party scripts, monitoring tool for the payment page.

## Workflow to study and run the program

### Year zero: standing it up

1. **Week 1–2**: scoping workshop, CDFD, network diagram, asset inventory.
2. **Week 3–6**: scope reduction architectural changes (tokenization, HPP migration). This is where most time and money goes.
3. **Week 7–10**: gap analysis against 4.0, remediation backlog.
4. **Month 3–8**: remediation execution. Weekly stand-ups, monthly steering committee with the CFO (because budget).
5. **Month 9**: internal validation — run the SAQ or do a mock RoC against yourself. Fix what you find.
6. **Month 10–11**: QSA fieldwork (Level 1) or SAQ finalization.
7. **Month 12**: AoC signed, submitted to acquirer.

### Selecting a QSA

Not all QSAs are equal. Criteria:

- Experience with your stack (cloud-native, ISVs/SaaS, retail).
- Reasonableness on the customised approach — some QSACs refuse it entirely.
- Geographic coverage if you have multi-region CDE.
- Continuity — same lead assessor year over year saves enormous re-education time.
- Pricing — Level 1 RoC typically 60k–200k USD/year depending on complexity.

Get references and ask explicitly about how they handle disputed findings.

### Common QSA findings to pre-empt

- **Segmentation not properly tested** — running nmap from one VLAN to another is not enough. Document the methodology, source/destination matrix, and tester independence.
- **MFA gaps** — service accounts, break-glass accounts, vendor remote access often missed.
- **Logging gaps** — DNS query logs, cloud control-plane logs (see [[cloud-ir-aws-cloudtrail]]), database audit logs.
- **Vendor management** — missing AoCs from sub-service-providers, no shared-responsibility matrix.
- **Targeted Risk Analyses not documented** — a 4.0-specific finding now common.
- **Script inventory incomplete** — every analytics, A/B test, chatbot, and tag-manager script on the checkout page.

### Year one onward: program operation

Move from project to program by building a control calendar:

- **Daily**: log review (automated triage + human spot-check), failed-change rollback.
- **Weekly**: vulnerability scan triage, firewall rule reviews delta.
- **Monthly**: access review for CDE accounts, file integrity monitoring summary, evidence collection sweep into your GRC tool.
- **Quarterly**: ASV scans, internal scans, full access recertification, anti-malware sample tests, incident-response tabletop.
- **Semi-annually** (service providers): segmentation test.
- **Annually**: pentest, risk assessment, policy review, full SAQ/RoC, BCP test.

Automate ruthlessly. GRC platforms (Vanta, Drata, Secureframe, Hyperproof, AuditBoard) ingest evidence from AWS/Azure, Okta, Jira, GitHub, CrowdStrike, etc., and timestamp it. They do not replace a QSA but they cut the evidence collection time from weeks to hours.

## Realistic expectations

PCI is achievable for a small team if scope is small. A Level 4 e-commerce shop on Stripe Checkout can self-assess SAQ A in a few days. A Level 1 retail chain with terminals, e-commerce, call centers, and a loyalty program is a 2–4 FTE permanent program. Headcount lies if you skip ongoing work — you will pay it back in panic mode before the next assessment.

Compare costs and outcomes with [[soc2-vs-iso27001]] when scoping a multi-framework program; many controls overlap and a unified control library prevents duplicate work.

## Related

- [[pci-dss-4-implementation]]
- [[pci-qsa-career-track]]
- [[secure-sdlc-rollout-playbook]]
- [[soc2-vs-iso27001]]
- [[hipaa-security-rule]]
- [[nis2-implementation]]
- [[appsec-maturity-checklist]]
- [[dmarc-spf-dkim-deep]]
- [[conditional-access-bypass-modern]]
- [[siem-detection-use-case-catalog]]
- [[cloud-ir-aws-cloudtrail]]
- [[pentest-proposal-and-scoping]]

## References

- PCI SSC document library (DSS 4.0, SAQs, scoping supplement, TRA guidance): https://www.pcisecuritystandards.org/document_library/
- PCI DSS v4.0 Summary of Changes: https://docs-prv.pcisecuritystandards.org/PCI%20DSS/Standard/PCI-DSS-v3-2-1-to-v4-0-Summary-of-Changes-r2.pdf
- PCI SSC Information Supplement on Scoping and Network Segmentation: https://www.pcisecuritystandards.org/documents/Guidance-PCI-DSS-Scoping-and-Segmentation_v1_1.pdf
- Visa Global Registry of Service Providers: https://www.visa.com/splisting/
- OWASP guidance on payment page script integrity (CSP + SRI): https://owasp.org/www-project-secure-headers/
- Akamai / Jscrambler / Source Defense vendor write-ups on Req 6.4.3 and 11.6.1 implementation patterns: https://www.jscrambler.com/blog/pci-dss-v4-0-requirements-6-4-3-and-11-6-1
