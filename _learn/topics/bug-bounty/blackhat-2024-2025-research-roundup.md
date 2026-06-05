---
title: Black Hat USA / Europe 2024-2025 research roundup
slug: blackhat-2024-2025-research-roundup
aliases: [blackhat-2024, blackhat-2025, bh-roundup]
---

> **TL;DR:** Black Hat USA and Europe in 2024-2025 leaned heavily on cloud identity abuse (Entra/Okta cross-tenant sync, OAuth device-code), Windows kernel and EDR bypass tradecraft, browser exploit-chain work, automotive and embedded breaks from the Pwn2Own pipeline, the first wave of "real" AI/LLM agent attacks, and hardware/firmware disasters such as PKfail, LogoFAIL, and the xz-utils supply-chain backdoor. This note is the conference-talk companion to [[case-study-portswigger-top-10-pattern]] and [[pwn2own-2024-2025-research-roundup]], and pairs well with [[keeping-up-with-research-feeds]] for ongoing intake.

## Why it matters

Black Hat is one of the few venues where vendor-disclosed, peer-reviewed offensive research lands with both slides and recorded talks, and where defenders, red teamers, and bug-bounty hunters all consume the same primary source. Watching a season of BH talks is a fast way to:

- Calibrate which classes of bugs the top researchers think are worth six months of effort.
- Pick up new techniques before they hit blog posts, training courses, or HackTricks-style aggregators.
- Spot the gap between "cool demo" and "real impact" so your own reports (see [[demonstrating-impact]] and [[report-writing-for-pentesters]]) land better.

If you only have time for one ingestion ritual, BH USA briefings + BH EU briefings + Pwn2Own write-ups is the strongest signal-to-noise loop available.

## Themes and notable talks

### Cloud identity (Entra, Okta, M365)

Identity took over the BH USA Enterprise track in both years. Standout work:

- **Dirk-jan Mollema (dirkjanm)** continued his multi-year Entra ID series, demonstrating cross-tenant trust abuse, abuse of the Microsoft Graph for stealthy persistence, and refresh-token theft against hybrid joined devices. Pairs with [[entra-cross-tenant-sync-abuse]] and [[m365-admin-attacks]].
- **Nestori Syynimaa (DrAzureAD)** continued AADInternals research, including service-principal certificate abuse and seamless-SSO key extraction. See [[conditional-access-bypass-modern]].
- **SpecterOps** presented refinements on BloodHound for Azure / Entra ID, formalising tier-zero in cloud terms.
- Talks on **OAuth device-code phishing** and **AiTM** updates fed directly into [[oauth-device-code-phishing-m365]] and [[aitm-evilginx-modern-phishing]].
- Post-Okta-2023, multiple sessions revisited support-portal and HAR-file exposure, building on [[case-study-okta-2023-support-system]].

Takeaway: identity is the new perimeter, and BH is publishing the playbook a year before it shows up in red-team engagements.

### Windows kernel and EDR bypass

- Multiple talks on **BYOVD (Bring Your Own Vulnerable Driver)** taxonomies, including improvements to LOLDrivers and EDRSandblast-style tooling.
- **Connor McGarr** and others on Windows kernel exploit primitives post-HVCI and post-VBS, focusing on arbitrary-read/write to kernel-mode code execution under hardware-enforced stack protection.
- Several sessions on **WDAC and AppLocker bypass** via signed-binary abuse and policy-merging tricks, useful input for [[edr-rules-as-code-from-attack-patterns]] and [[detection-engineering-pyramid-of-pain]].
- EDR-internals talks dissecting userland hooking, kernel callback enumeration, and ETW-TI evasion. Tie these back to [[atomic-red-team-emulation-deep]] for emulation coverage.

### Browser exploitation

- V8 and JavaScriptCore exploitation chains, often referencing Pwn2Own entries that later appeared at BH with more detail. See [[pwn2own-2024-2025-research-roundup]].
- **Renderer-to-sandbox** and **Site Isolation** weakness research, including content-process compromise leading to UXSS-like primitives.
- Talks on **WebGPU**, **WebAssembly**, and **WebCodecs** as new attack surfaces - all relatively young APIs with weaker fuzzing maturity.
- Recurring theme: modern browser exploits increasingly need two or three primitives chained, and the "single-bug RCE" era in mainstream browsers is essentially over.

