---
title: LTE NAS / RRC protocol attacks
slug: lte-nas-rrc-attacks
aliases: [lte-nas-attacks, lte-rrc-attacks, 4g-protocol-attacks]
---

> **TL;DR:** LTE's control plane sits on two stacks: Non-Access Stratum (NAS) between UE and MME, and Radio Resource Control (RRC) between UE and eNodeB. Both have pre-authentication windows where attackers can sniff IMSIs, force downgrades to 2G, hijack paging, or feed malformed EMM/ESM messages to crash basebands. Pair this with [[android-baseband-attacks]] and [[ios-baseband-attacks]] for the implementation-bug side, and with [[sdr-and-radio-recon]] for the RF and tooling foundation.

## Why it matters

Most LTE protocol research is now a precursor to 5G work, but 4G remains the fallback layer everywhere. Real-world attacks on subscribers still happen on LTE because:

- IMSI catchers and downgrade boxes are still sold and seized worldwide.
- Carriers leave 2G/3G fallback enabled, so any LTE attack that triggers a redirect ends in a weaker stack.
- Many basebands share LTE NAS parsers across modem generations — a NAS bug found on LTE often reaches 5G NSA as well.
- Operator misconfigurations (missing integrity protection on certain NAS messages, weak `KASME` rotation) survive for years.

If you study iOS/Android modem CVEs alongside the LTE protocol, you can read advisories like Pwn2Own Mobile baseband entries and immediately see which procedure the bug rides on. See [[pwn2own-2024-2025-research-roundup]] for recent baseband-related Pwn2Own entries.

## LTE control-plane primer

### NAS: EMM and ESM

NAS sits above RRC and terminates at the MME in the core. It has two sublayers:

- **EMM (EPS Mobility Management):** Attach, Detach, Tracking Area Update, Authentication, Security Mode Command, Identity Request, Service Request.
- **ESM (EPS Session Management):** PDN connectivity, bearer setup/modification/deactivation.

The key procedure to memorise is the **Attach**:

1. UE sends `Attach Request` (NAS, plaintext) with IMSI or GUTI.
2. MME runs `Authentication Request` / `Authentication Response` (AKA: RAND, AUTN, RES).
3. MME issues `Security Mode Command` (selects EIA/EEA algorithms, integrity-protected).
4. UE replies `Security Mode Complete` (now ciphered + integrity-protected).
5. ESM messages (`PDN Connectivity Request`, default bearer) complete the attach.

Anything before step 3 is unauthenticated. That is the entire attack surface for IMSI catchers and pre-auth NAS fuzzing.

### RRC: UE to eNodeB

RRC handles the radio link: connection establishment, measurement reports, handovers, paging delivery. The relevant pre-auth messages are:

- `RRCConnectionRequest` / `RRCConnectionSetup` / `RRCConnectionSetupComplete` (the last one wraps NAS Attach Request).
- `Paging` (broadcast, identifies UEs by S-TMSI or IMSI).
- `RRCConnectionReconfiguration` (used for handover; can carry redirects to GERAN/UTRAN).
- `RRCConnectionRelease` with `redirectedCarrierInfo` — the classic downgrade primitive.

System Information Blocks (SIB1, SIB2, SIB3) on broadcast channels advertise PLMN, cell parameters, and neighbour cells. Rogue eNodeBs forge these to lure UEs.

## Attack classes

### IMSI catching and identity exposure

- Rogue eNodeB advertises a strong cell with the operator's PLMN, the UE camps, the rogue sends `Identity Request (IMSI)` before security is set up. UE replies in cleartext.
- GUTI reallocation weaknesses: some MMEs reuse GUTIs predictably, enabling tracking without exposing IMSI.
- Companion: [[sdr-and-radio-recon]] for the RF capture pipeline.

### Downgrade and bidding-down

- After capturing the UE, the rogue sends `RRCConnectionRelease` with `redirectedCarrierInfo` pointing at a 2G ARFCN, forcing GSM camping where A5/1 or A5/2 attacks become viable.
- NAS-level `TAU Reject` with cause `EPS services not allowed` can also push the UE to legacy RATs.
- 5G mitigates with mandatory integrity protection on more NAS messages and stricter redirect rules, but only when SA is deployed.

### Paging attacks

- Paging messages are broadcast and unauthenticated. Correlating paging occasions with phone numbers (via silent SMS or VoLTE) lets attackers locate or fingerprint subscribers — the basis of "ToRPEDO" and follow-on research.
- Smart-paging variants enable targeted DoS by hammering paging channels with spoofed identifiers.

### EMM/ESM message-handling bugs

- Malformed `Attach Accept`, `Authentication Request`, `EMM Information`, or ESM `Activate Default EPS Bearer Context Request` messages are classic baseband crash vectors.
- Bugs often hide in optional IEs (Information Elements) with length fields the parser does not bound-check.
- See [[android-baseband-attacks]] and [[ios-baseband-attacks]] for vendor-specific writeups (Exynos, MediaTek, Qualcomm, Intel/Apple).

### Security context attacks

- `KASME` is derived from `CK`, `IK`, and SN id. Compromise of the operator's HSS or of long-lived keys cascades into all derived keys (`KNASenc`, `KNASint`, `KeNB`, `KUPenc`).
- Replay of old `Security Mode Command` with stale `KASME` is mitigated by NAS COUNT, but implementation bugs in COUNT handling have appeared.
- SIM-cloning and OTA SMS attacks (Simjacker, WIBattack) sit adjacent — they target the UICC, not NAS, but feed the same threat model.

