---
title: Android baseband (cellular modem) attacks
slug: android-baseband-attacks
aliases: [android-modem-attacks, android-baseband, qualcomm-exynos-baseband]
---

> **TL;DR:** The cellular modem (baseband) processor in a smartphone runs a separate firmware from the application processor and handles 2G/3G/4G/5G protocol stacks. A bug in baseband firmware reachable over-the-air gives **remote code execution without user interaction** at a processor that has DMA into device memory. Historically rare in public; Pwn2Own added baseband categories, and Project Zero / Google TAG have disclosed in-the-wild exploitation against Samsung Exynos and Qualcomm modems. Companion to [[ios-baseband-attacks]] and [[wifi-and-802-11-primer]].

## Why baseband matters

- **Zero-click remote** — attack happens over cellular RF; no user action.
- **Separate processor**, often with privileged DMA into application-processor RAM.
- **Closed firmware** from Qualcomm / Samsung / MediaTek — limited public research access.
- **Long persistence** — modem firmware survives many OS reinstalls.
- **Carrier interception capability** — IMEI / IMSI tracking, lawful intercept abuse.

## The cellular surface

A baseband implements a large stack of protocols:
- **2G** GSM (still supported for compatibility).
- **3G** UMTS / WCDMA.
- **4G** LTE.
- **5G** NR (Standalone + Non-Standalone).
- **VoLTE / VoNR** voice signalling.
- **SMS** signalling (PDU parsing).
- **Carrier provisioning** (OTA profile updates).
- **MM (Mobility Management)**, **CM (Call Management)**, **SM (Session Management)** layers.

Each protocol has its own parser (NAS, S1AP, RRC, SIB), many decades old, often C code with classic memory-corruption bugs.

## Class 1 — Memory corruption in protocol parsers

Baseband firmware parses Cell Broadcast, paging, RRC connection setup, NAS messages — all attacker-controllable via rogue base station. Buffer overflows, integer overflows, heap corruption.

Pwn2Own 2024 (Tokyo) and TAG reports document baseband memory corruption with no user interaction:
- **Samsung Exynos modem CVE-2023-24033** (and a cluster of others) — over-the-air RCE.
- Multiple **Qualcomm modem CVEs** in 2023–2024 with similar reach.

## Class 2 — SMS / signalling parser

SMS PDU contains binary fields. Bugs in TPDU parser allow:
- Specially crafted SMS → memory corruption in modem.
- "Class 0" / silent SMS hitting parser before user-visible delivery.

This is the highest-reach class: anyone with the target's phone number can attempt.

## Class 3 — IMS / VoLTE

VoLTE introduces SIP-over-IPsec on the cellular interface. SIP-parsing bugs in the modem are reachable via rogue or roaming network.

## Class 4 — Inter-processor communication

The modem and application processor talk via a shared memory + interrupt protocol. Bugs:
- Modem writes outside shared region → AP kernel memory corruption.
- AP-side handler doesn't validate modem messages → AP-side memory corruption.

This is the bridge from "modem RCE" to "device root".

## Class 5 — Provisioning / OMA-DM

Operator provisioning over OMA-DM or eSIM RSP. Vulnerabilities here allow attackers (with carrier-level access or rogue) to push attacker-controlled configuration profiles.

## Rogue base station

Setting up a fake LTE / NR base station is increasingly accessible:
- **srsRAN** (open-source LTE stack) + USRP / BladeRF SDR.
- **OpenAirInterface** for 4G/5G.
- Used by researchers and (in regulated jurisdictions) law enforcement.

For research, only use in shielded enclosures; emitting on cellular bands without licence is illegal in most jurisdictions.

## In-the-wild disclosures

- **Project Zero — Samsung Exynos modem (March 2023)** — disclosed 18 vulnerabilities; recommended users disable VoLTE and Wi-Fi calling pending patches.
- **Google TAG** — periodic reports identify modem exploitation by surveillance vendors (NSO, Intellexa adjacent).
- **Pwn2Own Tokyo / Mobile** — public modem exploit demonstrations 2024+.

## Defensive baseline

For users:
- **Apply security patches** as soon as available.
- **Disable VoLTE / 5G** if Project Zero or vendor advises during open vuln window.
- **Limit roaming** in high-risk locations.
- **Carrier choice** — some carriers / countries have stronger SS7 / Diameter security than others.

For platform vendors:
- **Sandbox the modem** — Apple does aggressively; Android variable.
- **Reduce IPC surface** between modem and AP.
- **Pre-release fuzzing** of protocol parsers.
- **Coordinated patching pipeline** with modem suppliers.

## Workflow to study

This is **research-grade** — most learners cannot easily reproduce.

1. Read Project Zero's Samsung Exynos baseband series end-to-end.
2. Study public modem-firmware extraction techniques (carrier-specific).
3. Examine `qualcomm-mss` / `samsung-shannon` firmware structure with `binwalk` and `ghidra`.
4. Identify NAS / RRC parser functions.
5. (For licensed researchers only) Set up a shielded srsRAN environment.

## Detection

- Anomalous modem reboots.
- Excess battery drain from modem (sustained activity).
- IMSI catcher detection apps (limited reliability).
- Cell-ID fingerprinting against known-good baseline.

## Related

- [[ios-baseband-attacks]]
- [[wifi-and-802-11-primer]]
- [[sdr-and-radio-recon]]
- [[android-trusty-tee-attacks]]
- [[firmware-extraction]]
- [[firmware-emulation-firmadyne-qemu]]

## References
- [Project Zero — Samsung Exynos modem disclosures](https://googleprojectzero.blogspot.com/2023/03/multiple-internet-to-baseband-remote-rce.html)
- [Google TAG — surveillance vendor reports](https://blog.google/threat-analysis-group/)
- [srsRAN](https://www.srsran.com/)
- [OpenAirInterface](https://openairinterface.org/)
- [Pwn2Own Mobile / Tokyo result archives — ZDI](https://www.zerodayinitiative.com/blog/)
- See also: [[ios-baseband-attacks]], [[wifi-and-802-11-primer]], [[sdr-and-radio-recon]], [[firmware-extraction]]
