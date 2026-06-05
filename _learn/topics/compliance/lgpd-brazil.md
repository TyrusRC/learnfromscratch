---
title: LGPD — Brazil General Data Protection Law
slug: lgpd-brazil
aliases: [brazil-lgpd, br-privacy]
---

> **TL;DR:** Brazil's Lei Geral de Proteção de Dados (LGPD, Law 13.709/2018, in force since Sept 2020) is heavily modeled on GDPR — same legal-basis structure, same data-subject rights, mandatory DPO ("Encarregado"), and an independent regulator (ANPD) that finally got teeth in 2023. The big practitioner differences from [[gdpr-incident-implications]]: breach-notification is "reasonable time" (not 72 hours), fines cap at 2% of Brazil revenue / R$50M per infraction (not 4% global), and BACEN/CVM sectoral rules stack on top for finance. Companion notes: [[pdpa-singapore]], [[appi-japan]], [[dpdp-india]].

## Why it matters

If you run security for any company touching Brazilian residents' data — a SaaS product, a payments processor, an HR system, a marketing list — LGPD applies regardless of where your servers live, same extraterritorial logic as GDPR Art. 3. Brazil is the largest data-economy in Latin America (~215M people, mature fintech and e-commerce sectors), so "we'll just block BR traffic" is rarely viable.

For security teams specifically:

- **Breach notification is on you to operationalize.** The law says "reasonable time" — ANPD's 2023 guidance points to 3 business days as the working ceiling. Engineering an IR process that decides, escalates, and notifies in 3 days is the same problem as [[gdpr-incident-implications]], just with looser wording you should not rely on.
- **DPO ("Encarregado") is mandatory** for most controllers. Your DPO will be the person filing breach reports, answering ANPD inquiries, and triaging data-subject requests — they need to be plugged into IR, not parked in legal.
- **Sectoral overlay matters.** Banks answer to BACEN (Resolution 4.893 on cyber, plus open-banking rules); securities firms answer to CVM; health data has additional ANPD-specific guidance. Multiple regulators may inquire about the same incident.
- **Penalties became real in 2023.** ANPD published the dosimetry regulation (Resolution CD/ANPD 4/2023) and started issuing administrative sanctions. Telefônica Brasil was fined in 2023. The era of "LGPD is a paper tiger" ended.

LGPD is also a useful template for the rest of LatAm — Argentina, Chile, Colombia, and Mexico are all heading toward GDPR-style frameworks, and Brazil's case law is leading.

## Structure of the law

### Scope and territorial reach

LGPD Art. 3 applies when:

1. Processing is carried out in Brazilian territory, **or**
2. The processing aims to offer goods/services to individuals in Brazil, **or**
3. The personal data was collected in Brazil (regardless of where processed).

The "offer of goods/services" prong is the extraterritorial hook — same logic as GDPR. There is no "establishment" requirement. If you sell to BR customers from Singapore, LGPD applies to that processing.

### Legal bases (Art. 7 and Art. 11)

Ten legal bases for general personal data — broader than GDPR's six:

1. Consent
2. Compliance with legal/regulatory obligation
3. Public administration execution
4. Studies by research bodies (anonymized where possible)
5. Contract performance / pre-contractual procedures
6. Regular exercise of rights in judicial/administrative/arbitral proceedings
7. Protection of life or physical safety
8. Health protection (by health professionals/authorities)
9. **Legitimate interests** of the controller or third party
10. Credit protection

For sensitive data (Art. 11 — racial origin, religion, political opinions, health, sex life, genetic/biometric data), the list narrows and consent must be specific and highlighted.

Practitioner takeaway: like GDPR, "we got consent" is the worst legal basis if any other applies — it can be withdrawn at any time. Contract-performance and legitimate-interest are usually cleaner for ongoing service operations.

### Data-subject rights (Art. 18)

Mirrors GDPR closely:

- Confirmation of processing
- Access
- Correction of incomplete/inaccurate data
- Anonymization, blocking, or deletion of unnecessary or unlawfully processed data
- Portability to another provider
- Deletion of data processed with consent
- Information about public/private entities the controller shared data with
- Information about the option not to give consent and consequences
- Revocation of consent
- Review of automated decisions (Art. 20 — narrower than GDPR Art. 22; ANPD has interpreted this aggressively for credit-scoring)

Response window: 15 days for confirmation/access, "reasonable time" for others. Build the DSAR pipeline to match what you already have for GDPR.

### DPO ("Encarregado") — Art. 41

