---
title: Financial sector defender playbook
slug: financial-sector-defender-playbook
aliases: [banking-defender, finsec-playbook]
---

> **TL;DR:** Defending a bank, broker-dealer, or fintech means stacking controls against a wide threat surface (wire fraud, SWIFT abuse, ATM jackpotting, account takeover, ransomware) under a thick regulatory overlay (PCI, GLBA, SOX, FFIEC, NYDFS 500, DORA, MAS TRM, FCA/PRA). This playbook is the practitioner companion to [[apt-tradecraft-dprk-lazarus]], [[ransomware-affiliate-playbook]], [[case-study-snowflake-2024]], [[ueba-detection-ml-primer]], and [[pci-dss-4-implementation]]. It frames the regulatory landscape, the relevant threat actors, the swiss-cheese layers that actually catch them, and the recurring gaps (third-party, M&A inheritance, mainframe legacy) that put financial firms in the news.

## Why it matters

Financial services attract the most capable adversaries because the payoff is immediate and liquid. DPRK crews fund a sanctioned state, Russian ransomware affiliates extort treasury operations, and FIN-named groups specialise in payment-card and POS abuse. The same firm is simultaneously regulated by a dozen agencies that each demand evidence, log retention, and breach notification on overlapping timelines. A defender hired into a bank inherits a stack with mainframe COBOL, mid-tier ESBs, dozens of SaaS, M&A-acquired subsidiaries, and a SOC that must satisfy both auditors and incident responders. The job is less about clever detections and more about making boring controls actually work everywhere, on time, with evidence.

## Regulatory overlay (practitioner view)

You are not the lawyer. Your job is to translate obligations into controls, evidence, and timelines.

### United States

- **PCI DSS 4.0.1** — anything that stores, processes, or transmits PAN. See [[pci-dss-4-implementation]] for the rollout reality (targeted-risk analyses, scoped CDE, customised approach).
- **GLBA Safeguards Rule** — written infosec program, qualified individual, risk assessment, MFA, encryption, IR plan. Effectively the floor for any FI under FTC jurisdiction.
- **SOX (s.404)** — ITGCs around financial reporting systems. Access provisioning, change management, segregation of duties get audited annually. Security and SOX audit teams must share evidence pipelines.
- **FFIEC IT Examination Handbook** — for banks and credit unions; aligns examiners across OCC, FDIC, Fed, NCUA. The Architecture, Infrastructure & Operations and Information Security booklets are the practitioner bibles.
- **NYDFS 23 NYCRR Part 500** — CISO sign-off, 72-hour notification of cybersecurity events, MFA, annual pen test, biennial risk assessment, vulnerability management. Amendments in 2023-2024 raised the bar (extortion-payment reporting, governance).
- **SEC cyber disclosure rule (Item 1.05 8-K)** — public companies must disclose material cyber incidents within four business days of materiality determination. Coordinate with disclosure counsel.

### EU / UK / APAC

- **DORA** (EU, applies 2025) — ICT risk, incident classification and reporting, third-party register, threat-led pen testing (TLPT). See its overlap with [[nis2-implementation]] for non-financial critical entities.
- **FCA / PRA SYSC 15A, operational resilience** — impact tolerances, important business services, severe-but-plausible scenarios.
- **MAS TRM Guidelines and Notice 655** — Singapore; defines incident notification windows (one hour for systems-affecting events) and outsourcing controls.
- **HKMA Cyber Resilience Assessment Framework**, **APRA CPS 234**, **RBI Cyber Security Framework** — same theme, local flavour.
- **GDPR** — personal-data breach notification at 72 hours. See [[gdpr-incident-implications]].

Build a single control matrix mapped to each framework so a control change updates evidence in N places at once.

## Threat actor landscape

### Nation-state financially motivated

- **DPRK (Lazarus / APT38 / BlueNoroff)** — SWIFT heists (Bangladesh Bank 2016), crypto-exchange and bridge theft (Ronin, Atomic Wallet), supply-chain into trading firms (3CX — see [[case-study-3cx-supply-chain]]). Deep dive in [[apt-tradecraft-dprk-lazarus]].
- **Russian SVR/FSB** — usually espionage, but treasury and payment systems get swept up. See [[apt-tradecraft-russian-svr-fsb]].

### Ransomware and extortion ecosystem

- LockBit, BlackCat/ALPHV, Cl0p, Akira, RansomHub affiliates routinely hit insurance and brokerage. See [[ransomware-affiliate-playbook]] and [[case-study-moveit-2023]].
- Pure-extortion crews (Snowflake-token campaigns) bypass endpoints entirely — see [[case-study-snowflake-2024]].

### Cybercrime specialists

- **FIN7 / FIN8 / FIN11** — POS, RMM abuse, BEC.
- **TA505, TA577** — initial-access brokers feeding the above.
- **Scattered Spider (UNC3944)** — help-desk social engineering against insurers and gaming (and trickled into banks).
- **Magecart** clusters — e-skimming on payment pages.

