---
title: Hardware / IoT bug bounty programs
slug: hardware-iot-bug-bounty-programs
aliases: [hw-iot-bb, pwn2own-hw-bb]
---

> **TL;DR:** Hardware and IoT bounty work pays well but has a steep entry cost: you need lab gear, target devices, and the patience to ship a working exploit (not just a finding). The marquee venues are Pwn2Own (consumer router, NAS, mobile, automotive, ICS/SCADA tracks with tiered prizes), ZDI's year-round brokerage, and vendor programs like Apple Security Bounty, Google/Pixel VRP, Samsung TRP/SKBP, Tesla, and Cisco PSIRT. Most pay on working chain + reliable PoC, not theoretical bug. Companion notes: [[pwn2own-2024-2025-research-roundup]], [[firmware-audit-methodology]], [[firmware-extraction]], and [[android-mali-gpu-exploitation]].

## Why it matters

Hardware bounty is one of the few corners of the industry where individual researchers still routinely earn six figures per chain, and where small teams (2-4 people) can compete head-to-head with vendor red teams. The reason: physical devices are hard to test at scale, the bug surface is wide (firmware, bootloader, radios, mobile companion app, cloud backend), and vendors have historically underinvested in product security. See [[firmware-audit-methodology]] for what the actual audit work looks like, and [[hardware-glitching-deep]] / [[fault-injection-laser-emfi]] / [[side-channel-power-em]] for the physical-layer techniques that frequently show up in winning entries.

The flip side: ROI is unforgiving. You can spend three months on a router and find nothing payable, or spend three weeks and land a $20k chain. Target selection ([[target-selection-heuristics]]) and program selection ([[program-selection-tactics]]) matter more here than in web bounty because the iteration loop is slow.

## Venues and programs

### Pwn2Own (ZDI / Trend Micro)

Pwn2Own runs multiple events per year, each with hardware-relevant categories. Prizes and categories shift annually; consult the current contest rules before committing.

**Pwn2Own Toronto / Ireland (consumer / SOHO):**

- **SOHO Smashup** — chain WAN-side router exploit into a LAN device (printer, NAS, smart speaker). Top prize historically $100k+.
- **Router / WAN and LAN** — TP-Link, Synology, Netgear, Asus, Ubiquiti, etc. Typical $20k-$50k per category.
- **NAS** — Synology, QNAP, Western Digital, TrueNAS. $40k-$50k range.
- **Smart speaker / home automation** — Sonos, Amazon Echo, Google Nest. $40k-$60k.
- **Printer** — Canon, HP, Lexmark, Brother. $20k.
- **Phone** — Samsung Galaxy, Google Pixel, iPhone. Up to $300k for full chain with persistence; see [[android-mali-gpu-exploitation]] for one common path.
- **Mobile messaging** — zero-click on WhatsApp, Signal, iMessage. $300k+.

**Pwn2Own Automotive (Tokyo):**

- Tesla (infotainment, modem, autopilot, charger). Tesla itself awarded $200k+ in past contests, plus the car.
- EV chargers (ChargePoint, Wallbox, JuiceBox, Ubiquiti).
- IVI (in-vehicle infotainment) from Alpine, Pioneer, Sony.
- Tier prizes range $20k-$100k per category.

**Pwn2Own Ireland / Miami (ICS/SCADA):**

- Control server, OPC UA server, DNP3 gateway, EWS (engineering workstation), HMI. See [[opc-ua-attacks]], [[dnp3-attacks-deep]], [[modbus-attacks-deep]], and [[ics-scada-protocols-attacks]].
- Prizes $20k-$40k typical; bonus for chains.

**Rules to know:**

- You bring a deterministic, working exploit. Three attempts in a 5-10 minute window.
- Targets are latest stable firmware as of contest cutoff date.
- Winning bugs go to ZDI and are reported to vendors with a 90-day disclosure window.
- If your bug collides with another contestant (same root cause), payout is reduced or split.
- Travel and per-diem are on you. Two or three failed attempts is an expensive trip.

### ZDI year-round

Outside contests, Zero Day Initiative buys bugs on a rolling basis. Payouts are lower than Pwn2Own (usually $1k-$15k for IoT/embedded) but you avoid the contest collision risk. ZDI also runs a researcher leaderboard with annual bonuses for top contributors. Submission requires reliable PoC and write-up; ZDI handles vendor coordination.

### Apple Security Bounty

Apple's program covers hardware-adjacent categories that interest bounty hunters:

