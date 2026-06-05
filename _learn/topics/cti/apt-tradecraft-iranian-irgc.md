---
title: Iranian APT tradecraft (IRGC / MOIS)
slug: apt-tradecraft-iranian-irgc
aliases: [iranian-apt, irgc-tradecraft, apt33, apt34, apt35]
---

> **TL;DR:** Iranian state cyber operations are conducted by the **Islamic Revolutionary Guard Corps (IRGC)** Intelligence Organisation and the **Ministry of Intelligence and Security (MOIS)**, plus IRGC-Aerospace Force–linked contractors. Public attribution: **APT33 / Refined Kitten / Holmium** (IRGC, energy / petrochemical / aerospace), **APT34 / OilRig / Helix Kitten** (MOIS, broad espionage), **APT35 / Charming Kitten / Mint Sandstorm** (IRGC, journalists / activists / civil society), **MuddyWater / Static Kitten** (MOIS). Patterns: spear-phishing of specific industries / individuals, mid-sophistication implants, occasional disruptive operations. Companion to [[apt-tradecraft-russian-svr-fsb]] and [[apt-tradecraft-chinese-mss]].

## Why study this

- Iranian cyber operations are **regional-conflict adjacent** — escalations track geopolitics.
- **Civil-society targeting** is heavier than other major actors — activists, journalists, dissidents.
- **Increasingly disruptive** — recent Albania (2022), water-utility (2023) targeting.
- **Mid-tier tradecraft** — competent but less sophisticated than Russian / Chinese top tier; relies on volume + opportunity.

## Agency split

### IRGC (Islamic Revolutionary Guard Corps)

- Military, paramilitary, ideological force.
- Has its own intelligence apparatus.
- **APT33** (IRGC) — energy, aerospace, petrochemical.
- **APT35** (IRGC) — journalists, dissidents, civil society.
- **IRGC Aerospace Force** — has cyber units.

### MOIS (Ministry of Intelligence and Security)

- Civilian intelligence.
- **APT34 / OilRig** — broad espionage.
- **MuddyWater** — broad espionage; financial-sector touches.

### IRGC contractors

Multiple cybersecurity contractors operate on IRGC behalf:
- Najee Technology, Afkar System, Mahak Rayan Afraz documented in DOJ indictments.

## APT33 / Refined Kitten tradecraft

### Initial access

- **Spear-phishing** with industry-specific lures (oil/gas conferences, engineering job offers).
- **Watering-hole** at industry sites.

### Tooling

- **TURNEDUP** — custom backdoor.
- **POWERTON** — PowerShell-based.
- **DROPSHOT / SHAPESHIFT** — wiper variants (rare for Iran to deploy).

### Targeting

- Aerospace / defence contractors (US, Saudi Arabia).
- Petrochemical / oil and gas.
- Government / military related to Iran's regional interests.

## APT34 / OilRig tradecraft

### Initial access

- **Spear-phishing** with HR / business documents.
- **DNS tunnelling** for C2.

### Tooling

- **Helminth / ISMDoor** — backdoors.
- **POWRUNER**.
- **BONDUPDATER** — DNS-based C2.

Multiple OilRig tools were leaked publicly (2019 Lab Dookhtegan leak), giving CTI community detection signatures.

### Targeting

- Middle Eastern governments, financial-services, telecom.
- US / Western targets in oil/gas.

## APT35 / Charming Kitten / Mint Sandstorm tradecraft

### Initial access

- **Spear-phishing** to journalists, academics, dissidents, expats.
- **Account-takeover** of Gmail / Twitter / similar.
- **Tracking-pixel** in emails.
- **Fake conferences / fellowships** as pretext.

### Tooling

- **HYPERSCRAPE** — extracts emails from compromised accounts.
- **Custom Android implants** for activist targeting.
- **Cobalt Strike** observed.

### Targeting

- Journalists covering Iran.
- Academic researchers studying Iran.
- Dissidents in diaspora.
- Civil-society organisations.
- US 2020 election-related targeting reported.

## MuddyWater / Static Kitten tradecraft

### Initial access

- **Spear-phishing** with malicious Office documents.
- **Living off the Land** — PowerShell heavy.

### Tooling

- **PowGoop**, **PowerStats**.
- **CrutchCommand** loader.
- **Customised Cobalt Strike** beacons.

### Targeting

- Government / telecom in Middle East, North Africa, Central Asia.
- More recently Western targets.

## Notable disruptive operations

- **Shamoon / DistTrack (2012, 2016, 2018)** — wiper attacks against Saudi Aramco and others.
- **Albania (2022)** — IRGC-attributed; sustained disruptive operation against Albanian government.
- **Water utilities (2023)** — IRGC-attributed; targeting of Unitronics PLCs at Western utilities including Aliquippa Pennsylvania.
- **Israeli-Iranian conflict cycle** — sustained mutual cyber operations.

## Common defensive priorities

For organisations in scope:

- **Civil society / journalists**: account-security hardening, hardware tokens, Lockdown Mode for iOS.
- **Energy / petrochemical**: aggressive edge-appliance patching, OT segmentation.
- **Wider**: MFA universally, EDR, behavioural detection of PowerShell / DNS tunnelling.

## Detection inspiration (ATT&CK)

- T1071.004 (DNS) — DNS tunnelling.
- T1566 (Phishing).
- T1059.001 (PowerShell).
- T1110.003 (Password Spraying).
- T1003 (OS Credential Dumping).

## Recent shifts

- **IRGC water-utility targeting (2023)** — Unitronics PLC defaults in Aliquippa PA; PLC interface modified to show pro-Hamas message.
- **Hacktivist front groups** — IRGC operates / orchestrates "hacktivist" groups for plausible deniability.
- **Albania post-incident** — Albania severed diplomatic relations with Iran over cyber operations.

## Workflow to study

1. Read CISA / FBI / Mandiant / Microsoft Iranian-APT advisories.
2. Read 2019 Lab Dookhtegan OilRig leak analyses.
3. Map your sector exposure to Iranian targeting.
4. For civil-society / NGO defence — Access Now / EFF have hardening guides.
5. Conduct purple-team for Iranian-TTP-likely paths.

## Real-world incidents

- **Shamoon (2012)** — wiper at Saudi Aramco.
- **Sands Casino (2014)** — IRGC-attributed.
- **Multiple US-individual financial-fraud / espionage operations** — DOJ-indicted.
- **Albania (2022)** — sustained operation.
- **Water-utility 2023** — Aliquippa, others.

## Related

- [[apt-tradecraft-russian-svr-fsb]]
- [[apt-tradecraft-chinese-mss]]
- [[apt-tradecraft-dprk-lazarus]]
- [[ransomware-affiliate-playbook]]
- [[ics-scada-protocols-attacks]]
- [[case-study-okta-2023-support-system]] — adjacent
- [[detection-engineering-pyramid-of-pain]]
- [[cti-collection-management]]

## References
- [CISA — Iranian APT advisories](https://www.cisa.gov/news-events/cybersecurity-advisories)
- [Mandiant / Microsoft TI — Iran reports](https://cloud.google.com/blog/topics/threat-intelligence)
- [Microsoft — Mint Sandstorm reports](https://www.microsoft.com/en-us/security/blog/)
- [Citizen Lab — Charming Kitten / NSO comparison](https://citizenlab.ca/)
- [DOJ Iranian-cyber indictments archive](https://www.justice.gov/)
- See also: [[apt-tradecraft-russian-svr-fsb]], [[apt-tradecraft-chinese-mss]], [[apt-tradecraft-dprk-lazarus]], [[ransomware-affiliate-playbook]]
