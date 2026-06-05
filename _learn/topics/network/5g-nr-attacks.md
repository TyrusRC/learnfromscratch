---
title: 5G NR attacks
slug: 5g-nr-attacks
aliases: [5g-attacks, 5g-nr-security]
---

> **TL;DR:** 5G New Radio (NR) keeps a lot of LTE's NAS/RRC heritage but rewires the core into a service-based architecture (SBA) of HTTP/2 microservices, encrypts the long-term subscriber ID (SUPI) into a per-session SUCI, and introduces network slicing plus MEC as fresh attack surface. Treat this note as the 5G companion to [[lte-nas-rrc-attacks]] and [[cellular-femtocell-attacks]]; review it alongside [[sdr-and-radio-recon]] when you build a lab.

## Why it matters

5G is no longer just "faster LTE." Operators deploy it in two flavours — 5G Non-Standalone (NSA), which reuses the LTE EPC as anchor, and 5G Standalone (SA), which introduces the full 5GC with SBA. The attacker reality is that NSA inherits every legacy LTE/NAS weakness, while SA opens HTTP/2 + OAuth2 + network slicing as new abuse classes. Enterprises adopting private 5G (factories, ports, campuses) frequently expose the core (AMF, SMF, UPF, NRF) on flat management VLANs, so "telecom" bugs become normal pentest bugs.

Key reasons to spend time here:

- Critical-infrastructure connectivity (utilities, hospitals, defence) increasingly runs on private 5G SA.
- The SBA control plane uses HTTP/2 and JSON, so your web-app skills from [[ssrf]], [[http-request-smuggling]], and [[http-smuggling-modern-variants]] transfer directly.
- MEC (Multi-access Edge Computing) co-locates third-party workloads with telco signalling, blurring the line between cloud pentests and core-network attacks.
- Roaming and inter-PLMN traffic still rides legacy Diameter/SS7 in many deployments, leaving downgrade paths.

## Architecture in one screen

### Radio side

- **UE** — User Equipment (handset, IoT module, CPE).
- **gNB** — 5G base station, split into CU (Central Unit) and DU (Distributed Unit), often with an RU (Radio Unit) over fronthaul (eCPRI).
- **N1/N2/N3** reference points carry NAS, control, and user-plane traffic respectively.

### Core (5GC) network functions

- **AMF** — Access and Mobility Management Function (NAS termination, registration).
- **SMF** — Session Management Function (PDU sessions, IP allocation).
- **UPF** — User Plane Function (GTP-U forwarding, lawful intercept hook).
- **AUSF / UDM / ARPF / SIDF** — authentication, subscriber data, SUCI deconcealment.
- **NRF** — NF Repository Function, the "service registry" all NFs query.
- **NEF / NSSF / PCF / SEPP** — exposure, slice selection, policy, and roaming security edge.

### Service-based architecture (SBA)

NF-to-NF calls are HTTP/2 with JSON payloads, mTLS between NFs, and OAuth2 access tokens issued by the NRF. This is REST-ish telecom — every interface (N7, N8, N12, N22 ...) is a documented Open API spec from 3GPP.

## Classes, patterns, and process

### Identity privacy: SUCI vs SUPI vs IMSI

- LTE leaked the IMSI in cleartext during initial attach — the foundation of every "IMSI catcher."
- 5G replaces this with **SUPI** (the long-term ID) which is never sent in cleartext. The UE encrypts it with the home network's public key into the **SUCI** (Subscription Concealed Identifier) using ECIES.
- Attacks worth studying:
  - **Null-scheme SUCI**: if the operator provisions scheme 0 (null encryption), SUCI == SUPI in cleartext — game over.
  - **SIDF oracle**: timing/error oracles on the home network's SUCI deconcealment function.
  - **Linkability via 5G-GUTI** reallocation patterns when the AMF is lazy.

See [[ios-baseband-attacks]] and [[android-baseband-attacks]] for the UE-side modem code that actually parses these.

### 5G-AKA and EAP-AKA'

- 5G-AKA is the default for 3GPP access; EAP-AKA' is used for non-3GPP (Wi-Fi offload).
- Mutual auth between UE and home network, with the serving network getting a "proof of presence" anchor key (KSEAF).
- Research themes:
  - Formal model failures (Basin et al., "A Formal Analysis of 5G Authentication") — race conditions in SQN handling.
  - Activity/location leak via failed-auth responses (MAC failure vs sync failure distinguishable).
  - Replay across serving networks if SEPP filtering is weak.

### Downgrade and bidding-down attacks

- **5G-to-LTE NSA fallback**: rogue gNB advertises no SA support so the UE drops to NSA mode, then to LTE-only — landing you in [[lte-nas-rrc-attacks]] territory.
- **RRC redirection / cell barring** abuse to force reselection to attacker-controlled LTE/3G cells.
- **NAS security-mode-command** tampering when integrity is not yet activated (pre-AS-security window).

### SBA / HTTP/2 microservice abuse

- **NRF token theft / forgery** — if NRF issues over-broad OAuth2 scopes, a compromised NF can call sibling NFs it shouldn't.
- **SBI request smuggling** — HTTP/2 frame confusion between proxy and backend (see [[http-smuggling-modern-variants]]).
- **SBI SSRF** — NF that accepts callback URLs (`notifyUri`) without validation; pivot via [[ssrf]] patterns.
- **SEPP bypass** — N32 inter-PLMN traffic should be protected by the Security Edge Protection Proxy. Weak JSON-patch validation in N32-f has produced real CVEs.
- **OpenAPI implementation drift** — vendors generate stubs from 3GPP YAMLs; auth checks on optional fields are often missing.

