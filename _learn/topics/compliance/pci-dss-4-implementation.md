---
title: PCI DSS 4.0 — practitioner's view
slug: pci-dss-4-implementation
aliases: [pci-dss-4, pci-dss-implementation]
---

> **TL;DR:** PCI DSS 4.0 (replacing 3.2.1 over a 2024–2025 transition) governs how organisations handle cardholder data. Twelve top-level requirements, ~400 sub-requirements. As a practitioner, the things that change posture from 3.2.1 are: customised approach (risk-based control selection), MFA on all access into the cardholder data environment (CDE), targeted risk analyses (TRAs), and several new control families around client-side script protection (e.g., 6.4.3 / 11.6.1 against Magecart). Companion to [[appsec-maturity-checklist]] and [[soc2-vs-iso27001]].

## Why PCI DSS matters

- **Card-acceptance gating** — non-compliance means inability to process cards.
- **Liability shift** in case of breach.
- **Influences architecture** more than most compliance regimes — segmentation, encryption, MFA, logging.
- Often a **first-touch compliance regime** for engineers.

## Scope: the CDE

PCI applies to **the cardholder data environment** — systems that process, transmit, or store cardholder data (PAN, CVV, magnetic stripe). Plus connected systems.

The single biggest cost-saving move is **scope reduction**: tokenize early, isolate the CDE behind segmentation, contractually outsource (PSP / Stripe / Adyen) where possible.

## The 12 requirements (compressed)

1. Install and maintain a firewall configuration (network controls).
2. Do not use vendor-supplied defaults (hardened systems).
3. Protect stored cardholder data (encryption, key management).
4. Encrypt transmission of cardholder data (TLS, etc.).
5. Use and regularly update anti-malware software.
6. Develop and maintain secure systems (secure SDLC, patching).
7. Restrict access to cardholder data on need-to-know.
8. Identify and authenticate access (MFA, password policy).
9. Restrict physical access to cardholder data (datacenters, paper).
10. Track and monitor access (logging, monitoring).
11. Regularly test security (vulnerability scans, pen tests).
12. Maintain an information security policy.

Each has dozens of sub-controls.

## What's new in 4.0

### Customised approach

Two paths now: **defined approach** (follow the requirement literally) or **customised approach** (alternative control achieving the requirement objective, validated via a Targeted Risk Analysis).

Practitioner: customised approach allows modern, novel controls (e.g., cloud-native zero-trust). Requires more documentation. Many organisations stay defined except where it's painful.

### MFA on the CDE

4.0 expands MFA: every access into the CDE (not just admin) plus all individual users — including system / service accounts where feasible. Phish-resistant MFA (FIDO2) preferred.

### Client-side script protection (Magecart)

Requirements 6.4.3 and 11.6.1 added in 4.0. Driven by the Magecart wave of e-commerce script-injection attacks (British Airways breach 2018+).

6.4.3: maintain an inventory of payment-page scripts; authorise each; assure integrity.
11.6.1: detect unauthorised changes to payment-page HTTP headers and contents.

Technical implementations: CSP, SRI (Subresource Integrity), client-side script-integrity monitoring services.

### Targeted Risk Analysis (TRA)

For several controls (e.g., scanning frequencies, patch cadences), 4.0 lets you set frequency *justifiably* via TRA. Document what risks you considered, why your chosen frequency mitigates them.

### Phishing-resistant authentication for administrative roles

Driven by AitM attack landscape ([[aitm-evilginx-modern-phishing]]).

### Encryption modernisation

Stronger keys, key rotation, secure key management.

## Practitioner mapping

For a typical web e-commerce / SaaS:

- **Requirement 3 (storage)** — tokenize via PSP; minimise stored PAN to nothing where possible.
- **Requirement 4 (transit)** — TLS 1.2 minimum, 1.3 preferred. No legacy TLS.
- **Requirement 6 (secure SDLC)** — see [[secure-sdlc-rollout-playbook]]. SAST / DAST / SCA in pipeline.
- **Requirement 8 (auth)** — MFA via SSO ([[conditional-access-bypass-modern]] context).
- **Requirement 10 (logging)** — centralised log retention 1 year; immediate availability 3 months.
- **Requirement 11 (testing)** — annual pentest of CDE + segmentation testing; quarterly internal/external scans.
- **Requirement 11.6.1 (client-side)** — CSP, SRI, monitoring on payment pages.

## Common practitioner mistakes

- **Scope creep** — treating systems "near" the CDE as in-scope when they're not. Costs.
- **Scope omission** — ignoring connected systems that touch CDE indirectly. Audit risk.
- **Vendor compliance assumption** — assuming Stripe / PSP "makes you compliant". You still have your own controls.
- **Manual compliance theater** — quarterly hand-maintained Excel control matrices. Automate.
- **Patch SLA missed** — Requirement 6 patch timelines (~30 days for critical) routinely missed.
- **Pentest scope mismatch** — pentest report doesn't cover the actual CDE.

## Mapping to other frameworks

PCI DSS 4 controls largely overlap:
- **SOC 2 CC controls** — see [[soc2-vs-iso27001]].
- **ISO 27001 Annex A** — many direct mappings.
- **NIST CSF 2.0** functions.

Most organisations build one control framework and map to multiple compliance regimes.

## Workflow to start

1. **Determine merchant level** (Level 1–4 based on transaction volume) — drives audit requirements.
2. **Self-Assessment Questionnaire (SAQ)** type for your scope.
3. **Engage a QSA** (Qualified Security Assessor) for L1.
4. **Build the control evidence package** with automation where possible.

## Real-world incidents driven by PCI gaps

- **Target 2013** — third-party HVAC vendor → network → CDE. Driven Requirement 8 / 9 / vendor risk evolution.
- **British Airways 2018 (Magecart)** — driven Req 11.6.
- **Equifax 2017** ([[case-study-equifax-2017]]) — patch / scope failure analogue.

## Workflow to study

1. Read the PCI DSS 4.0 specification (publicly available).
2. Read the Prioritised Approach (also public).
3. Apply Req 11.6 to a test e-commerce page — implement CSP + SRI.
4. Practice writing a Targeted Risk Analysis for one control.

## Related

- [[appsec-maturity-checklist]] — programmatic baseline.
- [[secure-sdlc-rollout-playbook]] — Req 6 implementation.
- [[hipaa-security-rule]] — adjacent regime.
- [[nis2-implementation]] — adjacent EU regime.
- [[soc2-vs-iso27001]].
- [[case-study-equifax-2017]] — adjacent class.

## References
- [PCI Security Standards Council](https://www.pcisecuritystandards.org/)
- [PCI DSS 4.0 standard](https://www.pcisecuritystandards.org/document_library/?category=pcidss)
- [PCI Prioritised Approach](https://www.pcisecuritystandards.org/document_library/?category=pcidss&document=pci_dss_prioritized_approach)
- [QSA registry](https://www.pcisecuritystandards.org/assessors_and_solutions/qualified_security_assessors)
- See also: [[appsec-maturity-checklist]], [[secure-sdlc-rollout-playbook]], [[hipaa-security-rule]], [[soc2-vs-iso27001]], [[pci-dss-4-customised-approach]], [[pci-saq-selection-and-scoping]], [[pci-cardholder-data-flow-mapping]], [[pci-3ds-and-p2pe-overlays]]
