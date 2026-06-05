---
title: LoRaWAN attacks
slug: lorawan-attacks
aliases: [lorawan-security, lora-attacks]
---

{% raw %}

> **TL;DR:** LoRaWAN is the most common low-power WAN protocol — sub-GHz, multi-kilometre range, used for utility meters, agriculture sensors, asset tracking, and smart-city infra. Attacks: (1) ABP devices with hardcoded keys, (2) OTAA join replay, (3) jamming to force re-joins, (4) frame counter rollover / replay, (5) network-server bugs in chirpstack/loriot. Companion to [[sdr-and-radio-recon]] and [[zigbee-and-zwave-attacks]].

## Stack quick reference

- **Device classes**: A (default, downlink after uplink), B (scheduled slots), C (always listening, higher power).
- **Activation**: ABP (Activation By Personalisation — pre-loaded keys) or OTAA (Over The Air Activation — keys derived via join procedure).
- **Keys**:
  - AppKey (root, in OTAA).
  - NwkSKey (network session) and AppSKey (application session) — derived or pre-loaded.
- **Frame structure**: PHY → MAC → MIC (4-byte truncated CMAC).
- **Frequencies**: EU868, US915, AS923, AU915, IN865 — region-specific channel plans.

## Hardware

| Tool | Use |
|---|---|
| HackRF / LimeSDR | full RX/TX |
| RAK / Pycom gateway | legitimate gateway you can mod |
| **gr-lora / gr-lorawan** | GNU Radio blocks |
| **LoRaWAN Auditing Framework** | testing helper |
| Single-channel gateway (cheap) | many SOHO setups; insecure-by-design |

## Attack 1 — ABP with hardcoded keys

ABP (Activation By Personalisation) devices ship with keys baked in firmware. Many cheap sensors:
- Use the same AppSKey across all devices in a product line.
- Store keys in clear in firmware images.
- Don't rotate keys at any lifecycle event.

Once you have the firmware (via download, JTAG dump, or vendor download), extract the keys, decrypt any captured traffic, and inject your own frames.

Source-audit angle:
```bash
strings firmware.bin | grep -iE 'appskey|nwkskey|appkey'
```

## Attack 2 — OTAA join procedure

OTAA exchange:
```
Device → JoinRequest(DevEUI, AppEUI, DevNonce)
Server → JoinAccept(AppNonce, NetID, DevAddr, ...) [encrypted with AppKey]
```

After accept, both sides derive NwkSKey + AppSKey from AppKey + nonces.

Attacks:
- **JoinRequest replay** — old DevNonce + AppEUI replayed. Defence: server tracks recent nonces. Devices that don't have monotonic DevNonce → vulnerable.
- **JoinAccept MITM** — if attacker intercepts and replaces, future traffic is decryptable by attacker. Requires both directions; harder in practice.
- **Downgrade to LoRaWAN 1.0** — newer spec (1.0.4 / 1.1) is stronger; some devices fall back.

## Attack 3 — frame counter

Each uplink/downlink carries a 16-bit (sometimes 32-bit) counter. Replay protection assumes counters never decrement.

Bugs:
- Counter rollover not handled — device resets and starts at 0; server accepts old counters again.
- Counter not synchronised between primary and backup network servers.
- "Frame count reset" frame accepted without auth.

Test by sending frames with stale counters.

## Attack 4 — jamming + forced rejoin

Jam the device's uplink slots → device assumes packets are dropped → eventually rejoins. Capture the rejoin to extract a new session key.

## Attack 5 — network server side

The LoRaWAN network server (ChirpStack, LoRiot, AWS IoT for LoRaWAN) accepts uplinks and forwards to apps. Bugs:
- Authentication of uplink integrity-failed messages dropped, but logged → log analysis reveals device identities.
- Replay protection sometimes optional in self-hosted ChirpStack.
- Admin web UI bugs (auth, IDOR, mass-assignment).

These are software bugs, not RF. Audit with usual web-app methodology.

## Bug examples from public research

- Smart-meter networks where ABP keys were predictable from serial numbers.
- Agriculture sensors leaking ABP keys via debug UART.
- Single-channel gateways (cheap consumer) that don't validate MIC → packet injection accepted.
- Asset trackers with frame-counter reset accepted.

## Defence

- **OTAA over ABP** for production.
- **Per-device unique AppKey**, not vendor-default.
- **LoRaWAN 1.1+** with rotating session keys.
- **Network server validates MIC** strictly.
- **Frame counter persistence** through power cycles.
- **Don't ship firmware with embedded keys.**

## Workflow for an engagement

1. Identify devices in scope — DevEUI, AppEUI.
2. Capture join procedures + uplinks over a session window.
3. Test for ABP key reuse across product line (if applicable).
4. Verify frame counter handling.
5. Check network-server software-level bugs.
6. Document with PCAP-like trace + decoded frames.

## OSCP/OSEP relevance

Out of scope. Important for utility / IoT / smart-city audits.

## References
- [LoRaWAN specifications (LoRa Alliance)](https://lora-alliance.org/about-lorawan/)
- [ChirpStack](https://www.chirpstack.io/)
- [gr-lora](https://github.com/rpp0/gr-lora)
- [LoRaWAN Security white papers](https://lora-alliance.org/resource-hub/)
- See also: [[sdr-and-radio-recon]], [[zigbee-and-zwave-attacks]], [[ble-and-bluetooth-low-energy-attacks]]

{% endraw %}
