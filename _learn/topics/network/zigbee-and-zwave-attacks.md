---
title: Zigbee and Z-Wave attacks
slug: zigbee-and-zwave-attacks
aliases: [zigbee-attacks, zwave-attacks]
---

{% raw %}

> **TL;DR:** Zigbee (2.4 GHz, IEEE 802.15.4) and Z-Wave (sub-GHz, proprietary stack acquired by Silicon Labs) drive smart locks, alarm sensors, lights, and HVAC. Attacks: (1) pairing-mode capture (Zigbee Trust Center link key is often the well-known `ZigBeeAlliance09` default; Z-Wave S0 is broken), (2) replay, (3) jamming and forced re-pairing, (4) command injection on weakly-authenticated networks. Companion to [[ble-and-bluetooth-low-energy-attacks]] and [[lorawan-attacks]].

## Stack quick reference

### Zigbee
- 2.4 GHz IEEE 802.15.4 PHY/MAC.
- Mesh routing.
- Trust Center (coordinator) manages keys.
- HA (Home Automation), GP (Green Power), Zigbee 3.0 (unified) profiles.

### Z-Wave
- Sub-GHz (908/916/868 MHz; varies by region).
- Star topology + range-extending repeaters.
- S0 security framework (broken — keys derived from temporary network key sent during inclusion).
- S2 security (current) uses ECDH; stronger.

## Hardware

| Tool | Use |
|---|---|
| **Zigbee USB dongle** (Texas Instruments CC2531, CC1352, Sonoff ZBDongle-E) | Zigbee sniff + transmit |
| **ApiMote / RZUSBSTICK** | Zigbee sniffer used by KillerBee |
| **Z-Wave HackRF + scapy-radio** | Z-Wave RX/TX |
| **Z-Stick (Aeotec)** | legitimate Z-Wave controller; useful for fuzzing |
| **HackRF** | both, with right gnu-radio flows |

## Zigbee attacks

### Attack 1 — Trust Center link key

Zigbee HA 1.2 used a public link key: `5A 69 67 42 65 65 41 6C 6C 69 61 6E 63 65 30 39` (`"ZigBeeAlliance09"`).

If you capture a join (`Transport Key` APS command), and the device used the default link key, decrypt with the well-known key.

```bash
# zbdsniff (KillerBee toolkit)
zbdsniff capture.pcap
# extracts network keys encrypted with known link keys
```

Once the network key is recovered, decrypt all subsequent traffic and inject your own.

### Attack 2 — install-code (Zigbee 3.0)

Zigbee 3.0 requires per-device install codes (printed on labels) used to derive a unique link key. Stronger — but install-code mode is opt-in; many devices still default to ZigBeeAlliance09 for compatibility.

Audit: does the gateway log when devices join with the default key vs install codes?

### Attack 3 — Green Power

Green Power devices (battery-less switches) use even weaker security — pre-shared or derived keys. Some commercial Zigbee lights ship with insecure GP support.

### Attack 4 — replay + jamming

Without rolling counter checks, "lights on" frames are replay-able. Combined with jamming the legitimate transmitter you can prevent unsubscribes.

KillerBee:
```bash
zbreplay -f channel -p capture.pcap
zbgoodfind -f capture.pcap        # search for keys
zbid -i /dev/ttyUSB0              # identify sniffer
```

### Attack 5 — touchlink commissioning (legacy Zigbee LightLink)

Zigbee LightLink had a "touchlink" mode where any device in range could reset and re-claim other devices. Many Hue / smart-light products were vulnerable circa 2016 (Z-Shave).

## Z-Wave attacks

### Attack 1 — S0 inclusion key capture

S0 security uses a temporary key (`00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00`) during initial inclusion. An attacker present at inclusion captures the network key.

A "downgrade" attack forces a device to re-include in S0 mode after the user paired it with S2.

### Attack 2 — frame injection

If the network key is known (S0 captured, or S2 not in use), any command can be injected: "unlock door", "disable motion sensor", "lights off".

### Attack 3 — exclusion / inclusion games

Forcing a device out of the network and back in (`exclude`) generates a window for re-inclusion in S0 (downgrade).

### Attack 4 — Black Hat / Pen Test Partners research

Multiple smart locks shipped with S0-only modes well into the 2020s. Pen Test Partners and others showed remote unlocking with $30 hardware.

## Workflow for a Zigbee / Z-Wave engagement

1. Identify the protocol and channel in use.
2. Sniff long enough to observe a re-join or scheduled key rotation.
3. Decrypt with known default keys or recover keys from inclusion frames.
4. Replay or inject commands.
5. Document the impact.

## Defence

- **Use install codes (Zigbee 3.0) or S2 (Z-Wave)** universally, no fallback to S0 / ZigBeeAlliance09.
- **Rotate network keys** periodically and on device exclusion.
- **Don't re-include in S0 to a previously S2 device.**
- **Application-layer crypto** on top of Zigbee/Z-Wave for sensitive controls (e.g., AES-CCM on payload).
- **Monitor for high rates of inclusion / exclusion events**.

## OSCP/OSEP relevance

Low — exam scope doesn't include 802.15.4. Real-world engagements at IoT-heavy customers (smart-building, healthcare-with-sensors, factory) include these protocols.

## References
- [KillerBee](https://github.com/riverloopsec/killerbee)
- [Zigbee Alliance (CSA) specifications](https://csa-iot.org/all-solutions/zigbee/)
- [Z-Wave Alliance specifications](https://z-wavealliance.org/)
- [Pen Test Partners — Z-Wave research](https://www.pentestpartners.com/)
- [Sergey Glushchenko — Z-Wave Sniffer & cracking](https://github.com/) (search)
- See also: [[ble-and-bluetooth-low-energy-attacks]], [[lorawan-attacks]], [[sdr-and-radio-recon]]

{% endraw %}
