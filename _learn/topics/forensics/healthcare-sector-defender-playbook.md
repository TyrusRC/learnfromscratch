---
title: Healthcare sector defender playbook
slug: healthcare-sector-defender-playbook
aliases: [healthcare-defender, hospital-cyber-playbook]
---

> **TL;DR:** Defending hospitals and health systems is a unique sub-discipline of security: regulatory overlay from HIPAA / HITECH / FDA medical-device guidance, a threat landscape where ransomware crews specifically target healthcare because uptime equals life-safety, and a fleet of legacy modalities and shared clinician workstations that cannot be patched or locked down like a normal enterprise. This note is a practitioner playbook for healthcare blue-teamers — what to actually do day to day. Pairs with [[hipaa-security-rule]] for the regulatory side, [[ransomware-affiliate-playbook]] for the adversary side, [[case-study-moveit-2023]] for a third-party blast-radius example, [[ueba-detection-ml-primer]] for detecting EHR insider misuse, and [[ir-from-source-signals]] for the IR muscle.

## Why it matters

Healthcare has become the most-attacked critical-infrastructure sector by several measures:

- **Ransomware impact is amplified.** When a manufacturer goes down for a week, products don't ship. When a hospital goes down for a week, patients are diverted, surgeries are cancelled, mortality measurably rises. Excess-mortality studies after the 2020 Universal Health Services and 2024 Ascension incidents found real patient-care degradation.
- **Change Healthcare (Feb 2024)** — UnitedHealth subsidiary, ALPHV/BlackCat affiliate. Prescription processing for a large fraction of US pharmacies halted. UnitedHealth disclosed paying ~$22M ransom; total cost guidance crossed $2.4B. Notification letters went to ~190M people, the largest US health breach in history.
- **Ascension (May 2024)** — Black Basta. 142 hospitals diverted ambulances and reverted to paper for weeks. Phishing entry vector via a contractor-laptop browser download.
- **NHS trusts** — Synnovis (June 2024, Qilin) disrupted blood testing across London trusts; WannaCry (2017) before that famously hit ~80 trusts.
- **Regulatory clock is short.** HIPAA breach notification: 60 days from discovery to notify affected individuals (and HHS / media if 500+ residents of a state). State laws layer additional clocks. EU GDPR is 72 hours — see [[gdpr-incident-implications]].
- **You inherit a fleet you didn't buy.** MRI from 2011 running Windows XP Embedded that the vendor won't let you touch without voiding the service contract. Infusion pumps with hardcoded creds. This is the actual job.

## Regulatory overlay (practitioner view)

This is **not** legal advice — talk to your privacy officer / counsel. But security-team members need to know which rules drive which controls.

### HIPAA Security Rule

Three buckets of safeguards — Administrative, Physical, Technical. Each is either Required or Addressable (addressable means "do it or document why an equivalent control is in place," not "optional"). See [[hipaa-security-rule]] for the detailed control mapping. The Jan 2025 NPRM proposes removing the Required/Addressable distinction and making MFA, encryption-at-rest, asset inventory, and annual pentest explicit.

### HITECH

Layered on top of HIPAA in 2009. Two things to know:

- Breach notification rule (60 days, written notice, plus HHS "Wall of Shame" if 500+ records).
- Higher penalties + state AG enforcement authority. OCR penalty tiers go up to roughly $2M per violation type per year.

### State breach laws

All 50 US states have their own. Some shorter than 60 days (e.g., Texas 60 days; some require 30). California (CMIA) covers medical info specifically and predates HIPAA breach rules. New York SHIELD and the NYDFS 23 NYCRR 500 apply if you're a payer.

### FDA medical-device cybersecurity guidance

- **Premarket (2023 guidance, refresh 2025)** — Manufacturers must include an SBOM, threat model, and vulnerability-handling plan in 510(k) submissions. Section 524B of the FD&C Act made cybersecurity mandatory for "cyber devices."
- **Postmarket (2016 / refresh 2025)** — Vendors must monitor for vulns and patch coordinated-disclosure style. In practice you, the hospital, still wait months for a patch.
- **Hospitals are not regulated by FDA** for device security — but you inherit the consequence when a vendor refuses to patch a CT scanner because it would re-trigger FDA clearance.

## Threat landscape

### Who actually targets healthcare

- **Big-game ransomware affiliates.** ALPHV/BlackCat (now defunct after the Change Healthcare exit-scam), Black Basta, LockBit, Qilin, Rhysida, INC Ransom. See [[ransomware-affiliate-playbook]].
- **Initial-access brokers** selling Citrix / RDP / VPN access into US health systems on Russian-language forums. Price spikes for "US hospital, $1B revenue."
- **DPRK** for IP theft (vaccine research, oncology data) and crypto-funded ransomware (Maui, H0lyGh0st). See [[apt-tradecraft-dprk-lazarus]].
- **Insider misuse** — clinicians snooping on celebrity records, ex-spouse records, neighbor records. Detected with UEBA on EHR access logs — see [[ueba-detection-ml-primer]].

### Common entry vectors

