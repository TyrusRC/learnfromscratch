---
title: DPDP Act — India Digital Personal Data Protection Act
slug: dpdp-india
aliases: [india-dpdp, in-privacy]
---

> **TL;DR:** India's Digital Personal Data Protection (DPDP) Act, 2023 is the first comprehensive horizontal privacy law in India, replacing the patchwork of the IT Act 2000 + SPDI Rules 2011 for digital personal data. It introduces a Data Protection Board (DPB) as regulator, a Data Fiduciary / Data Processor / Significant Data Fiduciary role taxonomy, a notice-and-consent framework with verifiable consent, data-principal rights, and penalties up to INR 250 crore per instance. Operationalizing it looks similar to [[gdpr-incident-implications]] with India-specific quirks: the DPB-driven enforcement model, a blacklisting approach to cross-border transfers, and broad government exemptions. Compare with [[pdpa-singapore]], [[appi-japan]], and [[lgpd-brazil]] for the broader APAC/global picture.

## Why it matters

If your organization processes personal data of individuals in India — whether you are an Indian company, a global SaaS with Indian users, or a processor for an Indian Data Fiduciary — DPDP applies. Unlike the old SPDI Rules, which only meaningfully covered "sensitive personal data or information" (passwords, financial info, health, biometric, sexual orientation, etc.) and were enforced weakly via the IT Act, DPDP creates a real regulator, a real penalty regime, and real obligations on processors.

For security practitioners the immediate questions are:

- Are we a Data Fiduciary, a Data Processor, or both, for each processing activity?
- Do we hit the (yet-to-be-notified) thresholds for Significant Data Fiduciary (SDF) status?
- Do we have a defensible consent + notice flow, and can we honor data-principal rights at scale?
- Can we detect and report breaches to the DPB and affected principals on time once rules are notified?
- Are we ready for the blacklisting model on cross-border transfers, which can change overnight?

This is not legal advice — engage Indian counsel for legal interpretation. This note is the practitioner view: what a security team has to actually build or change.

## Classes, roles, and key concepts

### Roles

- **Data Principal** — the natural person to whom the personal data relates. For children (under 18) and persons with disabilities under guardianship, the parent/lawful guardian acts on their behalf.
- **Data Fiduciary** — equivalent to GDPR's "controller". Decides purpose and means of processing.
- **Data Processor** — equivalent to GDPR's "processor". Processes on behalf of a Data Fiduciary under contract.
- **Significant Data Fiduciary (SDF)** — a Data Fiduciary notified by the Central Government based on volume and sensitivity of data, risk to electoral democracy, public order, state sovereignty, etc. SDFs face extra obligations: appoint a Data Protection Officer (DPO) based in India, appoint an independent Data Auditor, conduct periodic Data Protection Impact Assessments (DPIAs).
- **Consent Manager** — a registered intermediary that lets Data Principals give, manage, review, and withdraw consent across Fiduciaries via an interoperable platform. This is an India-specific innovation borrowed from the Account Aggregator framework.

### Lawful basis

DPDP recognizes two basic grounds:

1. **Consent** — free, specific, informed, unconditional, unambiguous, with a clear affirmative action. Must be preceded by a notice describing the data, purpose, rights, and grievance redressal.
2. **Certain legitimate uses** — including voluntarily provided data for a specified purpose, state functions, compliance with law/judgment, medical emergencies, disasters, employment-related purposes, etc.

Note this is narrower than GDPR's six bases; there is no general "legitimate interests" basis.

### Data-principal rights

- Right to access information about processing
- Right to correction, completion, updating, erasure
- Right of grievance redressal (must be addressed within a period to be prescribed)
- Right to nominate another person to exercise rights in case of death or incapacity

### Children's data

Processing children's (under-18) data requires verifiable parental consent. Tracking, behavioral monitoring, and targeted advertising directed at children are prohibited. Some Fiduciaries / processing classes may be exempted by government notification.

### Cross-border transfers — the blacklist model

