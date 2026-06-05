---
title: Threat modelling — LINDDUN for privacy
slug: threat-modelling-linddun-privacy
aliases: [linddun-privacy, privacy-threat-modelling]
---

> **TL;DR:** LINDDUN is the privacy counterpart to STRIDE: a structured methodology that walks a data-flow diagram (DFD) through seven privacy threat categories — Linking, Identifying, Non-repudiation, Detecting, Data Disclosure, Unawareness/Unintervenability, and Non-compliance — and maps findings onto privacy-by-design mitigations. For systems handling personal data, run LINDDUN *alongside* [[appsec-threat-modeling]] / STRIDE rather than instead of it. Pairs naturally with [[gdpr-incident-implications]], [[lgpd-brazil]], [[pdpa-singapore]], [[appi-japan]], and [[dpdp-india]] when scoping regional obligations.

## Why it matters

STRIDE was designed to find confidentiality, integrity, and availability bugs. It is not built to surface "this design is legal but creepy" problems: re-identification through joinable datasets, dark-pattern consent, retention that outlives purpose, opaque automated decisions. Those are exactly the failure modes regulators now fine.

LINDDUN (originated at KU Leuven, DistriNet group) gives engineers a vocabulary for the privacy side. It matters because:

- **Regulator expectations.** GDPR Article 25 ("data protection by design and by default") and equivalents in [[lgpd-brazil]], [[pdpa-singapore]], [[appi-japan]], and [[dpdp-india]] effectively require *some* documented privacy threat-modelling process. LINDDUN is the most cited public method.
- **DPIA inputs.** A LINDDUN pass feeds directly into a Data Protection Impact Assessment. Without it, DPIAs tend to become checklists copied between products.
- **Cross-team translation.** Privacy/legal teams speak in rights and lawful bases. Engineers speak in components and flows. LINDDUN's per-element table is one of the few artefacts both sides will read.
- **Catches design-time defects.** Like all threat modelling, the cheapest privacy bug to fix is the one not yet shipped. See [[secure-sdlc-rollout-playbook]] for where to slot it in.

## The seven categories

LINDDUN v2 (2023 revision) consolidated the original list slightly. The categories below reflect the current canonical naming.

### Linking

Linking two or more data items, actions, or sessions to the same data subject (or group) when the subject did not intend it. Example: ad-tech cookies bridging a logged-out session to a logged-in profile; correlating "anonymous" telemetry by device fingerprint.

### Identifying

Going further than linking — actually attaching a real-world identity to a record that should have been pseudonymous or anonymous. Re-identification of "anonymised" datasets via quasi-identifiers (postcode + DOB + sex) is the canonical case.

### Non-repudiation (privacy sense)

The system makes it impossible for a user to plausibly deny they performed an action when they have a legitimate interest in deniability — whistleblower portals, abuse-reporting flows, off-the-record messaging. This is the inverse of the *security* property of non-repudiation; that is the trap newcomers fall into.

### Detecting

An observer can infer that a record *exists* about a subject, even without reading the content. Example: an HTTP 200 vs 404 on `/users/<email>` discloses membership; query timing reveals that a watchlist entry matched.

### Data Disclosure

Unnecessary or unauthorised exposure of personal data — to operators, sub-processors, other users, or attackers. This is the category that overlaps most with STRIDE's Information Disclosure, but LINDDUN scopes it to *personal* data and forces a minimisation question, not just an access-control question.

### Unawareness & Unintervenability

Subjects are not adequately informed of processing, or cannot exercise their rights (access, rectification, erasure, objection, withdraw consent, opt out of automated decisions). Dark patterns, pre-ticked boxes, "settings" buried five screens deep, and irreversible model training all live here. v2 merged the previously separate U and Un categories.

### Non-compliance

The processing does not meet applicable legal, contractual, or policy requirements: missing lawful basis, cross-border transfer without safeguards, retention beyond purpose, sub-processor not in the register. This is the bridge to [[gdpr-incident-implications]] and the regional notes.

## Process

LINDDUN is a six-step loop. Treat it as iterative — the first pass will be wrong.

### 1. Define the system (DFD, privacy flavour)

