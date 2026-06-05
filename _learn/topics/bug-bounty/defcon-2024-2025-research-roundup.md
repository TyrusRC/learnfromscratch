---
title: DEF CON 2024-2025 research roundup
slug: defcon-2024-2025-research-roundup
aliases: [defcon-2024, defcon-2025, dc-roundup]
---

> **TL;DR:** DEF CON 32 (2024) and DEF CON 33 (2025) doubled down on AI red teaming, hardware-root-of-trust failures (PKfail), satellite and aerospace hacking (Hack-a-Sat finals), automotive infotainment exploits, and cloud identity abuse. Villages — AI, Aerospace, ICS, Car Hacking, IoT, Bio, Packet — drove much of the novel research, while main-track talks delivered patch-diff-grade zero-days and supply-chain dissections. Pair this roundup with [[blackhat-2024-2025-research-roundup]] (its corporate sibling), [[pwn2own-2024-2025-research-roundup]] (the contest-driven cousin), and [[cubesat-attacks]] for the space-systems angle.

## Why it matters

DEF CON is the world's largest hacker conference and the *de facto* publication venue for offensive research that does not fit a vendor briefing. Unlike academic venues, talks ship working exploits, recordings, and slide decks within weeks of the event via the media.defcon.org archive. For a bug-bounty hunter or red teamer, scraping DEF CON every August is one of the highest-yield ways to refresh tradecraft (see [[keeping-up-with-research-feeds]]).

What changed in 2024-2025:

- AI Village graduated from novelty to flagship — the Generative Red Team (GRT) at DC32 and the AI Cyber Challenge (AIxCC) semifinals at DC32 / finals at DC33 made AI security a first-class track.
- Hardware root-of-trust took center stage with Binarly's PKfail disclosure, presented at DC32 and expanded at DC33 (see [[pkfail-uefi-secureboot-bypass]]).
- Aerospace Village hosted the final Hack-a-Sat 5 attack-defend competition at DC32, with on-orbit Moonlighter satellite challenges; DC33 pivoted to the Aerospace Village CTF and broader space-systems content.
- Cloud identity bypasses — Entra cross-tenant sync abuse, OAuth device code phishing, conditional access gaps — dominated the cloud track (see [[entra-cross-tenant-sync-abuse]], [[oauth-device-code-phishing-m365]], [[conditional-access-bypass-modern]]).
- Automotive: Car Hacking Village ran multi-OEM CTFs; main track had Tesla, Sonata, and Hyundai infotainment talks.

## Classes, patterns, process

### Villages of note

#### AI Village

DC32 (2024) ran the second public Generative Red Team in partnership with Humane Intelligence and the White House OSTP, generating one of the largest public corpora of LLM jailbreak / harm prompts. DC33 (2025) hosted the AIxCC semifinals (DARPA Cyber Challenge), pushing automated vulnerability discovery and patching on real OSS. Themes worth studying:

- Prompt injection variants (indirect via documents, RAG poisoning).
- Multi-modal jailbreaks (image-embedded text payloads).
- Agentic abuse — tool-use exfiltration, sandbox escape (see [[ai-agent-sandbox-design]]).
- Voice and deepfake bypasses ([[voice-cloning-liveness-bypass]], [[deepfake-assisted-phishing]]).

#### Aerospace Village & Hack-a-Sat

Hack-a-Sat 5 (DC32, August 2024) was the final edition of the on-orbit CTF, with teams attacking and defending the Moonlighter satellite in low-earth orbit. Public writeups from the qualifying rounds and finals are gold for satellite tradecraft. DC33 transitioned to broader Aerospace Village CTFs, ADS-B / ACARS challenges, and avionics talks. Cross-reference [[cubesat-attacks]] and [[gps-gnss-spoofing]].

#### ICS Village

Focus on OT protocols (Modbus, DNP3, OPC-UA), HMI exploitation, and ransomware impact on industrial environments. Notable DC32 content included PLC supply-chain implants and engineering workstation attacks.

#### Car Hacking Village

DC32 and DC33 both hosted CTFs with real vehicles. Main-track adjacent talks covered:

- Tesla retbleed-style infotainment exploitation chains.
- Hyundai / Kia head-unit research (post the 2023 USB-A "challenge" social media wave).
- CAN bus injection via aftermarket dongles.
- UDS diagnostic abuse for ECU re-flashing.