DPDP flips the GDPR adequacy logic. Cross-border transfer is **allowed by default** to any country, except countries the Central Government **notifies as restricted** ("negative list"). Sectoral regulators (RBI, IRDAI, SEBI) can impose stricter localization (e.g., RBI's payment data localization remains in force).

### Penalty regime

The Schedule sets penalty tiers per instance:

- Up to **INR 250 crore** — failure to take reasonable security safeguards to prevent a personal data breach
- Up to **INR 200 crore** — failure of breach notification, failure of additional SDF obligations, failure to protect children's data
- Up to **INR 50 crore** — failure of other Fiduciary obligations
- Up to **INR 10,000** — on Data Principals for false / frivolous complaints

The DPB determines the actual penalty based on nature, gravity, duration, repeated nature, and gain/loss.

### Interaction with IT Act 2000 / SPDI Rules 2011

- DPDP supersedes Section 43A of the IT Act (compensation for negligent handling of SPDI) — that section and the SPDI Rules are repealed by the DPDP Act with respect to digital personal data once the Act is in force.
- Section 69A (blocking) and CERT-In's 2022 directions on 6-hour cyber incident reporting are **separate** and continue to apply. You may have to report the same breach to **both** CERT-In (security incident, 6 hours) and the DPB (personal data breach, timeline TBD by rules).
- Sectoral rules (RBI cyber framework, SEBI CSCRF, IRDAI guidelines) continue alongside DPDP.

## Defensive baseline for a DPDP-ready security program

Even before draft rules are fully notified, a security team can prepare:

### 1. Data mapping and role classification

- Build a record of processing: data categories, purposes, lawful basis, retention, transfers, processors involved, location of storage.
- Tag whether you are Fiduciary or Processor per activity. Update DPAs with sub-processors.
- Estimate whether SDF thresholds are likely to apply (volume of Indian principals, sensitivity, sectoral overlap).

### 2. Notice, consent, and consent withdrawal plumbing

- Implement layered notices in English plus the eighth-schedule languages where applicable.
- Build a consent ledger: who consented, to what, when, via which UI, and the corresponding notice version.
- Provide a withdrawal flow that is as easy as the give flow. Propagate withdrawals to downstream processors.
- Plan for Consent Manager integration once the framework is operational.

### 3. Data-principal rights workflow

- Centralized intake (web, email, in-app), identity verification proportional to risk, SLA tracking.
- Backend tooling to actually do access export, correction, and erasure across primary systems, data lakes, backups, and analytics warehouses. This is where most programs fail.
- Grievance officer published on the website with contact details. Maintain a complaint log and response audit trail.

### 4. Breach detection and notification

- DPDP defines "personal data breach" broadly: unauthorized processing, accidental disclosure, acquisition, sharing, use, alteration, destruction, or loss of access. Even a brief loss of access (ransomware) qualifies.
- The DPB must be notified, and affected Data Principals must be notified, in the form and manner to be prescribed. Treat this as a tight clock — design for hours, not days.
- Reuse the [[ir-from-source-signals]] muscle: scoping, evidence preservation, communication templates. Pre-draft principal notification copy in plain language.
- Remember the **parallel CERT-In track** (6-hour incident reporting under the 2022 directions) for cyber incidents.

### 5. Security safeguards

The Act simply says "reasonable security safeguards" — concrete controls will come via rules. Practitioner baseline that will survive any reasonable rulemaking:

- Encryption in transit and at rest, with key management
- Access control with least privilege, MFA, JIT for admins
- Logging and monitoring across identity, data, and infra layers (see [[siem-detection-use-case-catalog]], [[detection-engineering-pyramid-of-pain]])
- Vulnerability and patch management, asset inventory
- Secure SDLC ([[secure-sdlc-rollout-playbook]]) and appsec maturity ([[appsec-maturity-checklist]])
- DPIAs for new high-risk processing (mandatory for SDFs)
- Vendor / processor due diligence with right-to-audit clauses

### 6. Cross-border transfer hygiene

- Maintain an inventory of which Indian personal data flows where, via which processor, and under what contract.
- Monitor the government's negative-list notifications. Have a contingency plan to re-route or localize a workload within weeks if a destination country gets blacklisted.
- Layer sectoral localization on top (e.g., RBI payment data must remain in India even if DPDP would allow export).

### 7. Children's data

- Age-assurance mechanism proportionate to risk. Not necessarily hard KYC for every signup, but defensible.
- Block behavioral profiling and targeted ads for accounts identified as children.
- Parental consent workflow with verifiability evidence.

### 8. Governance

- DPO (mandatory for SDFs, good practice for others). India-based, reporting to the board / governing body.
- Independent Data Auditor for SDFs — start identifying candidates.
- Policy refresh: privacy policy, internal data handling SOP, retention schedule, incident response plan, vendor management policy.

## Comparison with GDPR

| Dimension | DPDP (India) | GDPR (EU) |
|---|---|---|
| Lawful bases | Consent + specified legitimate uses | Six bases incl. legitimate interests |
| Regulator | Data Protection Board (DPB) | Independent DPAs per member state + EDPB |
| Cross-border | Default allowed, blacklist by govt | Default restricted, adequacy / SCC / BCR |
| Penalties | Up to INR 250 crore per instance | Up to 4% global turnover or 20M EUR |
| Sensitive data | No separate category in DPDP itself | Special categories with heightened rules |
| Children | Under 18, verifiable parental consent | Under 16 (or lower per member state) |
| DPO | Mandatory only for SDFs | Mandatory for many controllers/processors |
| Right to data portability | Not explicit | Yes |
| Right to object / automated decisions | Not explicit | Yes |
| Profiling restrictions | Children only | General |
| Government exemptions | Broad | Narrower, subject to CJEU review |

The big practical gap: DPDP gives the Central Government broad rule-making and exemption powers (notably the Section 17 exemption for processors handling government data) that simply do not exist in GDPR. That makes the regulatory surface less stable than the EU's.

## Workflow to study

1. Read the DPDP Act 2023 bare text (it is short — under 50 pages).
2. Read the latest **Draft DPDP Rules** when notified by MeitY, plus the public consultation responses.
3. Skim the IT Act 2000 Section 43A and SPDI Rules 2011 to understand what you are migrating from.
4. Compare clause-by-clause against GDPR for your existing privacy program — see [[gdpr-incident-implications]] for breach handling reuse.
5. Map your processing activities, then your tech stack, then identify gaps for each obligation.
6. Walk a tabletop exercise: a ransomware incident affecting 100k Indian Data Principals. Who notifies CERT-In within 6 hours, who notifies the DPB, who notifies principals, who handles media, who handles regulators in other jurisdictions ([[pdpa-singapore]], [[appi-japan]], [[lgpd-brazil]] if you serve those markets too).
7. Track DPB rulings as they appear — early enforcement actions will set the de-facto bar for "reasonable security safeguards".

## Related

- [[gdpr-incident-implications]]
- [[pdpa-singapore]]
- [[appi-japan]]
- [[lgpd-brazil]]
- [[soc2-vs-iso27001]]
- [[hipaa-security-rule]]
- [[pci-dss-4-implementation]]
- [[nis2-implementation]]
- [[responsible-disclosure-across-jurisdictions]]
- [[ir-from-source-signals]]
- [[secure-sdlc-rollout-playbook]]
- [[appsec-maturity-checklist]]

## References

- https://www.meity.gov.in/static/uploads/2024/06/2bf1f0e9f04e6fb4f8fef35e82c42aa5.pdf
- https://www.meity.gov.in/data-protection-framework
- https://prsindia.org/billtrack/the-digital-personal-data-protection-bill-2023
- https://www.cert-in.org.in/PDF/CERT-In_Directions_70B_28.04.2022.pdf
- https://www.dataguidance.com/notes/india-data-protection-overview
- https://iapp.org/resources/article/india-digital-personal-data-protection-act/
