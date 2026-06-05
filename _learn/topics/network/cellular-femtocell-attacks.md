---
title: Cellular femtocell / small-cell attacks
slug: cellular-femtocell-attacks
aliases: [femtocell-attacks, small-cell-attacks]
---

> **TL;DR:** Femtocells and enterprise small cells are mini base stations that operators ship into untrusted homes and offices. Once an attacker roots the device, they often get an eNB-equivalent position on the operator's network: IMSI capture, voice/SMS interception, and a foothold inside an IPSec backhaul tunnel. This note covers the architecture, the classic Verizon and SFR rooting research, modern Open RAN concerns, and defender baselines. Pair with [[lte-nas-rrc-attacks]], [[5g-nr-attacks]], and [[firmware-extraction]].

## Why it matters

Small cells sit on a strange trust boundary. The operator treats them as a remote piece of the radio access network, but physically they live on a customer kitchen shelf or in an enterprise wiring closet. A rooted unit gives the attacker:

- A legitimate eNB / gNB identity that nearby phones will camp onto.
- A working IPSec tunnel back to the operator security gateway (SecGW).
- Visibility into clear-text IMSI, voice (over Iuh or S1), SMS, and signalling on the device itself.
- Potential to pivot toward EPC / 5GC management interfaces if isolation is weak.

The same primitives apply to outdoor small cells, enterprise pico/microcells, and the new Open RAN distributed units. Companion radio notes: [[wifi-and-802-11-primer]], [[sdr-and-radio-recon]], [[android-baseband-attacks]], [[ios-baseband-attacks]].

## Architecture refresher

### Femtocell vs small cell vs Open RAN DU

- **Femtocell / HNB / HeNB:** consumer indoor unit, low transmit power, sold or leased by the carrier. UMTS HNB talks Iuh to a HNB-GW. LTE HeNB talks S1 to an HeNB-GW or directly to the MME via the SecGW.
- **Enterprise small cell:** higher capacity, often Ethernet/PoE, managed by enterprise IT plus the operator. Same protocols, more exposure.
- **Open RAN DU/RU:** disaggregated radio unit and distributed unit connected over fronthaul (eCPRI / O-RAN 7.2x) to a CU. Different attack surface but similar trust assumption — the RU is "in the field."

### Trust assumptions

The operator assumes the small cell is a hardened appliance:

- Secure boot, signed firmware, sealed enclosure.
- All backhaul over IPSec (IKEv2 + ESP) to a SecGW; certificate-based auth, sometimes EAP-AKA.
- TR-069 / TR-369 (USP) for management.
- Local subscriber whitelists (Closed Subscriber Group, CSG) so random phones cannot camp.

When any of those assumptions fail, the device becomes the most privileged rogue base station you can ask for.

## Attack classes and patterns

### Physical and firmware extraction

Most research starts here. See [[firmware-extraction]] for the generic playbook. Femtocell-specific tricks:

- UART headers under stickers or RF shields; bootloader often drops to U-Boot with default password.
- SPI/eMMC dump of the system flash to recover root filesystem, certificates, and IPSec PSKs.
- JTAG re-enabled by lifting a pull resistor on production boards.
- Recovery images served over TFTP during boot — capture and modify offline.

Cross-link: [[bootloader-and-secure-boot-attacks]], [[hardware-glitching-deep]], [[fault-injection-laser-emfi]] for when secure boot is actually enforced.

### Local root and persistence

Historical and recurring weaknesses:

- Hard-coded SSH or telnet credentials reachable on the LAN side.
- Debug web UIs bound to the WAN-facing interface.
- Setuid helpers callable from a constrained shell.
- Writable /etc with no integrity check after boot.
- TR-069 ACS URL configurable locally, allowing redirect to attacker ACS.

### Backhaul / IPSec abuse

Once root is achieved, the IPSec tunnel is the prize:

- Extract the device certificate and private key from the flash or TPM blob.
- Reuse them on attacker-controlled hardware to mint a "trusted" RAN node.
- Probe the SecGW's inner network for management plane services (Diameter, GTP-C, S1AP, X2, Xn, NETCONF).
- Look for flat layer-2 between small cells, allowing east-west attacks across customers.

The 2023 Open RAN security work and various operator post-mortems repeatedly show insufficient micro-segmentation behind the SecGW.

### eNB / gNB equivalent compromise

With a rooted unit and live tunnel, the attacker can:

- Force nearby UEs onto the rogue cell by transmitting a stronger signal on the operator's licensed frequency (yes, this is illegal almost everywhere — research only in shielded labs).
- Capture IMSIs during attach, defeating TMSI-only privacy. See [[lte-nas-rrc-attacks]] for the NAS-level details.
- Intercept SMS and voice that route through the femtocell.
- Replay or modify RRC and NAS messages — overlaps with the IMSI catcher and downgrade work in [[5g-nr-attacks]].

### Classic case studies