Mandatory for most controllers. Must be publicly identified (name and contact on the website), accept complaints, communicate with ANPD, and train staff. Can be internal or outsourced. ANPD Resolution CD/ANPD 2/2022 carved out small-business exemptions but most regulated entities still need one.

From a security POV: the DPO needs a direct line to the IR commander. If you keep them in a legal silo they will not know about incidents until the news breaks.

## Breach notification — the "reasonable time" trap

LGPD Art. 48 says the controller must notify ANPD and affected subjects "in a reasonable time" after becoming aware of a security incident that may pose "relevant risk or damage."

What "reasonable time" means in practice:

- ANPD's initial guidance (2022) suggested **2 business days**.
- The September 2024 Breach Notification Regulation (Resolution CD/ANPD 15/2024) settled on **3 business days** from becoming aware of the incident.
- Notifications go through ANPD's online form. Required fields include: incident description, data categories and volume affected, when it occurred, when it was detected, technical/security measures used, risks, and mitigation measures.

What "relevant risk" means: ANPD has signaled that risk to data subjects' rights/freedoms is the threshold — same Art. 33/34 GDPR mental model. Internal-only encrypted data with no exfiltration evidence may not require notification; loss of CPF + financial data almost certainly does.

The trap: "reasonable time" sounds permissive but ANPD is willing to treat slow notification as an aggravating factor in penalty dosimetry. Do not plan for the ceiling.

### CPF as the universal identifier risk

Brazil's CPF (Cadastro de Pessoas Físicas) is used as a primary identifier across banks, telecom, e-commerce, and government. Breaches involving CPF + DOB + name are routine and almost always trigger notification. The 2021 Serasa breach (~220M CPFs) and 2024 Telefônica Vivo incidents shaped the regulator's expectations.

## Penalty regime

Art. 52 sanctions:

1. Warning (with corrective deadline)
2. Simple fine — up to **2% of the company group's Brazil revenue** for the prior year, capped at **R$50,000,000 per infraction** (~US$10M at 2026 rates)
3. Daily fine (subject to same cap)
4. Publication of the violation
5. Blocking of the personal data until regularization
6. Deletion of the personal data
7. Partial suspension of the database operation (up to 6 months, extendable)
8. Suspension of processing activity (up to 6 months, extendable)
9. Partial or total prohibition of activities related to data processing

The dosimetry regulation (CD/ANPD 4/2023) sets the calculation. Base fines scale by infraction class (minor / medium / severe) and aggravating/mitigating factors include: cooperation, prior compliance program, repeat offenses, adoption of internal codes of conduct, and good-faith breach handling. Practically: a documented IR program and timely notification reduce exposure materially.

## Sanctions ramp 2021-2023

A useful timeline for incident-response planning context:

- **August 2020** — LGPD enters force; sanctions provisions delayed.
- **August 2021** — Sanctions provisions enter force; ANPD still standing up.
- **2022** — ANPD publishes regulations on small-business treatment, DPO, oversight procedures.
- **February 2023** — Dosimetry regulation (CD/ANPD 4/2023) issued, allowing actual fine calculation.
- **July 2023** — First substantive fine: Telefônica Brasil, R$1.4M (telemarketing-related). Small in absolute terms but signaled enforcement was operational.
- **2024-2025** — Multiple fines and consent-decrees, breach-notification regulation finalized.

Treat 2023 as the inflection point. Pre-2023 ANPD activity is not a useful baseline.

## Sectoral overlay

LGPD does not displace sector-specific rules. Stack the obligations:

- **BACEN (Central Bank)** — Resolution 4.893/2021 on cyber policy and contracting of cloud services; Resolution 85/2021 on incident reporting; Open Finance rules (Joint Resolutions 1/2020 onwards). Banks notify BACEN **and** ANPD on relevant incidents.
- **CVM (Securities Commission)** — material-fact disclosure rules can trigger market disclosure for listed companies; CVM Resolution 35/2021 on cyber for fund administrators.
- **SUSEP (Insurance)** — Circular 638/2021 on cyber risk for insurers.
- **ANATEL (Telecom)** — confidentiality obligations under Lei Geral de Telecomunicações coexist with LGPD.
- **Marco Civil da Internet** (Law 12.965/2014) — log-retention obligations (12 months for application logs, 6 months for connection logs) that still apply alongside LGPD's data-minimization principle.

For listed multinationals, also consider SEC 8-K disclosure (the [[case-study-okta-2023-support-system]] and [[case-study-snowflake-2024]] timelines show how badly stacked obligations can collide).

## Comparison to GDPR