- Lockdown Mode bypass: up to $2M with bonuses.
- Zero-click kernel with persistence and bypass of Lockdown Mode: $1M+.
- Secure Enclave Processor (SEP) compromise: up to $500k.
- Network attack without user interaction reaching kernel: $250k.
- Hardware feature like Find My, AirTag, HomePod, Apple TV are in-scope but pay less.

Apple pays on a working chain demonstrating impact. Reports must be precise; see [[report-writing-step-by-step]]. Apple's payout speed has improved since 2023 but still trails Google.

### Google / Pixel VRP

Pixel hardware (Titan M2, Tensor SoC, modem) has dedicated tiers in the Android VRP / Google VRP:

- Pixel Titan M / Titan M2 chain with persistence: $1M+.
- Modem RCE without user interaction (see [[android-baseband-attacks]]): $300k-$1M.
- Trusted Execution Environment (Trusty TEE) compromise: $250k+.
- Pixel-specific kernel: $250k.

Google publishes a clear rubric; chains that combine remote entry + local privesc + persistence hit top tier. See [[case-study-google-vrp-writeup-patterns]] for how winning reports are structured.

### Samsung TRP and SKBP

- **Samsung Mobile Security Rewards Program** — phones and Tizen-based wearables. Up to $1M for a full chain on the latest Galaxy flagship.
- **Samsung Knox Vulnerability Rewards** — Knox container, TEEgris TEE, Samsung Pay.
- **TRP / Samsung Knox Bug Bounty (SKBP)** — broader scope including SmartThings (IoT), Bixby, Galaxy Wearable. Payouts $1k-$200k.

Samsung pays in cash and is one of the more active payers in mobile hardware bounty.

### Tesla VRP

Tesla runs its own program plus participates in Pwn2Own Automotive:

- Infotainment, autopilot ECU, modem, gateway ECU, charging controllers.
- Past awards include vehicle ownership (the actual car) for full chains.
- Tesla's program is one of the few where you can submit physical-access vulnerabilities and get paid, though remote bugs pay more.

### Cisco PSIRT and Meraki

Cisco runs a coordinated disclosure program for enterprise networking gear (routers, switches, firewalls, SD-WAN, Webex hardware). Historically disclosure-only, but Meraki added a paid bounty for its cloud-managed devices.

### Other vendor programs worth tracking

- Synology, QNAP, Western Digital — NAS, paid bounty in $300-$10k range.
- Netgear, TP-Link, Asus — routers, paid via Bugcrowd or HackerOne.
- Lexmark, HP, Canon — printers, mostly disclosure-only outside Pwn2Own.
- Sonos, Bose — smart speakers, disclosure-only.
- Bosch, Continental, Aptiv — automotive tier-1 suppliers, mixed.
- Schneider Electric, Siemens, Rockwell, ABB — ICS vendors, mostly disclosure-only, but their bugs are highly valuable at Pwn2Own.

## In-the-wild rewards vs disclosure-only

Three buckets to keep straight:

1. **Cash bounty** — vendor pays you for a working PoC. Apple, Google, Samsung, Tesla, Synology, Meraki.
2. **ZDI brokerage** — ZDI buys, vendor gets reported, you get paid but credit to ZDI.
3. **Disclosure-only / CVE-only** — vendor accepts the report, credits you in advisory, no cash. Most ICS vendors, many networking vendors. Useful for resume / conference talks / [[case-study-orange-tsai-research-pattern]]-style portfolio building, not for income.

A practical pipeline mixes all three: chase cash bounties for income, brokerage for backstop, disclosure-only for research that builds reputation and feeds future paid work. See [[burnout-and-pipeline]].

## Defensive baseline (vendor view)

If you're a vendor running a hardware bounty program, things that materially change researcher outcomes:

- Publish clear scope and payout tiers. Vague programs get fewer good reports.
- Provide test devices or a hardware loaner program. Lowers entry cost dramatically.
- Maintain a reproducible firmware download portal with old versions (lets researchers diff patches, see [[one-day-from-patch-diff]]).
- Document the threat model: what's in-scope as remote, network-local, physical, with-debug-port. Researchers want to know what counts.
- Pay on validated PoC, not on patch shipped. Otherwise researchers wait months for payment.
- Have a PSIRT that actually triages firmware bugs (many vendors route everything through IT helpdesk).

## Workflow to study