Draw a Data Flow Diagram, but with privacy emphasis:

- Label every data store and flow with the **personal data categories** carried (identifiers, special-category data under GDPR Art. 9, payment data, location, biometric, children's data).
- Mark **trust boundaries** at processor/sub-processor edges, not just network edges. A flow from your app to Stripe is a boundary even if both are "your" infra logically.
- Annotate **retention** and **purpose** on each store. A store without a documented purpose is already a finding.
- Note **data subject categories** (customers, employees, third parties, minors) — different rights regimes apply.

This is the single biggest difference from a STRIDE DFD: STRIDE cares about who can write to what; LINDDUN cares about *what kind of person's data sits where, why, and for how long*.

### 2. Map threats to elements

Use the LINDDUN threat tree catalog (published as PDFs by the KU Leuven team). For each DFD element (entity, process, data flow, data store), iterate the seven categories and ask "does this apply?". Most cells are "no" — that is fine, document why.

### 3. Identify and prioritise

For each plausible threat, capture: affected element, threat category, scenario, likelihood, impact on the data subject (not just the company), and any pre-existing controls. Likelihood/impact rubrics from [[cvss-scoring-practitioner]] do *not* translate cleanly — privacy harm is about subjects, not CIA.

### 4. Elicit mitigation strategies

Map each threat to one or more privacy-by-design strategies. The Hoepman 8 strategies (minimise, hide, separate, abstract, inform, control, enforce, demonstrate) are the most common pairing.

### 5. Select PETs / controls

Translate strategies into concrete privacy-enhancing technologies or process controls: pseudonymisation, k-anonymity / differential privacy, consent management platform, retention jobs, DSAR (data subject access request) tooling, sub-processor contracts.

### 6. Document and feed downstream

Outputs go into: the DPIA, the Record of Processing Activities (ROPA), the threat model repo alongside STRIDE artefacts, and the issue tracker. Without this step, LINDDUN becomes a one-off workshop.

## LINDDUN GO

The full method is heavy for a two-pizza team shipping a feature. LINDDUN GO is the lightweight variant: a deck of ~33 threat cards, each describing a scenario plus prompting questions. A facilitator walks the team through the deck in 60–90 minutes, recording the cards that "stick" against the design.

GO is a good fit for:

- Sprint-level features where a full LINDDUN pass is overkill.
- Teams new to privacy threat modelling — the cards lower the activation energy.
- Workshops with mixed audiences (PM, eng, legal).

Caveat: GO is for elicitation, not assurance. If you are processing special-category data or doing a DPIA, the full method is still expected.

## How LINDDUN complements STRIDE

Run both. They overlap less than people assume:

- STRIDE finds an SSRF that exfiltrates secrets; LINDDUN asks whether the secrets store should contain personal data at all.
- STRIDE asserts authentication is required; LINDDUN asks whether the auth log itself becomes a tracking surface.
- STRIDE catches a missing CSRF token; LINDDUN catches a missing consent record for the action.

Practical recipe: do STRIDE first on the security-critical surface, then LINDDUN on the data-handling surface, then reconcile in one combined threat register. See [[appsec-threat-modeling]] for sequencing inside an SDLC.

## Mapping to regional regimes

LINDDUN's Non-compliance category is the hook. The other six categories surface engineering-level facts that feed regional analyses:

- **GDPR / EU** — Art. 25 (by design/default), Art. 35 (DPIA), Art. 32 (security of processing). See [[gdpr-incident-implications]].
- **Brazil — LGPD.** Similar structure to GDPR; DPIA equivalent is the RIPD. See [[lgpd-brazil]].
- **Singapore — PDPA.** Consent-centric, accountability obligation. See [[pdpa-singapore]].
- **Japan — APPI.** Strong rules on cross-border transfer and sensitive personal information. See [[appi-japan]].
- **India — DPDP Act 2023.** Significant Data Fiduciary designations trigger DPIA-like obligations. See [[dpdp-india]].
- **California — CCPA/CPRA.** "Do not sell or share" maps directly onto Unawareness/Unintervenability findings.

The LINDDUN output is regime-neutral; the *prioritisation* is not. A Linking finding involving location data is severe under GDPR, even more severe under CCPA's sensitive PI definitions.

## Tooling

The ecosystem is thinner than STRIDE's:

- **LINDDUN GO cards** (PDF + printable deck) from KU Leuven.
- **LINDDUN PRO** documentation and threat trees (PDF) from the same source.
- **Microsoft Threat Modeling Tool** — no native LINDDUN templates; community templates exist with variable quality.
- **OWASP pytm** — DSL-based, has community LINDDUN extensions.
- **IriusRisk / SD Elements** — commercial platforms with LINDDUN content packs; verify currency before buying.
- **draw.io / Excalidraw** — fine for the DFD; track threats in your normal issue system.

Honest take: most teams end up with a spreadsheet plus a wiki page. That is acceptable. Tooling is not the bottleneck; *doing the workshop* is.

## Common mistakes

- **Confusing privacy non-repudiation with the STRIDE meaning.** Engineers reflexively add audit logs to "fix" it, which is exactly wrong.
- **Treating Data Disclosure as "did we authenticate?"** The real question is "did we need to collect this in the first place?"
- **Skipping retention annotations on the DFD.** Without them, minimisation findings are invisible.
- **Letting legal own the output alone.** LINDDUN findings often require code changes (pseudonymisation at write time, deletion cascade jobs, consent state machines). Engineering must own remediation.
- **Doing it once at launch.** Personal-data flows mutate every sprint. Re-run at least when adding a new processor, a new data category, a new jurisdiction, or a new model that trains on user data.
- **Skipping the data-subject impact rating.** "Low impact to the business" is not the same as "low impact to the user".

## Realistic effort and who succeeds

A first LINDDUN pass on a medium-sized product (10–20 services) is typically a 2–3 day workshop with prep, plus 1–2 weeks of follow-up to triage and ticket. LINDDUN GO on a single feature is a half-day.

Teams that succeed share three traits: they already do STRIDE (or some structured threat modelling), they have at least one person who understands the local privacy regime well enough to translate, and they treat findings as engineering work rather than a legal sign-off. Teams that fail tend to outsource the workshop to a consultant, accept the deck, and never reopen it.

Vendor marketing will claim LINDDUN coverage as a checkbox. Ask for the threat tree they actually use and the date it was last updated against v2. Many "LINDDUN" content packs still ship the original seven categories with the old U/Un split.

## Workflow to study

1. Read the LINDDUN v2 tutorial paper from KU Leuven end-to-end. It is short.
2. Print the LINDDUN GO deck. Run a workshop on a *toy* system (a fitness tracker, a school portal) before touching a real one.
3. Pick one real internal service that processes personal data. Draw the privacy-flavoured DFD. Do not skip retention annotations.
4. Run a full LINDDUN PRO pass with at least one engineer, one PM, and one privacy/legal stakeholder.
5. Map each finding to a Hoepman strategy and a concrete control. File tickets.
6. Compare against your existing STRIDE register. Note overlaps and gaps.
7. Re-run the exercise 6 months later. The mutation rate of findings is the real measure of whether the process is alive.

## Related

- [[appsec-threat-modeling]]
- [[secure-sdlc-rollout-playbook]]
- [[gdpr-incident-implications]]
- [[lgpd-brazil]]
- [[pdpa-singapore]]
- [[appi-japan]]
- [[dpdp-india]]
- [[appsec-maturity-checklist]]
- [[policy-and-standards-writing]]
- [[third-party-risk-management-practitioner]]
- [[responsible-disclosure-across-jurisdictions]]

## References

- LINDDUN project site and v2 materials — https://linddun.org/
- KU Leuven DistriNet group publications — https://distrinet.cs.kuleuven.be/
- ENISA, "Data Protection Engineering" — https://www.enisa.europa.eu/publications/data-protection-engineering
- Hoepman, "Privacy Design Strategies" (the eight-strategy paper) — https://www.cs.ru.nl/~jhh/publications/pds-booklet.pdf
- NIST Privacy Framework — https://www.nist.gov/privacy-framework
- European Data Protection Board, DPIA guidelines (WP248 rev.01) — https://edpb.europa.eu/our-work-tools/general-guidance/guidelines-recommendations-best-practices_en
