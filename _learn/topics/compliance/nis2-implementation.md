---
title: NIS2 — EU directive practitioner's view
slug: nis2-implementation
aliases: [nis2, nis2-directive, eu-nis2]
---

> **TL;DR:** NIS2 (Directive (EU) 2022/2555) replaces NIS1 and broadly extends EU cybersecurity rules to essential and important entities across many sectors (energy, transport, banking, health, digital infrastructure, manufacturing, food, public administration). Each member state implements via national law (e.g., Germany's NIS2UmsuCG, Italy's Decreto Legislativo, etc.). Practitioner: risk management measures, mandatory incident notification (24/72/30-hour cascade), and senior-management accountability. Companion to [[pci-dss-4-implementation]] and [[gdpr-incident-implications]].

## Why NIS2 matters

- **Greatly expanded scope** vs NIS1 — many more sectors and entity sizes.
- **Member-state implementations vary** — same directive, different national interpretations.
- **Mandatory incident notification** with tight timelines.
- **Senior-management direct accountability** — board members can be personally liable.
- **Significant fines** — up to €10M or 2% of global turnover (essential entities), €7M or 1.4% (important).

## Scope

NIS2 covers:
- **Essential entities** — high-criticality (energy, transport, banking, health, water, digital infrastructure, public administration, space).
- **Important entities** — significant (manufacturing, food, postal/courier, waste management, digital providers, research).

Within sectors, generally: medium and large entities (>50 employees or >€10M annual). Small/micro generally out (with exceptions).

Geographic: EU + entities offering services in EU.

## Risk management measures

Article 21 lists at least ten:
1. Risk-analysis and information-system security policies.
2. Incident handling.
3. Business continuity (including backup, disaster recovery, crisis management).
4. Supply chain security (including security-related aspects of vendor relationships).
5. Security in network and information systems acquisition, development, and maintenance, including vulnerability handling and disclosure.
6. Policies and procedures (testing and auditing).
7. Cyber hygiene practices and training.
8. Cryptography (including encryption).
9. Human resources, access control, asset management.
10. Multi-factor authentication, secure voice / video / text communications, and secure emergency-communication systems.

Practitioner: this maps closely to ISO 27001 Annex A, NIST CSF, etc. Implementations leverage existing frameworks.

## Incident notification cascade

Article 23 requires reporting to the competent authority / CSIRT in three steps:

- **Early warning** within **24 hours** of becoming aware of significant incident.
- **Incident notification** within **72 hours** — assessment, indicators of compromise, cross-border impact.
- **Final report** within **30 days** — root cause, mitigations, impact assessment.

Plus interim updates as appropriate.

"Significant" incident: serious operational disruption, financial loss, material loss to others.

## Supply chain security

Article 21(2)(d) specifically: assess security of suppliers, including those of MSPs / MSSPs. This applies upstream — a supplier failing security affects you for NIS2 purposes.

Drives contractual security clauses, supplier audits, and proactive supplier-incident tracking.

## Vulnerability handling and disclosure

Article 21(2)(e) requires coordinated vulnerability disclosure. EU member states must designate a CSIRT to handle CVDs (Coordinated Vulnerability Disclosure). Researchers gain (varying) legal protection for good-faith reports.

See [[responsible-disclosure-across-jurisdictions]].

## Senior management accountability

Article 20: management bodies of essential and important entities must approve the cybersecurity risk management measures, follow specific training, and can be held personally accountable.

This is **board-level material** — not delegated entirely to CISO.

## National implementation variability

Each member state implements NIS2 in national law. Differences include:
- Exact incident-threshold definitions.
- Specific sectoral additions.
- Fine schedules within EU caps.
- CSIRT contact procedures.
- Whether public-sector entities are in or out.

For multinational organisations: know each member state's specific requirements for your operations.

By mid-2025 implementation status: most member states have transposed, with some delays. Compliance enforcement ramping up.

## Comparison to other regimes

- **NIS1** — narrower scope, weaker enforcement; superseded.
- **GDPR** — privacy-focused; complementary for breach involving personal data.
- **DORA (Digital Operational Resilience Act)** — financial-sector ICT resilience; overlaps for banks. DORA applies in parallel.
- **CRA (Cyber Resilience Act)** — product-side; complements NIS2's entity-side.

Multinationals navigate all of these simultaneously.

## Practitioner mapping

For a typical EU mid-large entity:

- **Risk management** — ISO 27001 control adoption + risk register.
- **Incident handling** — runbooks with explicit NIS2 reporting timeline integration.
- **Business continuity** — tested BCP / DR.
- **Supply chain** — vendor security questionnaires, contractual security obligations, third-party risk management process.
- **Vulnerability handling** — internal vulnerability management + coordinated disclosure path.
- **MFA + crypto** — modern identity, encryption.
- **Training** — annual security awareness + role-specific training.
- **Senior management training** — explicit board-level briefings.

## Common mistakes

- **Treating NIS2 as IT-only** — missing the board-level component.
- **Inadequate incident-reporting integration** — IR runbooks not aligned with 24/72 timeline.
- **No supplier-security program** — discovering supply-chain reporting gap during incident.
- **Inadequate documentation** — measures exist but aren't documentable for audit.
- **Assuming NIS1 carry-over** — NIS2 is meaningfully different.

## Workflow to start

1. **Confirm scope** — is your entity essential / important / out?
2. **Map measures** — gap analysis against Article 21 list.
3. **Update incident response** — integrate 24/72/30 timeline.
4. **Vendor security program** — risk-based supplier assessment.
5. **Board briefing** — Article 20 training.
6. **Engage** with national CSIRT, register if required.

## Workflow to study

1. Read the directive text (2022/2555).
2. Read your member state's transposition law.
3. Map your existing controls (ISO / SOC 2 / etc.) to Article 21.
4. Build an incident-reporting decision tree.

## Related

- [[pci-dss-4-implementation]] — adjacent regime.
- [[hipaa-security-rule]] — adjacent regime.
- [[gdpr-incident-implications]] — privacy-side complement.
- [[soc2-vs-iso27001]].
- [[responsible-disclosure-across-jurisdictions]].
- [[third-party-saas-misconfig-patterns]].

## References
- [Directive (EU) 2022/2555 (NIS2)](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32022L2555)
- [ENISA — NIS2 page](https://www.enisa.europa.eu/topics/cybersecurity-policy/nis-directive-new)
- [European Commission — DG CONNECT NIS2](https://digital-strategy.ec.europa.eu/en/policies/nis2-directive)
- See also: [[pci-dss-4-implementation]], [[hipaa-security-rule]], [[gdpr-incident-implications]], [[soc2-vs-iso27001]], [[responsible-disclosure-across-jurisdictions]]