| Vector | Reality |
| --- | --- |
| Phishing on shared clinician workstations | Most common. AiTM / Evilginx defeats SMS MFA. See [[aitm-evilginx-modern-phishing]]. |
| VPN / Citrix exposed without phishing-resistant MFA | Change Healthcare reportedly entered via Citrix without MFA. |
| Third-party / business-associate compromise | Synnovis pathology to NHS, Welltok 2023, NRC Health. |
| Vulnerable network appliance | Ivanti Connect Secure, Fortinet, Citrix Bleed (CVE-2023-4966). |
| Medical-device pivot | Rare as initial vector, common as lateral. Devices on flat networks see everything. |

## The uptime vs security tension

This is the cultural reality you have to internalize:

- **Life-safety beats confidentiality, every time.** If your EDR quarantines a script the radiology PACS needs and a stroke scan is delayed, you will be in a serious conversation. Tune accordingly.
- **You cannot do a maintenance window on an emergency department.** Patching a critical EHR component during a Friday-night trauma surge will end your career. Plan windows around clinical census.
- **"Break-glass" access is real and abused.** Every EHR has emergency override accounts so a clinician can pull any record in a crisis. They are also used for snooping. Monitor them aggressively.
- **You will be asked to pay the ransom.** Have the calculus pre-decided with executive leadership and board, ideally with counsel and law enforcement coordination (FBI IC3, HHS HC3). OFAC sanctions screening is non-optional — paying a sanctioned group is itself a violation.

## Medical-device (IoMT) security

### What you actually have on the network

- **Imaging modalities** — MRI, CT, X-ray, ultrasound, PACS workstations. Typically Windows-based, 10-20 year service life, vendor controls patching.
- **Infusion pumps** — networked, often WPA2-PSK with hospital-wide key. CVE-laden (BD Alaris, Baxter, Hospira).
- **Patient monitors / telemetry** — often on isolated VLAN but bridged for nurse-station displays.
- **Lab analyzers** — chemistry, hematology, microbiology. Often Windows XP / 7 embedded, FTP-based result transfer.
- **Building / HVAC / pneumatic-tube** — adjacent OT, similar concerns. See [[ics-scada-protocols-attacks]].

### Realistic controls

| Control | How it actually goes |
| --- | --- |
| Network segmentation | Yes, but flat enough that a code-cart laptop can still reach. Use VLANs + ACLs, not just "med-device VLAN exists." |
| Asset inventory | Buy or build a passive medical-device discovery tool (Claroty xDome, Medigate, Armis, Ordr). Most useful single investment. |
| Patching | Vendor-coordinated only on regulated devices. Compensating controls (segmentation, IDS sigs) for the rest. |
| EDR on the device | Almost never possible — voids warranty / FDA clearance. EDR on adjacent workstations is the next best thing. |
| Default-credential remediation | Ongoing battle. Track per device family. |

## EHR system protection

- **Epic / Cerner (Oracle Health) / Meditech** — three vendors account for most US hospitals.
- **Access model** is broad by design (clinicians need any-patient access in an emergency). Detection is on access *patterns*, not access itself.
- **Audit logs** are voluminous and often in vendor-proprietary format. Get them into your SIEM — see [[siem-detection-use-case-catalog]].
- **High-value detections**: same-name / same-address access (snooping), VIP-list access without care relationship, mass-export, off-hours patient lookups by unit clerks, break-glass usage without incident ticket.
- **Insider misuse** is more common than external EHR compromise. Build the UEBA pipeline ([[ueba-detection-ml-primer]], [[time-series-anomaly-for-security]]).

## Third-party / business-associate management

- Every BA (anyone touching PHI on your behalf) needs a Business Associate Agreement (BAA) under HIPAA. The BAA passes obligations down.
- Change Healthcare, Synnovis, Welltok all illustrate that **BA compromise is your incident**. Notification clock still runs.
- Tier your BAs by data volume and clinical criticality. Top tier: pen-test or third-party-attestation review annually, contractual right to audit, defined IR notification SLA (24-72 hours, not "without unreasonable delay").
- Map BAs to clinical workflows so you know what breaks when one goes down. Run tabletops on the top five.

## Breach notification clock

### The 60-day timeline (US HIPAA)

```
Day 0:  Discovery (you know or should have known)
Day 0+: Begin forensics; preserve evidence; initial scoping
Day 7-14: Risk assessment (probability of compromise of PHI)
        4-factor analysis: nature, who used/accessed, was it
        acquired/viewed, mitigation
Day 30-45: Draft notification letters; identify affected
        individuals; counsel + comms review
Day 60: Mail individual notices; if 500+ in any state,
        notify HHS + prominent media outlets in that state
Annual: For <500 incidents, batch report to HHS by Mar 1
```

Common practitioner traps:

- "We don't know yet if PHI was acquired" is **not** an extension. The clock runs from discovery, not from forensic certainty.
- Encrypted data lost is a safe harbor *only* if the key was not also compromised and encryption meets the standard (FIPS 140-2 / -3).
- 500+ triggers HHS Wall of Shame — public list, indefinite. Plan comms.