### Customer-side fraud

- Banking trojans (Mispadu, Grandoreiro, Anubis, Hydra) and infostealers (RedLine, Lumma, StealC) drive credential resale, ATO, and APP fraud.
- Voice-AI fraud and deepfake-assisted phishing of clients and treasurers — see [[voice-cloning-liveness-bypass]] and [[deepfake-assisted-phishing]].

## Wire fraud, APP, and BEC priorities

- **BEC / vendor-impersonation** — the single biggest dollar loss reported to the FBI IC3. Controls: out-of-band callback on payment-account changes, DMARC enforcement (see [[dmarc-spf-dkim-deep]]), [[arc-and-mail-forwarding]] handling, [[bimi-and-mail-authenticity-ux]], and [[email-gateway-bypass-techniques]] awareness.
- **AiTM phishing of finance staff** — see [[aitm-evilginx-modern-phishing]] and [[tycoon2fa-and-modern-phish-kits]]. Detect with [[conditional-access-bypass-modern]] hardening and impossible-travel / token-binding signals.
- **Authorised Push Payment (UK / EU)** — under the PSR reimbursement regime, banks share liability. Fraud teams need real-time scoring, confirmation-of-payee, and 24-hour holds on first-time payees.
- **Wire desk procedures** — dual control, callbacks to known numbers, anomaly thresholds, mandatory cooling-off on new beneficiaries above a threshold.

## SWIFT-network defence

- **SWIFT CSCF** mandatory controls — segregated SWIFT zone, jump server, MFA, daily reconciliation, integrity checks on local SWIFT messaging infrastructure (Alliance Access, Alliance Gateway).
- Treat the SWIFT zone as a Tier-0 enclave: dedicated PAW endpoints, no internet egress, hardware token authentication, application allow-listing, and out-of-band confirmation for messaging templates.
- Detect MT103 / pacs.008 anomalies (new BIC, unusual corridor, time-of-day) at the messaging layer, not just on endpoints. Reconcile against core banking the same business day.
- Tabletop the Bangladesh-Bank pattern: malware on the SWIFT operator, message tampering, printer-suppression of confirmations.

## ATM-network defence

- **Logical attacks** — black-box (HSM cable taps), jackpotting (Ploutus, Cutlet Maker), middleware abuse (XFS).
- Controls: full-disk encryption, BIOS lock, USB port disable, application allow-list, top-hat sensors with alerting, switch-port lockdown to known MACs, signed firmware updates, network segmentation from corporate.
- Monitor cash-dispense events against transaction host; mismatches in real time.
- Physical defence (cassette safes, anti-skimming bezels) is part of the stack — collaborate with physical security.

## Broker-dealer and capital-markets specifics

- **SEC Reg SCI / Reg S-P** — system integrity, customer-data safeguarding, breach notification (30-day final rule in 2024).
- **FINRA 4370** business continuity, **CAT** reporting obligations, **MNPI** controls (Chinese walls, surveillance).
- Trading systems and risk engines are latency-critical; out-of-band logging (port mirrors, packet brokers) keeps detection off the hot path.
- Algorithmic-trading abuse, market-data exfiltration, and front-running by insiders need UEBA (see [[ueba-detection-ml-primer]] and [[time-series-anomaly-for-security]]).

## Customer-facing fraud (ATO and infostealers)

- Treat your customer base as part of the threat surface. Telemetry: device fingerprinting, behavioural biometrics, login anomalies, session-replay reuse.
- Ingest infostealer-log marketplaces (or use a vendor) to identify customers with leaked sessions and force re-auth.
- New-device + new-payee + new-corridor inside one session is a classic ATO signal — score it.
- Educate on SIM-swap risk and offer non-SMS MFA paths.

## Incident reporting expectations (typical windows)

| Regime              | Trigger                                 | Window                |
| ------------------- | --------------------------------------- | --------------------- |
| NYDFS Part 500      | Cybersecurity event                     | 72 hours              |
| SEC 8-K Item 1.05   | Material cyber incident                 | 4 business days       |
| GDPR Art. 33        | Personal-data breach                    | 72 hours              |
| DORA                | Major ICT-related incident              | Initial within hours  |
| MAS Notice 655      | System-affecting / IT security incident | 1 hour initial        |
| HKMA / FCA          | Material operational incident           | "Without undue delay" |
| US bank "Computer-Security Incident Notification" | Notification incident          | 36 hours              |

Pre-stage your decision matrix and counsel contacts now, not during the call.

## Defensive baseline (the swiss-cheese layers)

