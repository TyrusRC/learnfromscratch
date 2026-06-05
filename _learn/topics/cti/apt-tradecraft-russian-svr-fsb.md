---
title: Russian APT tradecraft (SVR / FSB / GRU)
slug: apt-tradecraft-russian-svr-fsb
aliases: [russian-apt, svr-apt29, fsb-apt28, gru-tradecraft]
---

> **TL;DR:** Russian state-aligned cyber operations are conducted by three intelligence agencies — **SVR** (foreign intelligence, civilian, methodical espionage), **FSB** (internal security, but also Center 16 / "Turla" foreign cyber-espionage), and **GRU** (military intelligence, disruptive operations). Public attribution: APT29 / Cozy Bear / Midnight Blizzard = SVR; APT28 / Fancy Bear = GRU 26165; Sandworm / Voodoo Bear = GRU 74455; Turla / Snake = FSB Center 16. Companion to [[apt-tradecraft-chinese-mss]] and [[case-study-solarwinds-2020]].

## Why study this

- Russian operations target intelligence, defence, governments, critical infrastructure.
- Tradecraft is **well-documented** by Western CTI — Mandiant, CrowdStrike, Microsoft, ESET, NCC.
- **Defining incidents**: SolarWinds (SVR), Ukraine power grid (GRU), DNC 2016 (GRU).
- Understanding tradecraft helps build detections and predict future targeting.

## Agency split

### SVR (Sluzhba Vneshney Razvedki)

- Foreign intelligence, civilian.
- APT29 / Cozy Bear / **Midnight Blizzard** (Microsoft naming).
- Patient, deeply operational, focuses on persistent espionage access.

### FSB (Federalnaya Sluzhba Bezopasnosti)

- Internal security but Center 16 conducts foreign cyber-espionage.
- Turla / Snake / Venomous Bear.
- Long-running cyberespionage; sophisticated implants.

### GRU (Glavnoye Razvedyvatel'noye Upravleniye)

- Military intelligence.
- Multiple units:
  - **26165** = APT28 / Fancy Bear (espionage, government / military / political targeting).
  - **74455** = Sandworm / Voodoo Bear (disruptive operations — Ukraine, NotPetya).
  - **29155** = recent grouping linked to physical operations + cyber.
- More willing to do disruptive / destructive operations than SVR.

## SVR / Midnight Blizzard tradecraft

### Initial access

- **Spear-phishing** with carefully tailored lures.
- **Software supply chain** compromise (SolarWinds SUNBURST).
- **Credential reuse** from breaches.
- **OAuth consent phishing** against M365.

### Persistence / lateral movement

- **Identity compromise** — focus on cloud identity (Entra ID, Okta).
- **Golden SAML** (post-SolarWinds standard).
- **Refresh token theft** with broad scope.
- **Mailbox forwarding rules**.
- **App-registration creation** with high-priv scopes.
- **Multi-tenant identity abuse**.

### Stealth

- **Cloud-native tools** — operate via Microsoft Graph, AWS, Google APIs.
- **Long dwell times** — months to years.
- **Low-volume** activity, blends with normal admin.
- **Use of trusted infrastructure** — operates from compromised legitimate tenants.

### Tooling

- **TEARDROP**, **RAINDROP** — Cobalt Strike loaders (SolarWinds era).
- **MagicWeb** — IIS module backdoor for AD FS / Entra.
- **WellMess / WellMail** — Go-language implants.
- **Sliver** observed.

### Targeting

- Government, defence, NGO, think tanks, COVID research (during pandemic), election infrastructure.

## GRU 26165 / APT28 tradecraft

### Initial access

- **Spear-phishing** with passwords-stolen lures.
- **Password spray** against M365 / O365.
- **Watering-hole** attacks against political sites.
- **VPN / firewall exploitation** opportunistic.

### Tooling

- **X-Agent** / **Sofacy**.
- **X-Tunnel**.
- **CHOPSTICK** (Windows / Linux / Android variants).
- **GooseEgg** (CVE-2022-38028 print spooler exploitation).

### Targeting

- Defence, foreign affairs, election interference, journalism, anti-doping (WADA).

## GRU 74455 / Sandworm tradecraft

### Initial access

- **Spear-phishing** primary.
- **Edge-appliance exploitation** (in disruptive campaigns).
- **Supply-chain** via Ukrainian MEDoc accounting software (NotPetya 2017).

