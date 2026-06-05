---
title: WiFi and 802.11 primer
slug: wifi-and-802-11-primer
aliases: [wifi-primer, 802-11-primer]
---

{% raw %}

> **TL;DR:** 802.11 is the radio + frame format under WiFi; understand the frame types (management, control, data), the four-way handshake, channel hopping, and the difference between WPA2-PSK / WPA2-Enterprise / WPA3 before touching the attack toolkits. This is the floor for [[wpa-and-wpa2-cracking]] and [[evil-twin-and-karma-attacks]].

## The radio + frames

802.11 transmits frames in three classes:

| Class | Examples | Why you care |
|---|---|---|
| Management | beacon, probe-request/response, auth, association, deauth | reveal SSIDs and clients; deauth = jamming primitive |
| Control | RTS/CTS, ACK | rarely useful for attack |
| Data | actual user payload | encrypted under WPA2/3 |

Greppable in Wireshark by `wlan.fc.type` (0=mgmt, 1=ctrl, 2=data) and `wlan.fc.type_subtype`.

## What hardware you need

- A USB WiFi adapter with monitor mode + frame injection.
- The shortlist: Alfa AWUS036ACH (rtl8812au), Alfa AWUS036NHA (Atheros AR9271), Panda PAU09. Drivers are the make-or-break — Atheros AR9271 "just works" on Kali; others may need an out-of-tree driver.

```bash
iw dev
iw list | grep -A8 'Supported interface modes'   # confirm 'monitor'
```

## Monitor mode and channel hopping

```bash
sudo airmon-ng check kill            # kill NetworkManager + wpa_supplicant
sudo airmon-ng start wlan0           # creates wlan0mon
iw dev wlan0mon set channel 6        # static channel
sudo airodump-ng wlan0mon            # hops channels automatically
```

`airodump-ng` is the survey tool. Output shows BSSID (AP MAC), SSID, channel, encryption, and connected clients (STA).

## The four-way handshake (WPA2-PSK)

```
Client                            AP
  | ←——————   Beacon (channel, SSID, capabilities)
  | ——————→  Probe / Auth / Assoc
  |
  | ←——————   ANonce
  | ——————→  SNonce + MIC
  | ←——————   GTK + MIC
  | ——————→  Ack
  |
  | ←—— data ——→ (encrypted under PTK)
```

Pairwise Transient Key (PTK) is derived from PSK + SSID + ANonce + SNonce + MACs. If you capture the four EAPOL frames, you can re-derive PTK *if* you know the PSK — that's the offline crack.

```bash
sudo airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w cap wlan0mon
# wait for a handshake; deauth a client to force one:
sudo aireplay-ng --deauth 5 -a AA:BB:CC:DD:EE:FF -c <client-mac> wlan0mon
```

See [[wpa-and-wpa2-cracking]] for the cracking step.

## PMKID — handshake-free capture

WPA2 APs advertise a PMKID in their first message; you can compute the same PMKID from PSK + SSID + APmac and crack offline *without* a client connecting.

```bash
sudo hcxdumptool -i wlan0mon -o cap.pcapng --enable_status=1
# extract:
hcxpcapngtool -o hash.22000 cap.pcapng
hashcat -m 22000 hash.22000 wordlist.txt
```

PMKID works only if the AP includes it in its first-msg (some vendors don't). Effective against many SOHO routers.

## WPA2-Enterprise (802.1X / EAP)

In enterprises the PSK is replaced by per-user credentials via 802.1X. The handshake involves a RADIUS server.

EAP methods you'll meet:
- **EAP-PEAP / EAP-TTLS** — outer TLS tunnel; inner MSCHAPv2 (crackable offline if captured).
- **EAP-TLS** — mutual cert auth; no usable creds in the handshake.
- **EAP-MD5 / EAP-LEAP** — legacy, broken.

Attack: stand up a rogue RADIUS server (`hostapd-wpe`), advertise the corporate SSID, capture MSCHAPv2 challenges, crack offline with hashcat (`-m 5500`).

## WPA3

WPA3-Personal replaces PSK-handshake with SAE (Simultaneous Authentication of Equals) — Dragonfly key exchange — designed to be offline-crack-resistant. Caveats:
- WPA3 transition mode still accepts WPA2 clients → downgrade is real.
- Dragonblood attacks (2019, partly mitigated) used timing/cache side channels against weak SAE implementations.

## Wireless tools — orientation

| Tool | Purpose |
|---|---|
| `airmon-ng` | enable monitor mode |
| `airodump-ng` | survey nearby networks and clients |
| `aireplay-ng` | inject (deauth, fake auth, replay) |
| `aircrack-ng` | offline crack WPA-PSK from capture |
| `hcxdumptool` / `hcxpcapngtool` | PMKID + EAPOL capture, convert for hashcat |
| `hashcat -m 22000 / 5500` | GPU offline cracker |
| `kismet` | passive scanner with web UI |
| `wifite` | automation wrapper |
| `hostapd-wpe` | rogue 802.1X / RADIUS for credential capture |
| `bettercap` | active layer-2 toolkit (deauth, ARP-spoof, evil-portal) |

## Regulatory note

Channel 1-11 (2.4GHz) is universal; 12/13/14 vary by region. 5GHz channels depend on radar-detection rules. If your adapter shows "no signal" on a channel a phone sees, you may be in a region-mismatch.

```bash
iw reg get
sudo iw reg set US     # or your region
```

## Source-of-truth references vs the toolkit

The IEEE 802.11 spec is enormous; the practitioner reads it via:
- The aircrack-ng wiki — protocol behaviour as observed by the tool authors.
- Hashcat's WPA mode pages.
- Vendor knowledge bases for region-specific channels.

## Companion notes
- [[wpa-and-wpa2-cracking]] — the offline crack itself.
- [[evil-twin-and-karma-attacks]] — active-engagement attacks.
- [[oscp-roadmap]] — wireless modules in PEN-200.

## References
- [Aircrack-ng wiki](https://www.aircrack-ng.org/)
- [Hashcat — Cracking WPA2](https://hashcat.net/wiki/doku.php?id=cracking_wpawpa2)
- [Dragonblood — Vanhoef, Ronen (2019)](https://wpa3.mathyvanhoef.com/)
- [IEEE — 802.11 standards](https://standards.ieee.org/standard/802_11-2020.html)
- See also: [[wpa-and-wpa2-cracking]], [[evil-twin-and-karma-attacks]], [[oscp-roadmap]]

{% endraw %}
