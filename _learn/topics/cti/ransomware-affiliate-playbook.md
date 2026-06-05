---
title: Ransomware affiliate playbook
slug: ransomware-affiliate-playbook
aliases: [ransomware-rolls, ransomware-as-a-service, raas-tradecraft]
---

> **TL;DR:** Modern ransomware is mostly Ransomware-as-a-Service (RaaS): operators develop the malware + leak site + negotiation infrastructure, affiliates conduct the intrusion + deployment. Major operators (LockBit, Conti, BlackCat / ALPHV, Black Basta, RansomHub, Akira, Play, Medusa) share patterns: initial-access broker (IAB) feeds, identity / VPN access, AD compromise, exfiltration before encryption, double-extortion via leak site. Companion to [[apt-tradecraft-dprk-lazarus]] and [[case-study-moveit-2023]].

## Why ransomware tradecraft matters

- Distinct economic model: criminal RaaS operators + affiliates + IABs.
- Affiliates often re-use TTPs across operators.
- Lessons learned defend against many groups simultaneously.
- Reported median dwell-time ~9 days (Mandiant 2024) — investigation window matters.

## The RaaS ecosystem

### Operators

Develop malware, leak site, support infrastructure. Maintain reputation.

### Affiliates

Independent operators conducting intrusions. Pay operator a fee (~20–30% of ransom).

### Initial Access Brokers (IAB)

Sell access to victim networks. Source:
- Credential-stuffing / infostealer logs.
- Phishing campaigns.
- N-day exploit campaigns.

Affiliate buys access; operates from there.

### Negotiators / shame-site operators

Distinct individuals handling negotiation and victim coercion.

## Initial-access vectors

- **VPN credentials** — particularly Fortinet, Ivanti, Cisco, Citrix, Palo (often N-day or default).
- **RDP** — exposed or with weak passwords.
- **VPN MFA-fatigue / AitM** — see [[mfa-fatigue-tradecraft]], [[aitm-evilginx-modern-phishing]].
- **Internet-facing application exploitation** — Confluence, GitLab, etc.
- **Cleo / MOVEit / Citrix Bleed** style mass-exploitation.
- **Spearphish** with malware loaders (QakBot, IcedID, Pikabot).
- **MSP / RMM compromise** — ScreenConnect (CVE-2024-1709), Kaseya 2021.
- **Supply-chain malware**.

## Recon / lateral movement

Standard windows-domain tradecraft:
- **Bloodhound** for AD graphing.
- **Mimikatz** / **DCSync** for credentials.
- **Kerberoasting**.
- **WMI / SMB** lateral movement.
- **Cobalt Strike** / **Sliver** / **Mythic** for C2.
- **PsExec / Impacket** for execution.
- **Living off the Land** for stealth.

See [[active-directory]], [[lateral-movement]].

## Exfiltration

Modern ransomware does **double extortion**: exfil + encrypt. Exfil to:
- **MEGA**, **AnonFiles**, **PCloud** uploads.
- **rclone** to cloud buckets attacker controls.
- **WinSCP / FileZilla** to attacker SFTP.

Volume: hundreds of GB typical for mid-size company. Detection opportunity at egress.

## Defence inhibitor / EDR-killing

Affiliates use:
- **BYOVD (Bring Your Own Vulnerable Driver)** to disable EDR — `gmer.sys`, `mhyprot2.sys`, others.
- **EDR un-installer** if admin creds obtained.
- **PowerShell to disable Defender**.
- **Killing antivirus services**.

This step is often the alarm — sophisticated EDR detects driver loads.

## Encryption stage

Final stage:
- Stage encryptor binary.
- Push via SMB or PsExec to all hosts.
- Encrypt local files.
- Encrypt mounted shares, including backups if reachable.
- Drop ransom note.
- Self-delete encryptor.

Fast — minutes to encrypt thousands of hosts.

## Operators (selected, 2023-2025)

### LockBit (2019-2024)

- One of the dominant operators.
- LockBit 3.0 (Black) used widely.
- Disrupted by Operation Cronos (Feb 2024) — UK NCA, Europol, FBI.
- Operator infrastructure seized; operators identified.
- Surviving affiliates moved to other operators.

### Conti (2020-2022)

- Hugely successful; internal leaks (ContiLeaks 2022) exposed operations after pro-Ukraine statement.
- Split into multiple successor groups: Black Basta, Royal, BlackByte.

### BlackCat / ALPHV (2021-2024)

- Rust-based, sophisticated.
- Notable: 2024 Change Healthcare incident — $22M ransom paid but data still leaked.
- Operator allegedly exit-scammed affiliates in early 2024.

### Black Basta (2022+)