## Life-safety and ransom-payment calculus

Decide this **before** an incident, document it, get exec + board signoff:

- **Trigger conditions** for considering payment (life-safety threat, no viable recovery in clinical timeframe, OFAC clear).
- **Negotiation authority** — who can authorize, what cap, what attorney / IR firm / negotiation firm.
- **OFAC screening** workflow — Treasury SDN list, geographic indicators (Russia/DPRK/Iran/Cuba). Coordinate with FBI; OFAC has a dual-track advisory.
- **Insurance** — cyber-insurance carrier coordination is mandatory; many policies require pre-approval before payment.
- **Communication** — to staff, patients, media, regulators. Pre-draft templates.

## Common gaps (the ones I find every engagement)

- **Over-permissive clinician access** — every clinician has any-patient access "for emergencies." No proactive monitoring of break-glass usage.
- **Shared workstations with stay-signed-in browsers** — fast-user-switch via badge tap, but browser session persists. Phish one user, get all of them.
- **Legacy modalities with default creds** — `admin/admin` on imaging consoles is shockingly common.
- **No SBOM for medical devices** — vendor won't share, you don't push.
- **Vendor remote-support tunnels** — ScreenConnect, TeamViewer, vendor VPN always-on. Massive lateral-movement surface.
- **MFA only on email** — VPN, Citrix, EHR admin portal, vendor portals often skipped.
- **Untested IR plan** — written for a HIPAA auditor, never run as a tabletop with clinical leadership.
- **DNS / outbound egress unmonitored** — ransomware C2 walks right out.

## Defensive baseline (90-day starter)

1. **Asset inventory of medical devices** via passive discovery tool. Categorize by criticality.
2. **Network segmentation** — minimum: med-device VLAN, EHR VLAN, clinical workstation VLAN, admin VLAN, with ACLs (not just VLAN tags).
3. **Phishing-resistant MFA** on email, VPN, Citrix, EHR admin. FIDO2 where possible; see [[conditional-access-bypass-modern]] for why TOTP isn't enough.
4. **EDR on every workstation and server** with tuned exceptions for clinical apps. Test exception impact before deploying.
5. **EHR audit logs to SIEM** with break-glass + VIP-list + same-surname detections.
6. **Backups** — immutable, offline, restore-tested for EHR + PACS + lab. Quarterly restore exercise.
7. **Tabletop** with clinical leadership (CMO, CNO, ED director). Ransomware scenario, downtime procedures.
8. **BA inventory + tiering** with notification-SLA contractual updates on top-tier BAs.
9. **OFAC + payment-authority pre-decision** with board signoff.
10. **HHS HC3 + FBI Cyber relationship** — pre-incident contacts, not Day 1 cold calls.

## Workflow to study

1. Read [[hipaa-security-rule]] end to end, then map your current controls to it.
2. Read FDA premarket + postmarket cybersecurity guidance (2023/2025).
3. Pull the HHS OCR breach portal (Wall of Shame) — read the last 100 entries, cluster by cause.
4. Read the Change Healthcare and Ascension public post-incident materials.
5. Walk an MRI / CT / lab analyzer in your environment with the biomed engineer. See what's actually on it.
6. Pull 30 days of EHR audit logs into a notebook. Build a same-surname-as-patient detector.
7. Run a ransomware tabletop with the ED director in the room. Watch what breaks.
8. Read [[ransomware-affiliate-playbook]] and [[ir-from-source-signals]] in tandem.

## Related

- [[hipaa-security-rule]]
- [[ransomware-affiliate-playbook]]
- [[case-study-moveit-2023]]
- [[ueba-detection-ml-primer]]
- [[ir-from-source-signals]]
- [[time-series-anomaly-for-security]]
- [[siem-detection-use-case-catalog]]
- [[gdpr-incident-implications]]
- [[apt-tradecraft-dprk-lazarus]]
- [[aitm-evilginx-modern-phishing]]
- [[conditional-access-bypass-modern]]
- [[ics-scada-protocols-attacks]]
- [[detection-engineering-pyramid-of-pain]]

## References

- HHS Office for Civil Rights — HIPAA Security Rule and breach-notification resources: https://www.hhs.gov/hipaa/for-professionals/security/index.html
- HHS Health Sector Cybersecurity Coordination Center (HC3) threat briefs: https://www.hhs.gov/about/agencies/asa/ocio/hc3/index.html
- FDA cybersecurity in medical devices (2023 premarket + postmarket guidance): https://www.fda.gov/medical-devices/digital-health-center-excellence/cybersecurity
- HHS OCR Breach Portal (the "Wall of Shame"): https://ocrportal.hhs.gov/ocr/breach/breach_report.jsf
- HSCC Health Industry Cybersecurity Practices (HICP) 405(d): https://405d.hhs.gov/
- CISA Healthcare and Public Health Sector resources: https://www.cisa.gov/topics/critical-infrastructure-security-and-resilience/critical-infrastructure-sectors/healthcare-and-public-health-sector