#### IoT Village

Router 0-days (TP-Link, Asus, Netgear), smart-lock bypasses, and "We hacked X consumer device" disclosures. Always check the village's GitHub for full lab repos.

#### Bio Hacking Village

Medical device research — infusion pumps, pacemaker telemetry, FDA SBOM compliance discussion. DC33 expanded to AI-in-healthcare risk.

#### Packet Hacking Village (Wall of Sheep)

Network forensics CTFs and live SSID-tracking demos; useful for refreshing [[wifi-and-802-11-primer]] and [[evil-twin-and-karma-attacks]].

### Main-track themes

#### Hardware root-of-trust failures

- **PKfail** (Binarly, DC32 main track): hundreds of UEFI firmware images shipped with the Platform Key from AMI's `DO_NOT_TRUST_AMI_TEST` test certificate, breaking Secure Boot trust anchors across Lenovo, HP, Dell, Acer, and more. Deep dive: [[pkfail-uefi-secureboot-bypass]] and [[bootloader-and-secure-boot-attacks]].
- LogoFAIL follow-ups and SMM exploitation chains.
- TPM sniffing and BitLocker pre-boot key exfiltration revisits.

#### Cloud identity & SaaS

- Entra ID cross-tenant sync abuse — see [[entra-cross-tenant-sync-abuse]].
- OAuth device-code phishing operationalized — see [[oauth-device-code-phishing-m365]].
- Conditional Access bypasses via legacy protocols / token theft — see [[conditional-access-bypass-modern]] and [[aitm-evilginx-modern-phishing]].
- M365 admin role abuse and forensic gaps — [[m365-admin-attacks]].

#### Supply chain

- 3CX retrospective and similar trojanized installers (see [[case-study-3cx-supply-chain]]).
- Open-source registry typosquatting at scale.
- CI/CD pivot — GitHub Actions OIDC abuse, self-hosted runner takeover.

#### Web & app security

- HTTP request smuggling variants — see [[http-smuggling-modern-variants]].
- Cache deception / poisoning chains — [[cache-deception]], [[cache-poisoning-modern-chains]].
- WAF bypasses presented in workshop form — [[waf-bypass-advanced-techniques]].

#### Mobile & Apple ecosystem

- iOS baseband and Secure Enclave talks — see [[ios-baseband-attacks]], [[ios-keychain-and-secure-enclave-audit]].
- macOS TCC and Gatekeeper bypasses ([[macos-tcc]], [[gatekeeper-bypasses]]).
- checkm8 / BootROM retrospectives — [[ios-bootrom-checkm8]].

### DEF CON CTF Finals

- **DC32 (2024) finals**: Won by Maple Bacon-adjacent merger / Blue Water (verify against the official 2024 results page when citing). Quals run by Nautilus Institute. Challenges leaned into Web3, hypervisor escapes, kernel exploitation, and weird-machine pwn.
- **DC33 (2025) finals**: Continued Nautilus organization; finals are an attack-defend tournament with shared infrastructure. Writeups appear on team blogs (Shellphish, PPP, Maple Bacon, Blue Water, KAIST GoN) within 1-3 months.

Even if you do not compete, replaying CTF finals problems is one of the best ways to internalize current pwn tradecraft — see [[pwn-college-walkthrough-methodology]] and [[ctf-to-bug-bounty-transition]].

### Pwn2Own-adjacent talks

Some DC talks are extended write-ups of Pwn2Own / Pwnie-nominated bugs. Use them as the "director's commentary" for [[pwn2own-2024-2025-research-roundup]]. Look especially for Tesla, ICS Pwn2Own Miami, and Mobile Pwn2Own Toronto retrospectives.

## Defensive baseline

If you defend infrastructure, mine DEF CON for IR and detection content as much as offensive:

- Map every applicable talk to ATT&CK techniques and update [[siem-detection-use-case-catalog]].
- Convert exploit chains to atomic tests via [[atomic-red-team-emulation-deep]].
- Update [[detection-engineering-pyramid-of-pain]] with new behavioral indicators (e.g., PKfail boot-time integrity checks, Entra audit log baselines).
- Refresh cloud IR runbooks: [[cloud-ir-aws-cloudtrail]], [[cloud-ir-azure-activity-log]], [[cloud-ir-gcp-audit-logs]], [[cloud-ir-k8s-audit-logs]].
- For OT environments, line up Village ICS talks against your asset inventory.