1. **Identity and access** — phishing-resistant MFA (FIDO2) for everyone, Just-in-Time admin, privileged access workstation for SWIFT / treasury / Active Directory tier 0. Watch [[adcs-attacks]], [[kerberoasting]], [[dcsync]], [[ntlm-relay-ws2025-mitigations]], [[bloodhound]].
2. **Endpoint and email** — EDR with [[edr-rules-as-code-from-attack-patterns]], hardened mail gateway, attachment detonation, link rewriting, DMARC at `p=reject`.
3. **Network** — micro-segmentation around treasury, SWIFT, payments, ATM management. East-west visibility, DNS sinkhole.
4. **Cloud IR readiness** — see [[cloud-ir-aws-cloudtrail]], [[cloud-ir-azure-activity-log]], [[cloud-ir-gcp-audit-logs]], [[cloud-ir-k8s-audit-logs]].
5. **Detection engineering** — [[detection-engineering-pyramid-of-pain]], [[siem-detection-use-case-catalog]], [[atomic-red-team-emulation-deep]], [[purple-team-feedback-loop]].
6. **Threat intel** — [[cti-collection-management]] with finance-sector ISAC (FS-ISAC) feeds.
7. **Deception** — see [[deception-and-honeypot-strategy]] for treasury-account honeytokens.
8. **Resilience** — immutable backups, isolated recovery environment, regular wire-fraud and ransomware tabletops.
9. **Third-party** — continuous vendor monitoring, contractual right to audit, breach-notification clauses with hours not days.

## Common gaps (where banks actually get burned)

- **Third-party and SaaS sprawl** — MOVEit, Snowflake, Okta-style support-system pivots ([[case-study-okta-2023-support-system]], [[case-study-snowflake-2024]]). Inventory SaaS aggressively; require SSO + IP allow-list for high-risk vendors.
- **M&A inheritance** — newly acquired subs run unpatched edge devices and shadow AD trusts. Add a pre-close security due-diligence checklist and 90-day remediation plan.
- **Legacy mainframe** — RACF/ACF2/Top Secret rarely feeds the SOC. Stream SMF records, watch for privileged DBA RACF special, and stale emergency IDs.
- **OT-adjacent** — building management, ATM physical networks, branch infrastructure. See [[ics-scada-protocols-attacks]] for mindset; banks have more OT than they admit.
- **Help desk** — Scattered-Spider-style social engineering. Add callback verification, video-call ID checks for credential / MFA reset, ticket-velocity anomaly detection.
- **Developer laptops with prod tokens** — rotate, scope, and short-TTL everything.

## Workflow to study

1. Read FFIEC IT Examination Handbook Information Security and Architecture booklets cover to cover.
2. Map your control set to PCI 4.0.1, NYDFS 500, GLBA Safeguards, DORA, and any local regime in a single matrix.
3. Walk the SWIFT CSCF Independent Assessment Framework; gap-assess your CSP attestation.
4. Tabletop three scenarios end-to-end: SWIFT message tampering, ransomware on the loan-origination platform, BEC redirecting a closing payment.
5. Run an attack-path review (BloodHound + cloud IAM) focused on treasury, SWIFT, and core banking.
6. Build a real-time dashboard for the top five customer-fraud signals (impossible travel, new device + new payee, infostealer hit, session reuse, MFA fatigue).
7. Sit two shifts on the fraud-ops floor to learn their vocabulary and pain points.
8. Run a purple-team exercise emulating [[apt-tradecraft-dprk-lazarus]] BlueNoroff intrusion-chain against your SWIFT zone (in isolation).

## Related

- [[pci-dss-4-implementation]]
- [[apt-tradecraft-dprk-lazarus]]
- [[case-study-snowflake-2024]]
- [[ransomware-affiliate-playbook]]
- [[ueba-detection-ml-primer]]
- [[case-study-3cx-supply-chain]]
- [[case-study-moveit-2023]]
- [[case-study-okta-2023-support-system]]
- [[aitm-evilginx-modern-phishing]]
- [[tycoon2fa-and-modern-phish-kits]]
- [[mfa-fatigue-tradecraft]]
- [[dmarc-spf-dkim-deep]]
- [[detection-engineering-pyramid-of-pain]]
- [[siem-detection-use-case-catalog]]
- [[cti-collection-management]]
- [[deception-and-honeypot-strategy]]
- [[purple-team-feedback-loop]]
- [[nis2-implementation]]
- [[gdpr-incident-implications]]
- [[cloud-ir-aws-cloudtrail]]

## References

- <https://www.ffiec.gov/cyberresources.htm> — FFIEC IT Examination Handbook and cyber resources
- <https://www.dfs.ny.gov/industry_guidance/cybersecurity> — NYDFS 23 NYCRR Part 500 portal
- <https://www.swift.com/myswift/customer-security-programme-csp> — SWIFT Customer Security Programme and CSCF
- <https://www.eba.europa.eu/regulation-and-policy/single-rulebook/interactive-single-rulebook/dora> — EBA DORA single rulebook
- <https://www.mas.gov.sg/regulation/guidelines/technology-risk-management-guidelines> — MAS Technology Risk Management Guidelines
- <https://www.sec.gov/news/press-release/2023-139> — SEC cybersecurity disclosure rule (Item 1.05)
- <https://www.fsisac.com/> — FS-ISAC sector threat intelligence
