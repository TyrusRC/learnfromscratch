---
title: Chinese APT tradecraft (MSS / PLA)
slug: apt-tradecraft-chinese-mss
aliases: [chinese-apt, mss-apt, pla-tradecraft, apt10, apt40, apt41]
---

> **TL;DR:** Chinese state-aligned cyber operations are conducted by the **Ministry of State Security (MSS)** and **People's Liberation Army Strategic Support Force (PLA SSF)**, plus contractor "i-Soon"-style hire-out shops. Public attribution: APT10 / Stone Panda (MSS), APT40 / Leviathan (MSS Hainan), APT41 / Barium (MSS contractor, dual espionage + cybercrime), Volt Typhoon (PLA, OT-pre-positioning), Salt Typhoon (PLA, telco). Patterns: edge-appliance N-day exploitation, "Living off the Land" on victim networks for stealth, focus on Intellectual Property + IP-rich targets. Companion to [[apt-tradecraft-russian-svr-fsb]] and [[cve-2024-3094-xz-utils-backdoor]].

## Why study this

- China conducts the largest volume of public-attributable cyber-espionage.
- Targets include IP-rich industries (aerospace, pharma, semiconductors, defence), critical infrastructure pre-positioning, telco / ISP intelligence.
- Tradecraft is **distinctive** — heavy use of edge-appliance exploitation, supply-chain, living-off-the-land.
- Recent (2024+) shift from espionage-only to OT pre-positioning (Volt Typhoon) is strategically significant.

## Agency / actor split

### MSS — Ministry of State Security

- Civilian intelligence; regional bureau structure.
- **APT10 / Stone Panda / MenuPass** — MSS Tianjin Bureau.
- **APT40 / Leviathan / TA423** — MSS Hainan State Security Department.
- **APT41 / Barium / Winnti / Wicked Panda** — MSS contractor; dual espionage + financially-motivated cybercrime; multiple sub-groups.
- **APT31 / Zirconium** — MSS-attributed (Microsoft).

### PLA — People's Liberation Army (Strategic Support Force / Cyberspace Force)

- Military focus, increasingly critical-infrastructure targeting.
- **Volt Typhoon** — PLA-attributed (Microsoft, CISA), pre-positions in US critical infrastructure (water, electricity, communications, transportation).
- **Salt Typhoon** — PLA-attributed, telco/ISP-focused.
- **Flax Typhoon** — botnet / persistence.
- **Granite Typhoon**, others.

### Contractors

- **i-Soon (Shanghai)** — 2024 leak revealed contractor operations across multiple campaigns.
- Multiple cybersecurity / IT contractors run operations on MSS / PLA behalf.

## MSS-typical tradecraft (APT10, APT40, APT41)

### Initial access

- **Spear-phishing** — sector-tailored lures.
- **Edge-appliance N-day** — Fortinet, Pulse Secure / Ivanti, Citrix, F5, Cisco. Rapid weaponisation after disclosure.
- **MSP / IT vendor compromise** — APT10 famous for "Cloud Hopper" — compromised IT MSPs to reach customers.
- **Supply chain** — software vendor compromise (e.g., ASUS Live Update, CCleaner).
- **Watering-hole** for high-value individuals.

### Persistence / lateral movement

- **Web shells** (China Chopper, ChinaChopper, more recent variants).
- **Living off the Land** — heavy use of `certutil`, `bitsadmin`, `wmic`, `mshta`, `rundll32`.
- **Stolen credentials** — extensive Mimikatz / Kerberoasting / DCSync.
- **Backdoored utilities** — modify legitimate admin tools.
- **Domain replication** abuse — APT41 famous for using EDR-blind tradecraft.

### Tooling

- **PlugX / Korplug** — modular RAT used by many MSS groups since 2008+.
- **ShadowPad** — modular RAT (sold; used widely).
- **Winnti malware** — Linux + Windows; APT41 signature.
- **Cobalt Strike** (cracked) — widely used.
- **Custom implants per campaign**.

### Targeting (MSS)

- Aerospace, defence contractors, semiconductors, biotech / pharma, MSPs, law firms, foreign-affairs ministries, dissidents / journalists.

## PLA-typical tradecraft (Volt Typhoon, Salt Typhoon)

### Volt Typhoon — OT pre-positioning

- **Edge router compromise** — SOHO router botnet (KV-botnet) as launch infrastructure.
- **Living off the Land** — minimal custom tooling. Native Windows commands.
- **Credential theft from edge devices** — VPN appliances, firewalls.
- **Persistence in OT networks** without immediate destructive action — pre-positioning for future conflict.
- **Targets**: water utilities, electric utilities, communications, transportation.
- CISA / Five Eyes treat as **highest-priority threat** for US CNI.