## Workflow to study DEF CON output

A reproducible monthly review process that pays back compound interest:

1. **Wait two to six weeks post-event.** Most slides and a chunk of videos hit media.defcon.org and the DEFCONConference YouTube channel by late September.
2. **Pull the official talk index.** The DC32 / DC33 talks pages on defcon.org list abstracts, speakers, and tracks. Save as a CSV or markdown table.
3. **Tag by domain.** Web, mobile, cloud, hardware, AI, OT, automotive, satellite, IR. Use the same taxonomy as the rest of your notes.
4. **Triage top 20.** Rank by relevance to your day job / target portfolio. For each: watch the talk at 1.5x, grab slides, find the speaker's GitHub.
5. **Replicate one.** Pick *one* talk per month and rebuild the lab in your home setup — see [[building-a-research-home-lab]].
6. **Patch-diff follow-ups.** For talks that dropped 1-days, run [[one-day-from-patch-diff]] on the referenced CVEs.
7. **Cross-link.** Add `[[wikilink]]` references from your existing topic notes to the talk URL. This is how the knowledge compounds.
8. **Track Villages separately.** Each Village publishes its own materials, often on GitHub orgs (aerospacevillage, ICSVillage, BiohackingVillage, AIVillage). Subscribe.
9. **Mirror media locally.** Slides and code disappear; mirror to your private archive (respect licensing).
10. **Feed your CTI loop.** Update [[cti-collection-management]] with new threat actor TTPs disclosed at the con.

### Reading order when time is short

If you have one weekend:

1. Watch the keynote and the closing ceremony.
2. Watch the top three main-track talks for your domain.
3. Skim AI Village summary thread on X / Mastodon / Bluesky.
4. Read three CTF finals writeups.
5. File three new notes in your knowledge base referencing the above.

## Related

- [[blackhat-2024-2025-research-roundup]]
- [[pwn2own-2024-2025-research-roundup]]
- [[cubesat-attacks]]
- [[pkfail-uefi-secureboot-bypass]]
- [[bootloader-and-secure-boot-attacks]]
- [[keeping-up-with-research-feeds]]
- [[building-a-research-home-lab]]
- [[case-study-portswigger-top-10-pattern]]
- [[case-study-orange-tsai-research-pattern]]
- [[case-study-h1-top-disclosed-2024-2025]]
- [[case-study-google-vrp-writeup-patterns]]
- [[ai-agent-sandbox-design]]
- [[voice-cloning-liveness-bypass]]
- [[deepfake-assisted-phishing]]
- [[entra-cross-tenant-sync-abuse]]
- [[oauth-device-code-phishing-m365]]
- [[conditional-access-bypass-modern]]
- [[aitm-evilginx-modern-phishing]]
- [[m365-admin-attacks]]
- [[case-study-3cx-supply-chain]]
- [[http-smuggling-modern-variants]]
- [[cache-deception]]
- [[cache-poisoning-modern-chains]]
- [[waf-bypass-advanced-techniques]]
- [[ios-baseband-attacks]]
- [[ios-keychain-and-secure-enclave-audit]]
- [[macos-tcc]]
- [[gatekeeper-bypasses]]
- [[ios-bootrom-checkm8]]
- [[gps-gnss-spoofing]]
- [[wifi-and-802-11-primer]]
- [[evil-twin-and-karma-attacks]]
- [[atomic-red-team-emulation-deep]]
- [[siem-detection-use-case-catalog]]
- [[detection-engineering-pyramid-of-pain]]
- [[cti-collection-management]]
- [[one-day-from-patch-diff]]
- [[ctf-to-bug-bounty-transition]]
- [[pwn-college-walkthrough-methodology]]

## References

- DEF CON official media archive: https://media.defcon.org/
- DEF CON 32 talks index: https://defcon.org/html/defcon-32/dc-32-speakers.html
- DEF CON 33 talks index: https://defcon.org/html/defcon-33/dc-33-speakers.html
- Binarly PKfail disclosure (presented at DC32): https://www.binarly.io/blog/pkfail-untrusted-platform-keys-undermine-secure-boot-on-uefi-ecosystem
- Hack-a-Sat finals retrospective: https://hackasat.com/
- DARPA AI Cyber Challenge (AIxCC) updates: https://aicyberchallenge.com/