### Web research and HTTP-layer attacks

- **James Kettle (albinowax, PortSwigger)** delivered his now-traditional BH USA web keynote on HTTP-layer attacks. The 2024-2025 cycle included new request-smuggling variants over HTTP/2 and HTTP/3, and large-scale cache-poisoning chains. Direct input to [[http-smuggling-modern-variants]], [[cache-poisoning-modern-chains]], and [[case-study-portswigger-top-10-pattern]].
- **Orange Tsai** presented further Apache HTTPD confusion attacks and middleware path-handling research, complementing [[case-study-orange-tsai-research-pattern]].
- Talks on **WAF bypass** at scale, feeding [[waf-bypass-advanced-techniques]].
- SSRF-to-cloud-metadata talks remained popular, see [[ssrf]].

### Automotive and Pwn2Own-adjacent

- **Tesla infotainment and modem** breaks from the Pwn2Own Automotive Tokyo events were re-presented at BH with deeper technical detail.
- **Lennert Wouters (KU Leuven COSIC)** and collaborators continued automotive immobiliser and key-fob cryptographic-implementation research, plus broader embedded fault-injection work that connects to [[fault-injection-laser-emfi]] and [[hardware-glitching-deep]].
- EV charging infrastructure (OCPP, ISO 15118) showed up as a fresh, under-tested attack surface.

### AI and LLM security

- First wave of **prompt-injection-as-real-exploit** talks: indirect injection via documents, emails, and tool outputs leading to data exfiltration in agentic systems.
- **Model supply-chain** talks on Hugging Face artefact abuse, pickle deserialisation, and malicious model weights.
- **LLM red-teaming methodology** sessions building on OWASP LLM Top 10 and MITRE ATLAS, pairing well with [[ai-agent-sandbox-design]].
- Defensive talks on agent sandboxing, capability scoping, and tool-call authorisation.

Honest framing: most 2024 AI talks were demo-heavy and impact-light. 2025 talks started to show real production-system compromises, particularly in enterprise copilot integrations.

### Hardware, firmware, and supply chain

- **PKfail** (Binarly): leaked Platform Keys shipped by major OEMs allowing Secure Boot bypass at scale. See [[pkfail-uefi-secureboot-bypass]] and [[bootloader-and-secure-boot-attacks]].
- **LogoFAIL** follow-ups: image-parser vulnerabilities in UEFI firmware, expanding the pre-OS attack surface.
- **xz-utils backdoor (CVE-2024-3094)**: dedicated retrospectives on the social-engineering long-con, the obfuscated payload, and the detection story. Direct input to [[case-study-3cx-supply-chain]] and [[case-study-solarwinds-2020]] as a comparison set.
- Continued **TPM, fTPM, and Secure Enclave** research, including sniffing and replay attacks on discrete TPM buses.

### Cryptographic implementations

- Side-channel work on post-quantum candidates (Kyber, Dilithium) feeding [[post-quantum-crypto-attack-surface]] and [[cryptography-side-channels-survey]].
- HSM and key-management abuse talks, connecting to [[hardware-security-module-attacks]].
- Renewed interest in **deterministic ECDSA nonce leaks** and **partial-key recovery** via cache and EM side channels, complementing [[side-channel-power-em]] and [[spectre-meltdown-deep]].

### Detection, IR, and threat intel

BH USA's defensive tracks added value too:

- Cloud-IR talks on CloudTrail, Azure Activity Log, and GCP audit logs feeding [[cloud-ir-aws-cloudtrail]], [[cloud-ir-azure-activity-log]], and [[cloud-ir-gcp-audit-logs]].
- Detection-as-code sessions reinforcing [[siem-detection-use-case-catalog]] and [[purple-team-feedback-loop]].
- APT tradecraft retrospectives that tie back to [[apt-tradecraft-russian-svr-fsb]], [[apt-tradecraft-chinese-mss]], and [[apt-tradecraft-dprk-lazarus]].