### Salt Typhoon — Telco

- **Telecom carriers** as primary target.
- **Cisco / Juniper / Fortinet** edge-router exploitation.
- **Routing / signalling intelligence** harvest.
- **Lawful-intercept system abuse** reported.
- 2024 US Senate / FCC investigation of US carrier compromises traces to this.

## Living off the Land emphasis

Chinese tradecraft notably leans on built-in tools:

- `netsh wlan show profile` (Wi-Fi creds).
- `wmic` for query / management.
- `certutil` for download.
- `bitsadmin` for download.
- `wevtutil` for log manipulation.
- Native PowerShell / cmd / WMI for execution.

Reduces malware signature detection but increases behavioural-detection opportunity.

## Common defensive priorities

For organisations in scope:

- **Edge-appliance patching** as priority — Volt/Salt Typhoon both opportunistic on N-days.
- **EDR with behavioural rules** for LotL tradecraft.
- **Identity tier-0** protection.
- **OT network segmentation** + monitoring (Volt Typhoon threat).
- **Telco / ISP-side** — ROV (RPKI), out-of-band management, frequent rotation of admin creds.
- **MSP / vendor risk** — supply-chain assessment.
- **Behavioural detection** of LotL commands at scale.

## i-Soon leak insights

In 2024, internal documents from i-Soon were leaked publicly:
- Revealed scope of contractor operations.
- Per-target operations against governments (India, UK, Taiwan, Mongolia, Malaysia, etc.).
- Tooling catalogue (web shells, backdoors, infrastructure-rental services).
- Pricing for operations.

Confirmed widely-held suspicions about scale and organisation.

## Detection inspiration (ATT&CK)

- T1078 (Valid Accounts) — sustained sign-ins from unusual ASNs.
- T1133 (External Remote Services) — edge-appliance VPN abuse.
- T1059 (Command and Scripting Interpreter) — LotL.
- T1098 (Account Manipulation).
- T1003 (OS Credential Dumping) — Mimikatz / SAM dumping.
- T1218 (System Binary Proxy Execution) — Mshta, Rundll32.

## Workflow to study

1. Read CISA advisories on Volt Typhoon, Salt Typhoon, APT10 Cloud Hopper.
2. Read i-Soon leak analysis (multiple researchers published).
3. Read MITRE ATT&CK profiles for the named groups.
4. Map your environment exposure to typical MSS tradecraft.
5. Run Atomic Red Team for relevant T-codes.

## Real-world incidents

- **APT10 Cloud Hopper** (disclosed 2017) — MSP-based mass access.
- **APT40 / Anchor Panda** (2017+) — maritime / academic targeting.
- **APT41 / Barium** — supply-chain (ASUS, CCleaner), Microsoft Exchange ProxyLogon involvement.
- **Hafnium / Microsoft Exchange ProxyLogon** (2021) — attributed to Chinese state.
- **Volt Typhoon** (disclosed 2023) — ongoing.
- **Salt Typhoon** (disclosed 2024) — telco compromise.

## Related

- [[apt-tradecraft-russian-svr-fsb]]
- [[apt-tradecraft-dprk-lazarus]]
- [[apt-tradecraft-iranian-irgc]]
- [[ransomware-affiliate-playbook]]
- [[case-study-3cx-supply-chain]] — DPRK but adjacent supply-chain shape
- [[cve-2024-3094-xz-utils-backdoor]] — adjacent class
- [[detection-engineering-pyramid-of-pain]]
- [[cti-collection-management]]
- [[living-off-the-land]]

## References
- [CISA — Volt Typhoon advisory](https://www.cisa.gov/news-events/cybersecurity-advisories/aa24-038a)
- [Microsoft Threat Intelligence — Typhoon family blog posts](https://www.microsoft.com/en-us/security/blog/)
- [Mandiant — APT41 reports](https://cloud.google.com/blog/topics/threat-intelligence)
- [MITRE ATT&CK — APT10 (G0045), APT41 (G0096)](https://attack.mitre.org/)
- [i-Soon leak analysis (Sentinel Labs, Mandiant, others)](https://www.sentinelone.com/labs/)
- See also: [[apt-tradecraft-russian-svr-fsb]], [[apt-tradecraft-dprk-lazarus]], [[detection-engineering-pyramid-of-pain]], [[cti-collection-management]]