| Dimension | GDPR | LGPD |
| --- | --- | --- |
| Regulator | National DPAs + EDPB | ANPD (federal, since 2020) |
| Legal bases (general) | 6 | 10 |
| Breach notification | 72 hours to DPA | "Reasonable time" — 3 business days per 2024 regulation |
| Max fine | 4% global revenue / EUR 20M | 2% Brazil revenue / R$50M per infraction |
| DPO requirement | Conditional (Art. 37) | Broad default (Art. 41), small-biz carve-outs |
| Extraterritorial | Yes (Art. 3) | Yes (Art. 3) |
| Sensitive data | Art. 9 | Art. 11 (similar list + extra basis) |
| Automated-decision review | Art. 22 | Art. 20 (right reviewed by ANPD in 2022) |
| Class actions | National rules vary | Allowed under Brazilian consumer/collective-rights law |

Big mental model: if your GDPR program is mature, LGPD is mostly mapping and additions. If you are starting from scratch in Brazil, do not assume "GDPR-lite" — the sectoral overlay (especially BACEN) often dominates the engineering work.

## Defensive baseline for security teams

Things you actually do:

- **Map processing activities.** Build/update your RoPA (Registro de Operações de Tratamento) — required by Art. 37. The GDPR Art. 30 record format works fine.
- **Wire breach notification into IR.** Decision criteria (relevant risk?), notification template (ANPD form fields), responsible role (DPO + Legal + CISO), and an explicit 3-business-day clock starting at "becoming aware." Tabletop it. See [[ir-from-source-signals]].
- **Identify CPF in your data flows.** Treat CPF + identifying data as a notification trigger by default. Tokenization or pseudonymization reduces breach scope.
- **DSAR pipeline.** Reuse what you built for GDPR; map LGPD-specific rights (e.g., information about sharing partners under Art. 18 V).
- **Vendor/processor contracts.** Art. 39 requires processor instructions; the cross-border rules (Art. 33) require adequacy, contractual clauses, or specific consent. ANPD published model standard contractual clauses in 2024.
- **Sectoral mapping.** If you are in finance, layer BACEN Res. 4.893 controls and incident-reporting timelines on top of LGPD.
- **Document your security controls.** ANPD's dosimetry explicitly rewards demonstrated controls. Tie your [[appsec-maturity-checklist]] and [[secure-sdlc-rollout-playbook]] artifacts to your LGPD compliance file.

## Workflow to study

1. Read LGPD itself (Lei 13.709/2018) — it is ~65 articles, an afternoon in Portuguese or the unofficial English translations the IAPP maintains.
2. Read ANPD's regulations stack in order: Sanctions (CD/ANPD 1/2021), Small-business (CD/ANPD 2/2022), Dosimetry (CD/ANPD 4/2023), Breach Notification (CD/ANPD 15/2024), Standard Contractual Clauses (2024).
3. Compare your existing GDPR control set to LGPD obligations — produce a gap matrix.
4. Build the breach-notification runbook with an explicit clock and ANPD-form field mapping; tabletop it.
5. Identify which sectoral regulators stack onto your case (BACEN, CVM, SUSEP, ANATEL) and integrate their reporting paths.
6. Review your processor agreements for Art. 39 instructions and cross-border transfer mechanism (Art. 33).
7. Stand up or formalize the Encarregado role with a real reporting line into security/IR.

## Related

- [[gdpr-incident-implications]]
- [[pdpa-singapore]]
- [[appi-japan]]
- [[dpdp-india]]
- [[hipaa-security-rule]]
- [[pci-dss-4-implementation]]
- [[nis2-implementation]]
- [[soc2-vs-iso27001]]
- [[responsible-disclosure-across-jurisdictions]]
- [[ir-from-source-signals]]
- [[case-study-snowflake-2024]]
- [[appsec-maturity-checklist]]

## References

- https://www.gov.br/anpd/pt-br — Autoridade Nacional de Proteção de Dados (ANPD) official site, regulations and guidance
- https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm — Lei 13.709/2018 (LGPD) official text
- https://iapp.org/resources/article/brazilian-data-protection-law-lgpd-english-translation/ — IAPP unofficial English translation and analysis
- https://www.bcb.gov.br/estabilidadefinanceira/cibernetica — BACEN cyber-resilience and incident-reporting page (Resolution 4.893 and follow-ups)
- https://www.gov.br/anpd/pt-br/assuntos/incidente-de-seguranca — ANPD breach-notification portal and Resolution CD/ANPD 15/2024 guidance
- https://www.cvm.gov.br/legislacao/resolucoes/resol035.html — CVM Resolution 35/2021 cyber rules for fund administrators
