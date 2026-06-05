---
title: GDPR — incident-response implications
slug: gdpr-incident-implications
aliases: [gdpr-ir, gdpr-72-hour, gdpr-breach-notification]
---

> **TL;DR:** GDPR Article 33 requires notifying the supervisory authority of a personal-data breach within **72 hours** of becoming aware (with limited exceptions). Article 34 requires notifying affected data subjects if the breach is likely to result in high risk. The trigger ("becoming aware") and the threshold ("high risk") matter operationally. Fines for the breach itself can reach €20M or 4% of global turnover; for notification failure, €10M or 2%. Companion to [[nis2-implementation]] and [[case-study-equifax-2017]].

## Why this note is operational, not legal

GDPR is a privacy regulation, not a security regulation. But IR teams handle the consequences of personal-data breaches — the 72-hour timeline is owned by the IR team in practice. This note covers the operational implications.

## "Becoming aware"

The 72-hour clock starts when the controller "becomes aware" of the breach. EDPB guidance: when the controller has **reasonable degree of certainty** that a security incident has led to personal data being compromised.

Operational implication:
- Don't game the clock — courts have looked at investigation diligence.
- Document the moment of awareness explicitly.
- The investigation can continue beyond 72 hours; initial notification is what's due.

## What counts as a personal-data breach

Article 4(12): "a breach of security leading to the accidental or unlawful destruction, loss, alteration, unauthorised disclosure of, or access to, personal data."

Includes:
- **Confidentiality** breach — data exposed.
- **Integrity** breach — data altered.
- **Availability** breach — data lost without recovery.

Availability breach (e.g., ransomware encrypting backups without exfil) **still counts**.

## What to include in the notification

Article 33(3):
- Nature of the breach.
- Categories and approximate number of data subjects.
- Categories and approximate number of records.
- Likely consequences.
- Measures taken or proposed.
- Contact for the Data Protection Officer (DPO).

Initial notification can be incomplete; provide further information in phases.

## When to notify data subjects (Article 34)

If the breach is **likely to result in high risk** to rights and freedoms. Factors:
- Type of data (special categories: health, biometric, racial — higher risk).
- Volume.
- Identifiability of the data subjects.
- Severity of consequences.

Exception: if encryption rendered the data unintelligible, notification may not be required. Encryption is the **safe harbour**.

## Practitioner runbook

### Hour 0 — detection

- Triage alert → incident.
- Engage IR team.
- Preserve evidence.
- Start the 72-hour clock when "awareness" criteria met.

### Hour 0–24

- Scope assessment: what data, how many subjects, what jurisdictions.
- Initial vendor / partner notifications if their data is involved.
- DPO + Privacy office engaged.

### Hour 24–72

- Draft notification to supervisory authority.
- Identify lead supervisory authority (one-stop-shop for cross-border processing).
- Submit Article 33 notification.

### Hour 72+

- Continue investigation; provide updates to supervisory authority.
- Decide on Article 34 notification to data subjects.
- Coordinate communications.

### Post-incident

- Document the breach for the Article 33(5) breach register (internal records of all breaches, including those not reported).
- Lessons-learned review.

## Lead Supervisory Authority

For organisations operating across multiple EU member states, identify the "main establishment" and its supervisory authority. That authority is the lead for cross-border issues.

Cross-jurisdictional cases create coordination overhead. Some recent fines have come from disputes between supervisory authorities.

## Common practitioner mistakes

- **Late notification due to "we want more details"** — file the initial notification, provide details later.
- **Encrypted-data assumption** — assuming encryption = no notification. Verify the encryption was at-rest and the key wasn't also compromised.
- **Volume undercount** — initial estimate too low; later revision drives further bad press.
- **Wrong supervisory authority** — notifying local instead of lead authority.
- **Failure to maintain breach register** — internal record-keeping omitted.
- **Confused about who's controller / processor** — if you're a processor, you must notify the controller without undue delay; the controller handles the supervisory authority.

## Coordination with other reporting regimes

A single incident may trigger multiple reports:
- GDPR — 72 hours, supervisory authority.
- **NIS2** ([[nis2-implementation]]) — 24/72/30, competent authority.
- **DORA** for financial — separate.
- **Sector-specific** — health, finance, telecom.
- **State-by-state breach laws** in non-EU jurisdictions.
- **Contractual** — customer / partner SLAs.
- **Regulatory disclosure** — SEC (US public companies, 8-K within 4 business days of materiality determination).
- **Stock-market** disclosure.

A single matrix of reporting obligations should exist before any incident.

## What goes wrong post-incident

- **Under-disclosure** triggers larger fine later.
- **Over-disclosure** invites class actions.
- **Delayed customer notification** — customers learn from the supervisory authority's website. Reputational damage.
- **PR-led timeline** — sometimes legal / PR pushes back on IT timeline. IT must hold the line on factual statements.

## Encryption as safe harbour

If the encrypted data is genuinely unintelligible to the attacker, Article 34 notification to subjects may not be required.

Operational criteria:
- AES-256 or equivalent.
- Key not also exposed.
- Key in independently-protected store (HSM, KMS with access controls).
- Documented as such.

Many "encrypted" claims fail on closer inspection. Don't rely on this without auditor confirmation.

## Recent enforcement

- Multiple eight-figure fines for inadequate security or late notification.
- DPA enforcement is increasing post-Schrems II.
- Specific patterns: late notification, inadequate response, weak underlying controls.

## Workflow to study

1. Read Articles 33 and 34 of GDPR.
2. Read EDPB Guidelines on personal data breach notification (Guidelines 9/2022).
3. Build a tabletop exercise simulating a 72-hour reporting cycle.
4. Map your sectors' overlapping reporting obligations into one matrix.

## Related

- [[nis2-implementation]] — overlapping regime.
- [[pci-dss-4-implementation]] — adjacent.
- [[hipaa-security-rule]] — adjacent.
- [[soc2-vs-iso27001]].
- [[case-study-equifax-2017]] — adjacent late-notification class.
- [[case-study-okta-2023-support-system]] — adjacent disclosure-revision class.
- [[ir-from-source-signals]] — IR mechanics.

## References
- [GDPR text (2016/679)](https://eur-lex.europa.eu/eli/reg/2016/679/oj)
- [EDPB — Guidelines on personal data breach notification (Guidelines 9/2022)](https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-92022-personal-data-breach-notification-under-gdpr_en)
- [National DPA list](https://edpb.europa.eu/about-edpb/about-edpb/members_en)
- See also: [[nis2-implementation]], [[pci-dss-4-implementation]], [[hipaa-security-rule]], [[ir-from-source-signals]]
