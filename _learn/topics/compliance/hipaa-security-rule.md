---
title: HIPAA Security Rule — practitioner's view
slug: hipaa-security-rule
aliases: [hipaa, hipaa-security, phi-controls]
---

> **TL;DR:** HIPAA's Security Rule (45 CFR Part 164 Subpart C) governs how covered entities (US healthcare providers, plans, clearinghouses) and their business associates safeguard electronic protected health information (ePHI). Unlike PCI DSS, HIPAA is *risk-based and flexible* — controls are "addressable" or "required", with broad latitude on how. Breaches are reportable; HHS OCR enforces with seven-figure fines. Companion to [[pci-dss-4-implementation]] and [[gdpr-incident-implications]].

## Why HIPAA matters

- **US healthcare data** is one of the most heavily regulated data classes.
- **Severe penalties** — $1M+ per violation tier; OCR settles many.
- **Operational reality**: most enforcement is reactive (after breach) but proactive audits do occur.
- **Business Associates** — vendors who touch PHI inherit obligations via the Business Associate Agreement (BAA).

## Scope

The Security Rule applies to **electronic PHI** specifically — paper PHI is the Privacy Rule (45 CFR Part 164 Subpart E).

Three categories of safeguards:
- **Administrative** — policies, training, contingency planning.
- **Physical** — facility access, workstation security, device controls.
- **Technical** — access control, audit controls, integrity, transmission security.

## The "required" vs "addressable" distinction

- **Required** — must be implemented.
- **Addressable** — must be implemented unless not reasonable and appropriate for the entity, with documentation of alternatives.

"Addressable" is **not optional**. It means flexibility, not exemption.

## Key technical requirements

### Access Control (164.312(a))

- **Unique user identification** — required.
- **Emergency access procedure** — required.
- **Automatic logoff** — addressable.
- **Encryption / decryption** — addressable.

Modern interpretation: SSO with MFA, session timeouts, JIT access, encryption at rest and in transit. All standard practice.

### Audit Controls (164.312(b))

- Record and examine activity in systems containing ePHI.

Practitioner: centralised logging, SIEM, retention sufficient to support breach investigation (typically 6 years to match HIPAA records retention).

### Integrity (164.312(c))

- Protect ePHI from improper alteration / destruction.

Implementations: file-integrity monitoring, write-restricted storage tiers, immutable backups.

### Person or Entity Authentication (164.312(d))

- Verify person / entity seeking access.

Modern: MFA. Phishing-resistant for clinical / administrative access.

### Transmission Security (164.312(e))

- **Integrity controls** — addressable.
- **Encryption** — addressable.

Modern interpretation: TLS 1.2+. End-to-end encryption for patient-facing portals.

## Administrative requirements highlights

### Risk Analysis (164.308(a)(1))

The **most important administrative requirement**. Conduct an accurate and thorough assessment of risks to ePHI confidentiality, integrity, and availability.

Practitioner reality: comprehensive risk analyses are rare. OCR enforcement often hinges on whether this exists.

### Security Management Process

Implement security measures sufficient to reduce risks to a reasonable and appropriate level.

### Workforce Security

Authorization / access termination procedures.

### Contingency Plan

Data backup, disaster recovery, emergency-mode operations.

### Business Associate Agreement (BAA)

Vendors with PHI access sign a BAA committing to HIPAA controls. Without a BAA, sharing PHI with the vendor is a HIPAA violation.

Cloud providers (AWS, Azure, GCP) sign BAAs for specific services. Outside those services, PHI is not allowed.

## Breach notification

Under the Breach Notification Rule:
- **Within 60 days** of discovery, notify affected individuals.
- **HHS OCR notification**: same 60 days if >500 affected; annual if <500.
- **Media notification** for >500 in a state.
- **Documentation** of the breach analysis.

Encryption per NIST 800-111 (at rest) and 800-52 (transit) is a **safe harbour** — encrypted lost data may not require breach notification.

## Common practitioner mistakes

- **No risk analysis** — most common OCR finding.
- **BAA gaps** — using cloud services for PHI not covered by BAA (e.g., consumer Gmail, non-BAA Slack).
- **Inadequate access termination** — terminated employees retaining access.
- **No encryption** of laptops / mobile devices — lost device = reportable breach.
- **Inadequate audit log retention** — can't investigate when needed.
- **Texting PHI** without secure messaging.

## Mapping to technical controls

Most HIPAA controls have direct technical implementations:
- Identity / access — SSO + MFA + IAM ([[conditional-access-bypass-modern]]).
- Encryption — TLS / disk / database (at rest + in transit).
- Logging — SIEM with appropriate retention.
- Backup — encrypted off-site, tested restore.
- Incident response — defined runbooks ([[ir-from-source-signals]]).
- Vulnerability management — periodic scans + patch SLA.
- Pen testing — required by some interpretations.

## HIPAA-specific challenges

- **PHI in unstructured data** — emails, attachments, free-text notes.
- **Clinician workflow vs security** — locked-out clinicians can be life-safety issue. UX matters.
- **Medical devices** — IoMT devices with poor security; vendor accountability.
- **Research data** — de-identified per Safe Harbor or Expert Determination, then less restricted.
- **State laws** stricter than HIPAA in some states (CA SB-466, NY SHIELD).

## Real-world enforcement

- Multiple OCR settlements for failure to conduct risk analysis ($1M–$5M).
- 23andMe 2023 breach — credential-stuffing → millions of profiles → consequential enforcement.
- Anthem 2015 — $115M settlement.
- Ransomware reporting now explicit (HHS 2022 guidance): ransomware on ePHI is a presumed breach.

## Workflow to start

1. **Determine if you're a covered entity** or business associate.
2. **Inventory ePHI** — where is it stored, transmitted, processed.
3. **Risk analysis** — comprehensive, documented.
4. **Gap analysis** — current controls vs required.
5. **BAA review** for every vendor.
6. **Incident-response runbook** specifically for PHI breach.
7. **Encryption everywhere** for ePHI.

## Mapping to other regimes

HIPAA overlaps with:
- **HITRUST CSF** — healthcare-industry control framework mapping to HIPAA.
- **NIST 800-66r2** — HIPAA implementation guide.
- **SOC 2** — addresses many HIPAA technical safeguards.
- **GDPR** if EU citizens' health data.

## Workflow to study

1. Read 45 CFR Part 164 Subpart C.
2. Read NIST 800-66 r2 — practical HIPAA guide.
3. Read HHS OCR audit protocols.
4. Walk a small EHR setup; map controls to requirements.

## Related

- [[pci-dss-4-implementation]] — adjacent regime.
- [[gdpr-incident-implications]] — adjacent regime.
- [[nis2-implementation]] — adjacent regime.
- [[soc2-vs-iso27001]].
- [[appsec-maturity-checklist]].
- [[ir-from-source-signals]].

## References
- [HHS OCR — Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)
- [NIST 800-66 r2](https://csrc.nist.gov/pubs/sp/800/66/r2/final)
- [HHS OCR enforcement actions](https://www.hhs.gov/hipaa/for-professionals/compliance-enforcement/agreements/)
- [HITRUST CSF](https://hitrustalliance.net/)
- See also: [[pci-dss-4-implementation]], [[soc2-vs-iso27001]], [[gdpr-incident-implications]], [[appsec-maturity-checklist]], [[hitrust-csf-implementation]], [[iso-27701-privacy-extension]]
