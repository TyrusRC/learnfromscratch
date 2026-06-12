---
title: PCI DSS SAQ selection and scoping
slug: pci-saq-selection-and-scoping
---

> **TL;DR:** PCI DSS Self-Assessment Questionnaires (SAQ) are simplified compliance paths for merchants and service providers not undergoing full Report on Compliance (ROC) assessment. Eight SAQ types; choice determined by HOW you handle cardholder data, not transaction volume alone. Wrong SAQ selection = non-compliance even if completed.

## What it is
PCI DSS compliance reporting follows volume- + handling-based tiers:
- **Level 1 merchants** (>6M Visa/MC tx/yr, or post-breach) — full ROC via QSA
- **Level 2-4 merchants** — typically SAQ based on handling profile
- **Service providers** — Level 1 (>300K tx/yr stored/processed/transmitted) need ROC; smaller use SAQ-D for service providers

SAQ types pre-filter PCI DSS requirements to only those relevant to a specific scope. A SAQ A merchant answers ~25 questions; SAQ D answers all 300+ requirements.

## SAQ types (PCI DSS 4.0)

| SAQ | Eligibility |
|---|---|
| **A** | Card-not-present merchants; ALL CHD functions fully outsourced to PCI DSS validated third party |
| **A-EP** | E-commerce merchants whose website doesn't receive CHD but controls how customers are directed to third-party payment site |
| **B** | Merchants using imprint machines OR standalone, dial-out terminals (no electronic CHD storage) |
| **B-IP** | Merchants using standalone PTS-approved POI devices connected via IP to processor (no CHD storage) |
| **C-VT** | Merchants using only web-based virtual terminals (no CHD storage on premises) |
| **C** | Merchants with payment application systems connected to the internet; no CHD storage |
| **P2PE** | Merchants using only PCI SSC validated P2PE solution; no other CHD access |
| **D for merchants** | All other SAQ-eligible merchants |
| **D for service providers** | Service providers eligible to complete SAQ instead of ROC |

PCI DSS 4.0 retains the same SAQ types as 3.2.1 with minor updates.

## Tradecraft — picking the right SAQ

**Step 1 — Map all CHD touchpoints.** Even if you "outsource payments", check:
- Where is the cardholder data ENTERED? (your site, third-party hosted form, iframe, redirect)
- Where is it PROCESSED, TRANSMITTED, STORED?
- Do you receive a token, the PAN, or nothing?
- Are there backup paths (call centre, mailorder, in-person)?

**Step 2 — Walk the decision tree.**

```
Is there ANY CHD on your systems / network ever?
├── No → e-commerce only?
│   ├── Yes → fully outsourced payment page (no iframe code on your domain)?
│   │   ├── Yes → SAQ A
│   │   └── No → SAQ A-EP
│   └── No → only standalone IP terminals?
│       ├── Yes → SAQ B-IP
│       └── Web-based virtual terminal only → SAQ C-VT
│       └── Dial-out terminals only → SAQ B
└── Yes → only via P2PE validated solution?
    ├── Yes → SAQ P2PE
    └── No → CHD on your network → SAQ C or SAQ D
```

**Step 3 — Match the SAQ assumptions.** Each SAQ has "Eligibility Criteria" page; entity must affirm ALL apply. One mismatch = ineligible for that SAQ → step up.

**Step 4 — Get acquirer sign-off.** Merchant acquirers determine reporting requirements per agreement. Some require SAQ D from all merchants regardless of eligibility. Always confirm with your acquirer.

## SAQ A — the most common but easy to misuse

SAQ A is for merchants whose entire CHD function is outsourced. Common misuses:
- **iframe / redirect on your domain** — if the payment iframe is hosted on your domain, you're SAQ A-EP, not SAQ A
- **JavaScript on the page that touches form fields** — even custom UI on third-party hosted page can shift you to A-EP
- **Stored "card on file" via tokenisation** — depends on token vault: if vault is third-party, SAQ A may apply; if vault is yours, SAQ D
- **PCI DSS 4.0 new requirement 6.4.3** — added requirement for SAQ A merchants to inventory all scripts loaded on the payment page (Magecart mitigation, effective March 2025)

