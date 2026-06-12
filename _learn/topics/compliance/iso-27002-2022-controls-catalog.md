---
title: ISO/IEC 27002:2022 — controls catalog and implementation
slug: iso-27002-2022-controls-catalog
---

> **TL;DR:** ISO/IEC 27002:2022 is the implementation guidance companion to ISO 27001 Annex A. The 2022 revision restructured controls from 14 domains (114 controls) to 4 themes (93 controls), introduced attribute-based tagging (control type, security property, cybersecurity concept, operational capability, security domain), and added 11 new controls reflecting cloud, threat intelligence, and modern engineering practice.

## What it is
ISO 27002 is **non-certifiable guidance** — you can't get certified to 27002, only to 27001. But 27002 is the practical handbook ISMS implementers use daily because it explains *how* to implement each Annex A control. Treating 27002 as the certifiable standard is a frequent confusion.

The 2022 version (current) supersedes 27002:2013. Organisations already certified to 27001:2013 must transition to 27001:2022 (Annex A pulled from 27002:2022) by October 2025.

## Structure — 4 themes, 93 controls

| Clause | Theme | Controls |
|---|---|---|
| 5 | Organisational | 37 |
| 6 | People | 8 |
| 7 | Physical | 14 |
| 8 | Technological | 34 |

Each control has:
- Title and control statement
- Purpose
- Guidance (implementation detail)
- Other information (background, related standards)
- 5 attributes (introduced in 2022):
  - **Control type** — preventive / detective / corrective
  - **Information security properties** — confidentiality / integrity / availability
  - **Cybersecurity concepts** — identify / protect / detect / respond / recover (NIST CSF alignment)
  - **Operational capabilities** — governance / asset management / IAM / etc.
  - **Security domains** — governance / protection / defence / resilience

Attributes are filterable — produce a control subset by attribute combination (e.g., "all detective controls in the protect concept").

## The 11 new controls (2022 vs 2013)

1. **5.7 Threat intelligence** — formalises TI program
2. **5.23 Information security for use of cloud services** — cloud-specific
3. **5.30 ICT readiness for business continuity** — BC scoped to ICT
4. **7.4 Physical security monitoring** — CCTV, alarms, motion
5. **8.9 Configuration management** — baseline + drift detection
6. **8.10 Information deletion** — secure deletion across lifecycle
7. **8.11 Data masking** — pseudonymisation / anonymisation
8. **8.12 Data leakage prevention** — DLP tooling expected
9. **8.16 Monitoring activities** — proactive monitoring + behaviour analytics
10. **8.23 Web filtering** — block known-bad domains
11. **8.28 Secure coding** — secure SDLC practice

These reflect what modern security teams already do — codifying it makes auditors verify it.

## Mapping old → new
27002:2013 had 114 controls. 27002:2022 has 93 controls because:
- 24 controls merged
- 1 control split
- 58 controls renumbered
- 11 new controls added
- Net: -21 from merging

The transition matrix is published as ISO/IEC 27002:2022 Annex B. Use it to remap your existing Statement of Applicability (SoA).

## Implementation tradecraft

**Step 1 — Read the controls actually relevant to you, not all 93.** Use attribute filtering. For SaaS startup: focus on technological controls (Clause 8) + key org controls (5.7 threat intel, 5.23 cloud).

**Step 2 — Write SoA against 27002:2022, not 2013.** If you're new, start with 2022. If you have a 2013 SoA, use Annex B mapping.

**Step 3 — Evidence per control.** Auditors verify implementation through:
- Policy documents (lead with these)
- Process artifacts (tickets, reviews, training records)
- Technical configurations (screenshots, system reports)
- Logs / monitoring records
- Interviews (control owner explains the process)

**Step 4 — Risk-based control depth.** 27002 guidance ranges from one paragraph to multiple pages. Pick depth proportional to risk:
- Low-risk control: implement the minimum guidance, document the rationale
- High-risk control: implement the full guidance, add organisation-specific extensions

**Step 5 — Cross-cutting controls** that touch many areas:
- **5.31 Legal, statutory, regulatory, contractual** — keep a register; GDPR, DORA, NIS2, sector regs land here
- **5.32 Intellectual property rights** — license inventory
- **5.34 Privacy and protection of PII** — bridges to 27701
- **6.3 Information security awareness, education and training** — annual + role-specific
- **8.16 Monitoring activities** — proactive SOC integration

## Common implementation pitfalls

- **Copy-paste policy templates** without tailoring — auditors notice immediately
- **Treating SoA as static** — must be reviewed annually + after major changes
- **Missing exclusions justification** — every "not applicable" needs a documented reason
- **Conflating 27002 control text with 27001 Annex A** — 27001 Annex A is normative (mandatory); 27002 is guidance (informative)
- **Annex A "control" written in 1 sentence** — 27001 Annex A controls are intentionally short; the implementation detail is in 27002
- **Confusing 2022 transition deadline** — Oct 31, 2025 for certificates; surveillance audits after Apr 30, 2024 require 2022 compliance

## Frequently-mis-implemented controls

- **8.16 Monitoring** — auditors expect proactive analytics, not just log retention
- **8.28 Secure coding** — needs documented secure SDLC + training + verification (SAST/code review)
- **5.7 Threat intelligence** — requires structured TI process, not "we read blogs"
- **5.23 Cloud services** — shared-responsibility documented per provider, not a single one-size statement
- **8.12 DLP** — auditors check for ACTUAL DLP rule effectiveness, not just the licence
- **7.4 Physical monitoring** — covers remote workers' home offices in many SoAs (contentious)

## Tooling that helps

- **Vanta / Drata / Secureframe** — automate evidence collection mapped to controls
- **ISO 27002 Excel exports** from community repos — start with attribute-tagged spreadsheet
- **CIS Controls v8 → 27002 mapping** — useful if you've adopted CIS as the technical baseline
- **NIST 800-53 → 27002 mapping** — for orgs straddling US federal and international

## OPSEC for compliance team

- The SoA is the central artifact — keep it under version control
- Track control evidence with timestamps; surveillance audits are quarterly/annual
- Decisions to NOT implement a control should reference risk treatment, not "we don't have budget"
- Mock audit before real audit — your internal auditor or hired consultant walks the SoA exactly like the certification body will

## References
- [ISO/IEC 27002:2022](https://www.iso.org/standard/75652.html) — purchase from ISO
- [ISO/IEC 27001:2022](https://www.iso.org/standard/27001) — the certifiable standard
- [Transition guide ISO/IEC 27001:2013 → 2022](https://www.iaf.nu/) — IAF Mandatory Document MD 26
- [Annex A → 27002 control mapping](https://www.iso27001security.com/) — practitioner community resources

See also: [[building-an-iso27001-isms-practitioner]], [[iso-27001-lead-auditor-certification]], [[soc2-vs-iso27001]], [[iso-42001-ai-management-system]], [[iso-27701-privacy-extension]], [[iso-22301-business-continuity]], [[nist-csf-2-implementation]], [[appsec-maturity-checklist]], [[policy-and-standards-writing]]