- Conti successor.
- Active 2024.
- Targets US healthcare, government, financial.

### RansomHub (2024+)

- Emerged as dominant RaaS after LockBit takedown.
- Targets across sectors.

### Akira (2023+)

- Smaller but consistent.
- VPN-focused initial access.

### Play / Medusa (2022+)

- Active and growing.

### Cl0p (2019+)

- Mass-exploitation-driven (Accellion 2021, MOVEit 2023, Cleo 2024).
- Notable for skipping encryption in some campaigns — pure data theft + extortion.

## Defence-side priorities

For organisations:

### Pre-incident hardening

- **VPN MFA** + phishing-resistant; immediate patching.
- **RDP off internet**; if needed, behind VPN + MFA + IP allowlist.
- **EDR universally** with behavioural rules.
- **Network segmentation** — limit lateral movement.
- **Immutable backups** off-network.
- **Backup restore tested** quarterly.
- **Tier-0 isolation** — admin workstations dedicated.
- **MFA on admin accounts** unequivocally.
- **Egress controls** — MEGA / rclone / cloud-storage destinations should alert.
- **PowerShell logging + AMSI**.
- **EDR-killing detection** — driver loads, BYOVD signatures.

### During incident

- **Disconnect compromised systems** from network.
- **Preserve evidence** before remediation (RAM, disk image).
- **Identify scope** — compromised credentials, lateral movement paths.
- **Containment**: change all credentials, revoke sessions.
- **Negotiation decision** — engage legal / law enforcement.
- **Backup integrity verification** before restore.
- **Communications plan** — staff, customers, regulators.

### Post-incident

- **Full forensic timeline**.
- **Rebuild from clean** — assume any persisted credentials compromised.
- **Lessons learned** + control gaps.
- **Mandatory regulator reporting** if applicable.

## Negotiation considerations

Outside this note's scope; engage specialist firms (Coveware, Arete IR, ReSecurity).

OFAC sanctions implications — paying ransom to sanctioned entities is illegal in US/EU. Sanctioning of LockBit, Conti members, others limits negotiation.

## Recovery realities

- **Decryption keys**: even with key, decryption is slow + lossy.
- **Backup restore**: faster but data-loss between last backup and incident.
- **Total recovery**: weeks to months for medium / large org.
- **Reputational + financial damage** lasting years.

## Detection inspiration (ATT&CK)

- T1078 (Valid Accounts).
- T1059 (Command and Scripting Interpreter).
- T1003 (Credential Dumping).
- T1486 (Data Encrypted for Impact).
- T1567.002 (Exfiltration to Cloud Storage).
- T1561 (Disk Wipe).

CTI providers publish operator-specific detection content.

## Workflow to study

1. Read ContiLeaks (translated) for insider view.
2. Read Coveware / IBM X-Force / Mandiant ransomware reports.
3. Map your environment to TTPs of currently-active operators.
4. Run TTP-specific Atomic Red Team tests.
5. Conduct ransomware tabletop exercise quarterly.

## Real-world examples

- **Colonial Pipeline (2021)** — DarkSide; fuel pipeline shutdown.
- **JBS Foods (2021)** — REvil.
- **Kaseya VSA (2021)** — REvil supply chain.
- **Change Healthcare (2024)** — BlackCat.
- **MGM Resorts / Caesars (2023)** — Scattered Spider (affiliate) + BlackCat.

## Related

- [[apt-tradecraft-russian-svr-fsb]]
- [[apt-tradecraft-chinese-mss]]
- [[apt-tradecraft-dprk-lazarus]]
- [[apt-tradecraft-iranian-irgc]]
- [[case-study-moveit-2023]]
- [[case-study-cleo-2024]]
- [[case-study-equifax-2017]]
- [[cve-2024-1709-screenconnect-auth-bypass]]
- [[aitm-evilginx-modern-phishing]]
- [[mfa-fatigue-tradecraft]]
- [[detection-engineering-pyramid-of-pain]]
- [[ir-from-source-signals]]

## References
- [Coveware quarterly reports](https://www.coveware.com/blog)
- [Mandiant — ransomware threat landscape](https://cloud.google.com/blog/topics/threat-intelligence)
- [Microsoft Threat Intelligence — ransomware blogs](https://www.microsoft.com/en-us/security/blog/)
- [CISA #StopRansomware](https://www.cisa.gov/stopransomware)
- [Recorded Future / ContiLeaks analyses](https://www.recordedfuture.com/)
- See also: [[apt-tradecraft-dprk-lazarus]], [[case-study-moveit-2023]], [[aitm-evilginx-modern-phishing]], [[detection-engineering-pyramid-of-pain]]