### Network slicing risks

- A slice is identified by **S-NSSAI** (SST + SD). Tenants assume hard isolation; reality is shared UPF/AMF in many deployments.
- Cross-slice attacks:
  - NSSAI spoofing during registration to land in a higher-trust slice.
  - Side-channels via shared UPF queues or shared NRF.
  - Policy bypass via PCF rules that don't pin per-slice.

### MEC (Multi-access Edge Computing)

- MEC hosts run third-party apps next to the UPF for low latency (AR/VR, V2X, industrial control).
- Attack surface looks like a hostile multi-tenant Kubernetes cluster glued to the telco data plane — see [[cloud-ir-k8s-audit-logs]].
- Risks: container escape into UPF host, abuse of MEC traffic-steering APIs to mirror subscriber traffic, exposed Prometheus/Grafana on the OAM VLAN.

### Fronthaul and O-RAN

- Open RAN splits CU/DU/RU and uses open interfaces (E2, O1, A1) plus the **RIC** (RAN Intelligent Controller).
- New attack surface: xApps/rApps as untrusted plugins, E2 messages that can reconfigure the RAN, software supply chain of community xApps.
- O-RAN Alliance security working group publishes a threat model worth reading end-to-end.

### Early CVE / research landmarks

- CVE-2021-45462 and friends in open5gs / free5GC NRF and AMF parsers.
- Positive Technologies' annual "5G standalone core security" reports.
- BlackHat/DEF CON talks by Altaf Shaik and Ravishankar Borgaonkar on rogue gNB testbeds.
- Academic: "5GReasoner," "BaseSpec," "DoLTEst" (LTE but methodology carries over).

## Defensive baseline

For operators and private-5G adopters:

- Disable null SUCI scheme; enforce profile A or B with rotated keys.
- Mutual TLS on every SBI interface, with short-lived NRF OAuth2 tokens scoped per service.
- Validate `notifyUri` / callback URLs against an allowlist; treat them as SSRF sinks.
- Deploy SEPP for every roaming relationship and harden N32 JSON-patch handling.
- Pin slices to dedicated NF instances when tenants demand isolation; document the threat model honestly when you can't.
- Segment OAM, signalling, and user-plane VLANs; never expose NRF / AMF management to corporate LAN.
- Monitor AKA failure ratios and SUCI deconcealment errors as fraud / IMSI-catcher signals.
- For O-RAN: sign xApps, run RIC in a hardened namespace, audit E2 policies.

Pair these controls with detection patterns from [[detection-engineering-pyramid-of-pain]] and [[siem-detection-use-case-catalog]].

## Workflow to study

1. **Read the standards spine** — 3GPP TS 33.501 (security architecture), TS 23.501 (system arch), TS 29.500-series (SBI). Skim, do not memorise.
2. **Stand up a lab** — open5gs or free5GC for the core, srsRAN Project or OpenAirInterface for the gNB, a USRP B210 or similar SDR. See [[building-a-research-home-lab]] and [[sdr-and-radio-recon]].
3. **Reproduce a known bug** — pick an open5gs NRF CVE, patch-diff it (see [[one-day-from-patch-diff]]), exploit it on your lab.
4. **Fuzz NAS and SBI** — frameworks: 5GReasoner, dotdotpwn-style HTTP/2 fuzzers, custom Scapy NAS layers.
5. **Test downgrade paths** — script a rogue gNB that refuses SA capability and watch UE behaviour.
6. **Study a real disclosure** — read Positive Technologies, P1 Security, and ENISA 5G threat reports cover to cover.
7. **Write it up** — apply [[report-writing-for-pentesters]] and [[demonstrating-impact]] to translate "core network bug" into business risk.

## Related

- [[lte-nas-rrc-attacks]]
- [[cellular-femtocell-attacks]]
- [[wifi-and-802-11-primer]]
- [[sdr-and-radio-recon]]
- [[gps-gnss-spoofing]]
- [[ios-baseband-attacks]]
- [[android-baseband-attacks]]
- [[ssrf]]
- [[http-smuggling-modern-variants]]
- [[cloud-ir-k8s-audit-logs]]
- [[building-a-research-home-lab]]
- [[one-day-from-patch-diff]]
- [[detection-engineering-pyramid-of-pain]]

## References

- <https://www.3gpp.org/ftp/Specs/archive/33_series/33.501/> — 3GPP TS 33.501, 5G security architecture and procedures.
- <https://www.enisa.europa.eu/publications/enisa-threat-landscape-for-5g-networks> — ENISA 5G threat landscape report.
- <https://www.gsma.com/security/fs-31-baseline-security-controls/> — GSMA FS.31 baseline security controls for mobile networks.
- <https://www.o-ran.org/specifications> — O-RAN Alliance specifications including security working group documents.
- <https://global.ptsecurity.com/analytics/5g-standalone-core-security-research> — Positive Technologies 5G SA core security research.
- <https://www.usenix.org/conference/usenixsecurity21/presentation/hussain> — "5GReasoner" formal analysis of 5G control-plane protocols.