The Magecart / web-skimming threat changed regulatory thinking; 4.0 makes SAQ A merchants more accountable for client-side payment page security than 3.2.1 did.

## SAQ A-EP — the in-between

E-commerce with no CHD touch on your servers BUT your site controls the user experience (redirect URL, iframe parameters, transaction direction). About 50 questions; covers application security, change management, vulnerability scanning, pen testing.

Most modern e-commerce platforms (Shopify, WooCommerce + Stripe, Square Online) lean towards SAQ A-EP because the storefront still has script involvement in payment.

## Scoping — the underlying skill

SAQ eligibility hinges on accurate scope determination. Scope = "all components that store, process, transmit cardholder data, or could impact the security of CHD". Scope reduction strategies:

- **Tokenisation** — replace PAN with non-sensitive token; vault out of scope (if tokenisation is third-party)
- **Hosted payment pages / fully outsourced flow** — CHD never touches your environment
- **P2PE** — encrypted at POI, decrypted only at processor; cardholder data never appears in cleartext in your environment
- **Network segmentation** — segment CDE (Cardholder Data Environment) from rest of corporate network with strong controls; segmentation testing required annually for high-risk

Improper scoping → "I thought we were SAQ A but the auditor found CHD logs in our application logs". Hidden CHD locations:
- Application logs / debug logs
- Database backups
- Email attachments (customer screenshots of cards)
- Call recordings (customer reads card on phone)
- Chat transcripts
- Memory dumps from debugger sessions
- Screen-sharing recording

## Defending segmentation

PCI DSS 4.0 requires (Requirement 11.4.5 / 11.4.6) segmentation effectiveness testing:
- **Merchants** — at least annually
- **Service providers** — at least every six months

Segmentation tests verify CDE isolation: simulated attacker on out-of-scope network attempts to reach in-scope systems. If reachable, segmentation isn't effective and scope must expand.

## Common implementation pitfalls

- **SAQ D selection without acquirer approval** — SAQ D is broad; entity can downgrade to easier SAQ if eligibility met (acquirer-permission required)
- **SAQ A on a site with payment iframe code on your domain** — 6.4.3 requires script inventory; many SAQ A merchants will be surprised by this 4.0 change
- **Reusing prior year's SAQ** — answers may have aged out; re-walk eligibility every year
- **Unclear service provider scope** — payment gateway, tokenisation vault, PCI-validated cloud provider may each have different applicability
- **CHD found in unexpected places post-incident** — discovery during DFIR shifts retroactive scope

## Annual cadence

PCI DSS is point-in-time compliance reaffirmed annually:
- Re-confirm SAQ eligibility every year
- Pass quarterly ASV scans (external) — clean scan for each quarter required (4 per year)
- Perform internal vulnerability scans + remediation
- Penetration test (requirement 11.4.x) annually + after significant change
- Annual employee security awareness training
- Annual security policy review
- Risk assessment refresh (4.0 requires Targeted Risk Analyses per requirement)

## OPSEC for compliance team

- SAQ + Attestation of Compliance (AoC) is submitted to acquirer; treat as confidential
- AoC may be requested by customers (B2B service providers); have a sanitised version ready
- ASV scan reports contain network info; restrict access
- Retain SAQ + AoC + supporting evidence for at least 3 years (PCI SSC requirement)

## References
- [PCI DSS Self-Assessment Questionnaires](https://www.pcisecuritystandards.org/document_library/?category=saqs)
- [PCI DSS v4.0 Standard](https://www.pcisecuritystandards.org/)
- [PCI DSS Quick Reference Guide v4.0](https://www.pcisecuritystandards.org/document_library)
- [PCI SSC Scope and Segmentation Information Supplement](https://www.pcisecuritystandards.org/)
- [Visa Acquirer Risk Profile guide](https://usa.visa.com/) — merchant-level mapping by brand

See also: [[building-a-pci-dss-program-practitioner]], [[pci-dss-4-implementation]], [[pci-dss-4-customised-approach]], [[pci-cardholder-data-flow-mapping]], [[pci-3ds-and-p2pe-overlays]], [[pci-qsa-career-track]], [[vulnerability-management-lifecycle]], [[patch-management-program]], [[appsec-maturity-checklist]]