1. Read the current Pwn2Own rules for whichever contest is nearest. Note exact targets, firmware versions, and prize tiers.
2. Pick one target where you can afford the device and have time to invest 4-12 weeks. Use [[target-selection-heuristics]].
3. Acquire the device. Extract firmware ([[firmware-extraction]]) — UART, JTAG, SPI flash dump, or vendor update package.
4. Set up emulation if possible ([[firmware-emulation-firmadyne-qemu]]) so you can iterate quickly without bricking hardware.
5. Audit the network-facing services first (web UI, UPnP, mDNS, custom protocols). Most winning router and NAS bugs are in the web UI or admin API. See [[firmware-audit-methodology]].
6. For mobile and automotive, study the baseband, modem, and IVI architecture. [[android-baseband-attacks]], [[ios-baseband-attacks]], [[can-bus-attacks]], [[obd2-uds-attacks]].
7. Build a reliable, deterministic PoC. Pwn2Own and Apple/Google require it. Flaky exploits get rejected.
8. Write the report with clear repro and impact. [[report-writing]], [[demonstrating-impact]].
9. For contests: rehearse the on-stage demo. Three attempts, timed. Bring a backup laptop.
10. For year-round programs: submit via the official portal, follow up on schedule, don't disclose publicly until coordinated. [[disclosure-and-comms]], [[responsible-disclosure-across-jurisdictions]].

## Getting into hardware bounty

**Lab investment:** start with $500-$2k of basic gear. Logic analyzer (Saleae Logic 8 or clone), multimeter, soldering iron, USB-UART adapter, JTAG/SWD probe (J-Link or Black Magic Probe), SPI/I2C flash reader (CH341A or FT2232H), bench power supply with current limit. Add a hot-air rework station and microscope when you start desoldering SOIC-8 flash chips. See [[building-a-research-home-lab]].

**Target selection rules:**

- Pick a device under $300 if possible. You will brick at least one.
- Prefer targets with active patch history — means the vendor cares enough to ship updates, and you can diff for n-days ([[n-day-rapid-exploitation]], [[known-vuln-workflow]]).
- Prefer targets with an active Pwn2Own category. Means there's a market.
- Avoid devices with hardware secure boot if you're new — you'll spend more time on glitching ([[hardware-glitching-deep]]) than on bugs.

**Evidence and PoC quality:** vendors and ZDI care about reliability. A 70% reliable exploit is unpayable at contest level. Spend the last 25% of your time on reliability, error handling, and bypassing whatever mitigations apply (ASLR, KASLR, stack cookies, CFI). See [[demonstrating-impact]].

**Pipeline mindset:** treat hardware bounty as a portfolio. One ongoing Pwn2Own target, one ZDI submission in flight, one quick n-day chase, one research project for conference / writeup. [[automation-and-rinse-repeat]], [[continuous-recon-automation]] apply less here than in web, but [[keeping-up-with-research-feeds]] is critical — new techniques (bootloader glitch, modem RCE, SMM bug) reset the playing field.

## Related

- [[pwn2own-2024-2025-research-roundup]]
- [[firmware-audit-methodology]]
- [[firmware-extraction]]
- [[firmware-emulation-firmadyne-qemu]]
- [[bootloader-and-secure-boot-attacks]]
- [[hardware-glitching-deep]]
- [[fault-injection-laser-emfi]]
- [[side-channel-power-em]]
- [[android-baseband-attacks]]
- [[ios-baseband-attacks]]
- [[android-mali-gpu-exploitation]]
- [[can-bus-attacks]]
- [[obd2-uds-attacks]]
- [[ics-scada-protocols-attacks]]
- [[opc-ua-attacks]]
- [[dnp3-attacks-deep]]
- [[modbus-attacks-deep]]
- [[uart-jtag-debug]]
- [[building-a-research-home-lab]]
- [[program-selection-tactics]]
- [[target-selection-heuristics]]
- [[demonstrating-impact]]
- [[report-writing]]
- [[disclosure-and-comms]]
- [[case-study-google-vrp-writeup-patterns]]

## References

- [Pwn2Own contest archive (Zero Day Initiative)](https://www.zerodayinitiative.com/Pwn2Own/)
- [Apple Security Bounty categories and payouts](https://security.apple.com/bounty/categories/)
- [Google and Android VRP rules and rewards](https://bughunters.google.com/about/rules/android-friends)
- [Samsung Mobile Security Rewards Program](https://security.samsungmobile.com/rewardsProgram.smsb)
- [Tesla Vulnerability Reporting Policy](https://www.tesla.com/about/security)
- [ZDI researcher submission and program overview](https://www.zerodayinitiative.com/about/benefits/)