### Pre-auth NAS reject abuse

- `Attach Reject` with causes like `#7 EPS services not allowed`, `#8 EPS services and non-EPS services not allowed`, `#14 EPS services not allowed in this PLMN` can permanently disable LTE on the UE until reboot or SIM reinsertion. Useful for persistent DoS by a rogue cell.

## Research toolchain

### srsRAN (formerly srsLTE)

- Open-source LTE/5G stack. Provides `srsUE`, `srsENB`, and `srsEPC` (4G) or `Open5GS` integration (5G).
- Run a full eNodeB + EPC on a single host with a USRP B210 or LimeSDR. Strip down `srsENB` to forge SIBs and craft RRC messages.

### OpenAirInterface (OAI)

- More research-grade, closer to 3GPP timelines. Better for L1 modifications and 5G NR experiments.
- Heavier build, but indispensable if you want to fuzz at the PHY/MAC boundary.

### Fuzzers and analyzers

- **LTEFuzz / DoLTEst:** academic NAS/RRC fuzzers; LTEFuzz produced dozens of CVEs against commercial UEs and networks.
- **5GReasoner / LTEInspector:** model-checking frameworks that catch logic flaws in procedures.
- **Wireshark with `nas-eps` and `lte-rrc` dissectors:** the first tool to learn. Pair with `mobile-insight` for UE-side captures.

### SIM/USIM tooling

- `pySim`, `osmo-sim-auth`, programmable USIMs (sysmoUSIM). Needed if you want to bring your own test SIM to a private core.

## Regulatory and ethics

- Transmitting on licensed LTE bands without authorisation is illegal in essentially every jurisdiction.
- Use **shielded enclosures (Faraday tents)**, **band 46/47 / CBRS in some regions with proper licensing**, or **lab-only RF cabling between SDRs and UEs**.
- Many universities operate research PLMNs under experimental licenses; partner with one rather than going solo.
- See [[responsible-disclosure-across-jurisdictions]] when reporting findings against operators — telecom regulators are often a required notification path.

## Workflow to study

1. **Read the specs.** 3GPP TS 24.301 (NAS), TS 36.331 (RRC), TS 33.401 (security). Skim, then re-read with Wireshark traces open.
2. **Capture clean traffic.** Stand up `srsENB + srsEPC + srsUE` in loopback. Decode every message of Attach, TAU, paging, detach.
3. **Reproduce a known attack.** Start with `RRCConnectionRelease` redirect to a fake GERAN ARFCN. Read the LTEFuzz paper and replay one of its test cases.
4. **Map bug classes to CVEs.** Pick three baseband CVEs (e.g., Samsung Exynos 2023, MediaTek 2022, Qualcomm 2024) and locate the exact NAS/RRC message and IE involved.
5. **Build a fuzzer harness.** Modify srsENB to inject malformed IEs into one chosen message; observe UE behaviour over `adb logcat` (Android) or via JTAG on a dev board.
6. **Pivot to 5G NSA then SA.** Re-run the same procedures in 5G mode and note what SUCI/SUPI separation, mandatory integrity protection, and 5G AKA change.
7. **Document a case study.** Pick one CVE chain and write it up following [[case-study-orange-tsai-research-pattern]].

## 5G mitigations to know

- **SUCI (Subscription Concealed Identifier):** SUPI is encrypted with the home network's public key before transmission — kills classic IMSI catchers when SUCI is enforced.
- **Mandatory integrity protection on more NAS messages**, including some pre-security ones in 5G SA.
- **Stricter redirect rules:** `RRCRelease` redirects to lower RATs require integrity-protected context.
- **AS/NAS algorithm negotiation hardening**, removing weak null-integrity options outside emergency calls.
- Caveats: 5G NSA reuses LTE NAS, so most LTE attacks still apply. Only standalone 5G with SUCI enforced closes the IMSI-catching gap.

## Defensive baseline for operators

- Disable 2G fallback where regulators allow, or restrict it to emergency calls only.
- Monitor for anomalous `Attach Reject` and `TAU Reject` cause codes across the radio access network.
- Deploy SIB integrity checks on the UE side via MNO-distributed apps (some operators do this).
- Roll GUTIs frequently and unpredictably.
- For enterprise/private LTE: enforce 5G SA from day one and require SUCI.

## Related

- [[android-baseband-attacks]]
- [[ios-baseband-attacks]]
- [[sdr-and-radio-recon]]
- [[wifi-and-802-11-primer]]
- [[gps-gnss-spoofing]]
- [[pwn2own-2024-2025-research-roundup]]
- [[building-a-research-home-lab]]
- [[responsible-disclosure-across-jurisdictions]]
- [[case-study-orange-tsai-research-pattern]]

## References

- 3GPP TS 24.301 NAS for EPS: https://www.3gpp.org/dynareport/24301.htm
- 3GPP TS 36.331 E-UTRA RRC: https://www.3gpp.org/dynareport/36331.htm
- 3GPP TS 33.401 SAE security architecture: https://www.3gpp.org/dynareport/33401.htm
- srsRAN project: https://www.srsran.com/
- OpenAirInterface: https://openairinterface.org/
- LTEFuzz (Kim et al., S&P 2019): https://syssec.kaist.ac.kr/pub/2019/kim_sp_2019.pdf