## Patterns across the season

A few patterns repeat across both years:

1. **Chains beat single bugs.** Almost every headline talk required two or more primitives. Build your own research the same way - assume one bug is not a finish line.
2. **Identity, firmware, and AI are the three growth areas.** Web and kernel research is still strong but increasingly incremental.
3. **Tooling release at talk time.** Most serious BH talks ship code (BloodHound modules, fuzzers, EDR-evasion frameworks). Track repos, not just slides.
4. **Disclosure tracks matter.** Many BH talks coordinate with vendors on a multi-month timeline; the embargo story is itself a learning artefact for [[disclosure-and-comms]] and [[responsible-disclosure-across-jurisdictions]].

## Workflow to study a BH season

1. **Pull the briefings index** for BH USA and BH EU as soon as it is published. Skim every abstract; star 20-30 talks.
2. **Watch the recordings** once they hit the official YouTube channel (usually a few weeks post-event). Take notes on technique, not narrative.
3. **Grab the slides and white paper** from the briefing page; many talks publish a longer paper than the talk covers.
4. **Find the repo.** If the talk released tooling, clone it into [[building-a-research-home-lab]] and reproduce one primitive.
5. **Map to your existing notes.** For each talk, ask: which of my topic notes does this update? Edit them directly rather than hoarding a "to read" list.
6. **Cross-reference Pwn2Own.** Many BH talks are extended versions of Pwn2Own entries. Use [[pwn2own-2024-2025-research-roundup]] as a cross-index.
7. **Feed your RSS/Atom intake.** Add researcher blogs to [[keeping-up-with-research-feeds]] so the next year's work shows up before the conference.

## Defensive baseline

If you are on the blue or purple side, the minimum follow-up from a BH season:

- Patch firmware (UEFI, TPM, baseband) on a defined cadence, not just OS patches.
- Review Entra / Okta cross-tenant settings and conditional-access posture against the latest talks.
- Add detection content for the year's BYOVD drivers and any new EDR-evasion primitives.
- Re-baseline your supply-chain controls against xz-style social engineering: maintainer takeover, obfuscated build steps, test-fixture payloads.
- Update tabletop exercises with the season's most plausible chains; see [[purple-team-feedback-loop]] and [[ir-from-source-signals]].

## Related

- [[pwn2own-2024-2025-research-roundup]]
- [[case-study-portswigger-top-10-pattern]]
- [[case-study-orange-tsai-research-pattern]]
- [[case-study-h1-top-disclosed-2024-2025]]
- [[case-study-google-vrp-writeup-patterns]]
- [[keeping-up-with-research-feeds]]
- [[building-a-research-home-lab]]
- [[entra-cross-tenant-sync-abuse]]
- [[oauth-device-code-phishing-m365]]
- [[aitm-evilginx-modern-phishing]]
- [[http-smuggling-modern-variants]]
- [[cache-poisoning-modern-chains]]
- [[waf-bypass-advanced-techniques]]
- [[pkfail-uefi-secureboot-bypass]]
- [[bootloader-and-secure-boot-attacks]]
- [[post-quantum-crypto-attack-surface]]
- [[cryptography-side-channels-survey]]
- [[ai-agent-sandbox-design]]
- [[detection-engineering-pyramid-of-pain]]
- [[edr-rules-as-code-from-attack-patterns]]

## References

- Black Hat USA briefings archive: https://www.blackhat.com/us-24/briefings/schedule/ and https://www.blackhat.com/us-25/briefings/schedule/
- Black Hat Europe briefings archive: https://www.blackhat.com/eu-24/briefings/schedule/ and https://www.blackhat.com/eu-25/briefings/schedule/
- Binarly PKfail research: https://www.binarly.io/blog/pkfail-untrusted-keys-undermining-secure-boot
- PortSwigger Research (James Kettle): https://portswigger.net/research
- Orange Tsai (DEVCORE) blog: https://blog.orange.tw/
- xz-utils backdoor analysis (Akamai SIRT): https://www.akamai.com/blog/security-research/critical-linux-backdoor-xz-utils-discovered-what-to-know
