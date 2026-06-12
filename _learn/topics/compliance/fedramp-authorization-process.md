---
title: FedRAMP — cloud authorization for US federal
slug: fedramp-authorization-process
---

> **TL;DR:** Federal Risk and Authorization Management Program (FedRAMP) is the US government framework for authorising cloud services for federal agency use. Three impact levels (Low, Moderate, High), two authorisation paths (JAB P-ATO and Agency ATO), and a continuous monitoring obligation. 18-month-plus authorisation timeline; major commercial commitment.

## What it is
FedRAMP standardises security assessment, authorisation, and continuous monitoring for cloud services used by federal agencies. Established 2011, modernised by the **FedRAMP Authorization Act (FAA) of 2022** (signed Jan 2023) and subsequent updates including FedRAMP 20x (2024-2025 process reform).

Cloud service providers (CSPs) get authorised; agencies leverage authorisations to deploy services. Without FedRAMP, federal agencies generally cannot procure cloud services.

## Impact levels

| Level | Data sensitivity | Controls (Rev 5) |
|---|---|---|
| **Low** | Low confidentiality, integrity, availability impact | ~125 controls |
| **Low-LI-SaaS** | Lightweight SaaS with low impact, narrow scope | ~36 controls |
| **Moderate** | Most agency CUI, sensitive but not classified | ~325 controls |
| **High** | Law enforcement, emergency services, financial, health, very sensitive CUI | ~425 controls |

Impact determined per data type; aggregate of highest sensitivity within the service.

## Authorisation paths

### Joint Authorization Board (JAB) P-ATO
- **Provisional Authorization to Operate** from FedRAMP JAB (DoD, DHS, GSA representatives)
- Highly competitive: limited annual slots, prioritised by demand and government value
- Strongest reuse signal — most agencies trust JAB P-ATO without re-assessment
- 18-24 months typical

### Agency ATO
- **Authorization to Operate** issued by a specific sponsoring agency
- CSP partners with one agency willing to sponsor; assessment performed by 3PAO; agency authorises
- More common path; faster than JAB
- ATO leverageable by other agencies (one agency authorises, others reuse via "Authorization Package" review)
- 12-18 months typical

### FedRAMP 20x (in progress)
2024-2025 modernisation aimed at faster, more automated authorisations. Continuous authorisation concepts, machine-readable control evidence, expanded reciprocity with StateRAMP and DoD IL2/4/5.

## Preconditions / where it applies

- Cloud service provider offering services to federal agencies
- Service involves federal data (FCI, CUI) or federal-mission processing
- Even commercial-first SaaS marketing to federal market needs FedRAMP for procurement

## Tradecraft

### Phase 1 — Readiness assessment (Months 1-6)

Self-assess maturity vs FedRAMP requirements:
- NIST SP 800-53 Rev 5 control baseline (Low/Mod/High)
- FedRAMP-specific parameter values (FedRAMP "tailors" 800-53)
- Continuous Monitoring (ConMon) requirements
- Cryptographic requirements (FIPS 140-2/3 validated modules)
- US person personnel handling (PS-2 background screening)
- US-based data centres (most cases)

Many commercial SaaS providers find their environment needs ~30-50% rework: stronger MFA, FIPS-validated crypto, US persons in operations roles, separate environment from commercial.

### Phase 2 — FedRAMP Tailored Low-LI-SaaS path (if applicable)

For low-impact lightweight SaaS only:
- Reduced controls (~36)
- Self-attestation OR 3PAO assessment
- Faster authorisation (3-9 months)
- Eligibility narrow: not all SaaS qualifies

### Phase 3 — Sponsor identification

Agency ATO path requires sponsor:
- Find an agency willing to authorise (often via pilot project or existing relationship)
- Build the business case for that agency's use of your service
- Establish points of contact for the assessment process

JAB P-ATO path: apply via FedRAMP PMO; selection criteria include demand, criticality, security maturity.

### Phase 4 — System Security Plan (SSP)

The central deliverable. Hundreds of pages covering:
- System boundary diagram + components inventory
- Each control's implementation per FedRAMP parameter
- Inheritance from underlying providers (e.g., AWS GovCloud / Azure Government as Cloud Service Provider for IaaS)
- Continuous Monitoring strategy
- Incident response procedures
- Contingency planning

FedRAMP SSP template required. Inheritance lets you reuse controls met by the underlying IaaS — significant scope reduction.

### Phase 5 — 3PAO assessment