- **Verizon Samsung femtocell (2013, iSEC / Doug DePerry, Tom Ritter):** rooted Network Extender, demonstrated voice and SMS interception at DEF CON / Black Hat. Showed that "trusted RAN node" was a single device away.
- **SFR / Vodafone Sure Signal (UK, ~2011, The Hacker's Choice):** root via console password and signed-but-not-verified updates; full SIP credential theft for the operator core.
- **Various 2017–2020 enterprise small cell findings:** debug ports on outdoor units, weak TR-069 ACS auth, recycled IPSec PSKs across a vendor's fleet.

### Modern Open RAN concerns

O-RAN Alliance and ENISA threat models flag:

- Open fronthaul (7.2x) with optional or weak MACsec.
- xApps / rApps in the RIC executing partner code with access to RAN telemetry.
- Multi-vendor supply chain — disaggregation widens the attack surface even if each piece is hardened.
- Cloud-native CU/DU stacks reintroduce classic container and Kubernetes risk; see [[cloud-ir-k8s-audit-logs]].

## Defensive baseline

For operators and enterprises that deploy small cells:

- Treat every small cell as untrusted; enforce strict IPSec policy and per-device certificates issued by an internal PKI, never shared PSKs.
- Terminate tunnels on a SecGW that drops into a tightly segmented RAN management VRF — no flat east-west to other cells or to the EPC/5GC management plane.
- Disable WAN-side management; require ACS to push config over the tunnel only.
- Enforce secure boot with anti-rollback; sign and verify every firmware stage; provision keys in a TPM or secure element.
- Monitor for cells appearing from unexpected geolocations or with inconsistent SecGW selection.
- Rate-limit and alert on signalling anomalies on the S1/Iuh interfaces per cell (excessive IMSI requests, repeated detach/attach storms).
- Maintain a CSG enforcement layer in the core, not only in the cell; do not trust the cell to filter its own subscribers.
- For Open RAN: enforce MACsec on fronthaul, strict mTLS on O1/O2/A1, code review xApps/rApps like third-party plugins.

For pentesters with a legal scope:

- Get authorisation in writing covering radio emissions, SIM use, and any interception. National regulators care.
- Work inside an RF-shielded enclosure (Faraday tent) with test SIMs.
- Coordinate with the operator's security team — small cells often beacon home and will be noticed.

## Workflow to study

1. Read the Verizon Network Extender DEF CON 21 talk and slides; map each step (UART, root, certificate extraction, IMSI capture) to the architecture above.
2. Read the THC Vodafone Sure Signal write-up and note how trivial bugs cascaded to full SIP theft.
3. Build a lab tower with srsRAN or Open5GS plus a controlled SDR (see [[sdr-and-radio-recon]]) and a test SIM to understand NAS/RRC flows before touching real femtocells.
4. Pick up a retired carrier femtocell on eBay; practice firmware extraction per [[firmware-extraction]] and diff against any known dumps.
5. Read O-RAN WG11 security specifications and ENISA's 5G RAN threat landscape; relate each control to a real failure mode above.
6. Track Pwn2Own Mobile and SSTIC for newer baseband and small-cell research; cross with [[pwn2own-2024-2025-research-roundup]].
7. Build a detection use case in your SIEM for anomalous S1/Iuh signalling and add it to your [[siem-detection-use-case-catalog]].

## Related

- [[lte-nas-rrc-attacks]]
- [[5g-nr-attacks]]
- [[firmware-extraction]]
- [[android-baseband-attacks]]
- [[ios-baseband-attacks]]
- [[sdr-and-radio-recon]]
- [[gps-gnss-spoofing]]
- [[wifi-and-802-11-primer]]
- [[bootloader-and-secure-boot-attacks]]
- [[hardware-glitching-deep]]
- [[fault-injection-laser-emfi]]
- [[siem-detection-use-case-catalog]]
- [[detection-engineering-pyramid-of-pain]]

## References

- [DEF CON 21 — Doug DePerry and Tom Ritter, "I Can Hear You Now: Traffic Interception and Remote Mobile Phone Cloning with a Compromised CDMA Femtocell"](https://www.youtube.com/watch?v=hsfHwbg6P_8)
- [The Hacker's Choice — Vodafone Sure Signal / Sagem femtocell research archive](https://web.archive.org/web/2024/http://wiki.thc.org/vodafone)
- [3GPP TS 33.320 — Security of Home Node B (HNB) / Home eNode B (HeNB)](https://www.3gpp.org/dynareport/33320.htm)
- [ENISA — 5G Threat Landscape (RAN and small cell sections)](https://www.enisa.europa.eu/publications/enisa-threat-landscape-for-5g-networks)
- [O-RAN Alliance — WG11 Security Specifications](https://www.o-ran.org/specifications)
- [P1 Security — research notes on small cell and SecGW exposures](https://www.p1sec.com/corp/research/)