### Disruptive payloads

- **BlackEnergy** (Ukraine 2015 grid).
- **Industroyer / Industroyer2** (Ukraine grid 2016, attempted 2022).
- **NotPetya / EternalPetya** (2017).
- **VPNFilter** (router compromise).
- **Olympic Destroyer** (PyeongChang 2018).
- **AcidRain** (Viasat 2022 — see [[ground-station-attacks]]).
- **WhisperGate / HermeticWiper / IsaacWiper** (Ukraine 2022).
- **CaddyWiper** (Ukraine 2022).

### Targeting

- Critical infrastructure during active conflicts; Olympic Games; transport.
- Disruption-focused; not stealth.

## Turla / FSB Center 16 tradecraft

### Initial access

- Watering-hole.
- Compromised infrastructure of third parties to host C2.
- **Satellite-based C2** (geographic-unique) — early Turla used hijacked satellite IP space.

### Tooling

- **Snake** / **Uroburos** — kernel rootkit. Long-running, sophisticated.
- **ComRAT**.
- **Kazuar**.
- **Capibar**.

### Stealth

- **Custom protocols** over legitimate-looking transport.
- **Compromise of third-party infrastructure** for C2.
- **Code reuse minimised** — Turla's tools are distinctive each campaign.

### Targeting

- Government foreign-affairs, defence ministries, embassies. Long-term espionage.

## Common defensive priorities

For organisations potentially in scope:

- **Strong identity** — Phish-resistant MFA, Conditional Access, Identity Protection.
- **Cloud-native logging** — Graph API audit, Defender for Cloud Apps.
- **Supply-chain auditing** — SBOM, provenance.
- **SAML token-signing key protection** — HSM-bound.
- **Mail flow rule auditing** — unusual forwarders.
- **OAuth consent governance** — strict app approval workflow.
- **EDR coverage** — endpoint plus identity plus network.
- **External CTI feeds** — Mandiant, Microsoft TI, ESET, CrowdStrike, sector-specific.

## Detection inspiration (mapped to ATT&CK)

- T1078 (Valid Accounts) — sign-in anomalies.
- T1098 (Account Manipulation) — Mail rules, new app registrations.
- T1606 (Forge Web Credentials) — Golden SAML detection.
- T1538 (Cloud Service Dashboard) — Graph API enumeration.

CTI providers publish Russian-actor-specific detection content.

## Workflow to study

1. Read MITRE ATT&CK profile for APT28, APT29, Sandworm, Turla.
2. Read Mandiant / Microsoft / CrowdStrike attribution reports.
3. Subscribe to CISA advisories.
4. Map your environment against each actor's known TTPs.
5. Run Atomic Red Team tests aligned with their TTPs.

## Real-world incidents tied to each

- **Midnight Blizzard / SolarWinds (2020)** — see [[case-study-solarwinds-2020]].
- **APT28 / DNC 2016, Bundestag 2015, MH17 OPCW operations**.
- **Sandworm / NotPetya 2017, Ukraine grid 2015/2016, Viasat 2022**.
- **Turla / Pacifier, ComRAT campaigns** ongoing.

## Related

- [[apt-tradecraft-chinese-mss]]
- [[apt-tradecraft-dprk-lazarus]]
- [[apt-tradecraft-iranian-irgc]]
- [[ransomware-affiliate-playbook]]
- [[case-study-solarwinds-2020]]
- [[case-study-3cx-supply-chain]]
- [[detection-engineering-pyramid-of-pain]]
- [[cti-collection-management]]
- [[ground-station-attacks]]

## References
- [Microsoft Threat Intelligence — Midnight Blizzard reports](https://www.microsoft.com/en-us/security/blog/)
- [Mandiant — APT29 / APT28 reports](https://cloud.google.com/blog/topics/threat-intelligence)
- [MITRE ATT&CK — APT29 (G0016)](https://attack.mitre.org/groups/G0016/)
- [CISA advisories on Russian state actors](https://www.cisa.gov/news-events/cybersecurity-advisories)
- [ESET — Turla research](https://www.welivesecurity.com/)
- See also: [[apt-tradecraft-chinese-mss]], [[apt-tradecraft-dprk-lazarus]], [[case-study-solarwinds-2020]], [[ransomware-affiliate-playbook]]