3PAO = Third Party Assessment Organization, accredited by FedRAMP PMO. Assessment covers:
- Penetration testing (FedRAMP penetration test guidance)
- Security Control Assessment (SCA) testing each control's implementation
- Documentation review
- Continuous Monitoring readiness

Assessment lasts weeks; output is the Security Assessment Report (SAR) and Plan of Action & Milestones (POA&M).

### Phase 6 — Authorization

JAB or Agency reviews the package:
- SSP
- SAR + 3PAO testing artifacts
- POA&M
- Continuous Monitoring plan

Result: ATO letter. CSP listed on FedRAMP Marketplace. Agencies can now procure.

### Phase 7 — Continuous Monitoring (ConMon)

After authorisation:
- Monthly vulnerability scans (with FedRAMP-prescribed scope)
- Annual SCA on subset of controls
- Significant change requests reviewed before deployment
- POA&M items remediated per SLA (typically 30/90/180 days based on severity)
- Annual full re-assessment cycle

ConMon is the biggest ongoing investment. Many CSPs underestimate it.

## FedRAMP control modifications vs vanilla NIST 800-53

FedRAMP "tailors" 800-53:
- Parameter values prescribed (e.g., audit log retention = 1 year not "organisation-defined")
- Some controls strengthened or added (FedRAMP-specific additions)
- US-centric assumptions (citizenship, geography)
- Cryptographic requirements pinned to FIPS-validated modules

Practitioner skill: knowing where FedRAMP differs from your existing NIST 800-53 implementation.

## Cost reality

Authorisation costs (2025 estimates):
- Readiness consulting: $200K-$1M
- 3PAO assessment: $300K-$1M
- Internal staffing: 2-10 FTE for the duration
- Infrastructure: separate FedRAMP environment ($M/yr in cloud costs)
- Authorisation timeline opportunity cost: 18+ months

Most successful FedRAMP CSPs are SaaS with existing federal customer demand strong enough to justify multi-million investment.

## Intersection with related programs

- **StateRAMP** — state and local government cloud authorisation; FedRAMP-aligned
- **DoD Cloud Computing Security Requirements Guide (CC SRG)** — DoD Impact Levels (IL2, 4, 5, 6); FedRAMP Moderate roughly = IL2; FedRAMP High roughly = IL4/5
- **CMMC** — for DIB contractors (see [[cmmc-2-dod-contractor]]); separate from FedRAMP but cloud providers serving DIB often have both
- **IRS Publication 1075** — federal tax info CUI; FedRAMP + IRS 1075 layer
- **CJIS** — criminal justice information; FedRAMP + CJIS layer
- **FISMA** — broader federal cybersecurity law; FedRAMP is its cloud implementation

## Common implementation pitfalls

- **Underestimating ConMon** — annual operational cost rivals initial authorisation cost
- **Mixing commercial and federal environments** — FedRAMP requires logical separation; common to discover shared infrastructure failing the boundary requirement
- **Inheritance confusion** — inheriting from AWS/Azure GovCloud is allowed but must be documented; CSPs sometimes claim inheritance not supported by the IaaS scope
- **Personnel requirements** — US person operations staff (Public Trust clearance minimum) required for many roles; visa-holder staff may need reassignment
- **Cryptographic gaps** — FIPS 140 validated modules required for crypto; some commercial libraries fall short
- **Significant change paranoia** — small changes (library updates, config tweaks) require change request; balance velocity vs ConMon burden

## FedRAMP Marketplace

Live listing of authorised CSPs at marketplace.fedramp.gov. Searchable by impact level, agency authorisation, service category. Used by agencies during procurement.

## OPSEC for compliance team

- SSP and SAR contain detailed defensive posture description — TLP:AMBER federal-only
- ConMon reports include vulnerability data — restricted access
- 3PAO testing results may surface real attack paths — coordinate with internal IR
- POA&M items must be tracked truthfully — false reporting under federal contracts carries FCA exposure

## References
- [FedRAMP PMO](https://www.fedramp.gov/)
- [FedRAMP Marketplace](https://marketplace.fedramp.gov/)
- [NIST SP 800-53 Rev 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final)
- [FedRAMP Authorization Act (FAA) 2022](https://www.congress.gov/bill/117th-congress/house-bill/21)
- [DoD CC SRG](https://public.cyber.mil/dccs/dccs-documents/)

See also: [[cmmc-2-dod-contractor]], [[nist-csf-2-implementation]], [[iso-27002-2022-controls-catalog]], [[soc2-vs-iso27001]], [[third-party-risk-management-practitioner]], [[hitrust-csf-implementation]], [[csa-star-cloud-security]], [[dora-eu-implementation]]
