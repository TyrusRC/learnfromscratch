---
title: DPRK / Lazarus tradecraft
slug: apt-tradecraft-dprk-lazarus
aliases: [lazarus-group, dprk-apt, kim-jong-un-cyber, andariel, kimsuky]
---

> **TL;DR:** North Korean cyber operations support the regime's strategic goals: **financial theft** (~$3B+ stolen cryptocurrency 2017-2024) to fund nuclear program, **espionage** against defectors / foreign governments / defence, and **counterintelligence**. Multiple groups under the **Reconnaissance General Bureau (RGB)** umbrella: **Lazarus / APT38** (financial), **Kimsuky / Velvet Chollima** (espionage), **Andariel / Stonefly** (financial + espionage), **APT37 / ScarCruft** (espionage). Companion to [[apt-tradecraft-chinese-mss]] and [[case-study-3cx-supply-chain]].

## Why study this

- North Korean ops are **financially-motivated at state level** — uniquely focus on stealing crypto / banking funds.
- The 3CX 2023 incident ([[case-study-3cx-supply-chain]]) was DPRK; defining cascading supply-chain case.
- Crypto-industry exposure to DPRK is large; defending crypto firms requires understanding.
- Cross-platform tradecraft (Windows / macOS / Linux) due to ecosystem diversity.

## RGB sub-groups

### Lazarus / APT38 / Hidden Cobra (financial)

- Operates against banks, crypto exchanges, financial-services providers.
- Defining incident: Bangladesh Bank SWIFT theft 2016 ($81M).
- Crypto theft: Axie Infinity / Ronin 2022 ($625M), Atomic Wallet 2023, several other exchanges.
- WannaCry 2017 attributed to broader Lazarus.

### Kimsuky / Velvet Chollima / Black Banshee (espionage)

- Spear-phishing campaigns against:
  - Defectors / human-rights activists.
  - Defence / military targets.
  - Researchers studying DPRK / Korean affairs.
- Sustained, high-volume phishing.

### Andariel / Stonefly (financial + espionage)

- Defense industrial base targeting.
- Combination espionage + ransomware.
- Maui ransomware attributed.

### APT37 / ScarCruft / Reaper (espionage)

- South Korean target focus.
- 0-day usage observed (Flash, Hangul-Word).

## Common DPRK tradecraft patterns

### Cross-platform implant deployment

DPRK groups maintain Windows / macOS / Linux variants of implants:
- **AppleJeus** — macOS / Windows crypto-themed trojan.
- **VeiledSignal**, **GhostWeapon**.
- **3CXDesktopApp trojan** — multi-platform.

### Crypto-industry-specific tradecraft

- **Job-recruiter pretext** — pose as recruiters; PDF / file is malware.
- **GitHub / npm package planting** in supply chain (multiple DPRK-attributed packages).
- **DevSecOps engineers** at crypto firms targeted via LinkedIn pretext.
- **Custom kernel rootkits** for macOS / Linux engineering targets.

### Supply chain

- **3CX (2023)** — cascading via X_TRADER (Trading Technologies) → 3CX → customers.
- **JumpCloud (2023)** — customer-targeted via JumpCloud commands.
- **Multiple npm / PyPI package campaigns**.

### Financial theft chain

For exchange theft:
1. Initial access via phishing / supply-chain.
2. Compromise crypto-related accounts.
3. Identify hot-wallet access.
4. Stealth-monitor signing infrastructure.
5. Coordinated theft transaction with prepared laundering.
6. Cross-chain swap / Tornado Cash / similar mixer.
7. Off-ramp via various exchanges.

US Treasury OFAC sanctions multiple Lazarus-affiliated wallets.

### Living off legitimate services

- **Cloudflare Workers** for C2 fronting.
- **AWS / Azure for hosted infra**.
- **GitHub** as malware-staging.
- **NPM** as malware-staging.

### Long-game social-engineering

DPRK operators have documented patience:
- LinkedIn relationship-building over months.
- Conferences attendance (virtual).
- Multi-step grooming before payload.

## macOS-specific tradecraft

Unusually for state actors, DPRK has strong macOS capability:
- **AppleJeus family** — macOS variants.
- **KandyKorn** (2023) — macOS variant.
- **BeaverTail / InvisibleFerret** (2024) — macOS-targeting payloads.
- Exploitation of macOS-specific authentication / file paths.

See [[macos-tcc]], [[macos-tcc-forensics]].

## DPRK IT worker scheme

A separate but related state-sponsored activity: DPRK IT workers infiltrate Western tech companies under false identities to:
- Earn wages remitted to DPRK.
- Sometimes plant access for follow-on operations.

CISA / FBI publish guidance for identifying this.

## Common defensive priorities

For crypto / financial / DPRK-relevant defence:

- **Phishing-resistant MFA** universally.
- **Supply-chain vetting** (npm / PyPI / 3rd-party software).
- **HR-side verification** for remote hires — video calls with live ID.
- **Cross-platform EDR** — macOS / Linux coverage as good as Windows.
- **Watch for job-recruiter outreach** — known tradecraft.
- **DevOps engineer awareness** — they're heavily targeted.
- **Wallet signing key management** with hardware + multi-party.
- **Transaction monitoring** for atypical amounts / destinations.

## Detection inspiration

- T1078.004 (Valid Accounts: Cloud) — anomalous sign-ins.
- T1566.003 (Spear-phishing via service) — LinkedIn / messaging-app vectors.
- T1505.003 (Server Software Component: Web Shell).
- T1059.007 (JavaScript / TypeScript implants).
- T1036 (Masquerading) — legitimate-looking processes.

## Workflow to study

1. Read 3CX post-mortem (Mandiant, Microsoft, SentinelOne).
2. Read CISA advisories on Lazarus.
3. Read Kaspersky / ESET DPRK reports.
4. Map crypto-industry-specific defences.
5. Conduct purple-team exercise with relevant TTPs.

## Real-world incidents

- **Sony Pictures (2014)** — Guardians of Peace; attributed to DPRK.
- **Bangladesh Bank SWIFT theft (2016)** — $81M.
- **WannaCry (2017)** — global; attributed.
- **Ronin Bridge (Axie Infinity, 2022)** — $625M crypto.
- **3CX (2023)** — see [[case-study-3cx-supply-chain]].
- **JumpCloud (2023)** — IT-management vendor breach used to reach crypto customers.
- **Atomic Wallet (2023)** — ~$100M stolen.
- **Ongoing** — crypto exchange / DeFi targeting weekly to monthly cadence.

## Related

- [[apt-tradecraft-russian-svr-fsb]]
- [[apt-tradecraft-chinese-mss]]
- [[apt-tradecraft-iranian-irgc]]
- [[ransomware-affiliate-playbook]]
- [[case-study-3cx-supply-chain]]
- [[bridge-attacks-modern]]
- [[npm-postinstall-and-typosquat-audit]]
- [[macos-tcc-forensics]]
- [[detection-engineering-pyramid-of-pain]]

## References
- [Mandiant — 3CX investigation](https://cloud.google.com/blog/topics/threat-intelligence/3cx-software-supply-chain-compromise/)
- [CISA — North Korean APT advisories](https://www.cisa.gov/news-events/cybersecurity-advisories)
- [US Treasury OFAC — Lazarus sanctions](https://ofac.treasury.gov/recent-actions)
- [Microsoft — Diamond Sleet / Sapphire Sleet blogs](https://www.microsoft.com/en-us/security/blog/)
- [Chainalysis — DPRK crypto theft reports](https://www.chainalysis.com/blog/)
- See also: [[apt-tradecraft-russian-svr-fsb]], [[apt-tradecraft-chinese-mss]], [[case-study-3cx-supply-chain]], [[bridge-attacks-modern]]
