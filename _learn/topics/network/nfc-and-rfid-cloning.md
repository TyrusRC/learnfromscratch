---
title: NFC and RFID cloning
slug: nfc-and-rfid-cloning
aliases: [nfc-cloning, rfid-cloning, hid-cloning]
---

{% raw %}

> **TL;DR:** RFID (125kHz LF + 13.56MHz HF) and NFC (13.56MHz HF, narrower spec) drive access badges, transit cards, payment cards, hotel keys, and ID. Attacks: (1) read the badge UID — often the only thing being checked, (2) clone the UID to a writable card or emulator, (3) attack the crypto (MIFARE Classic Crypto-1 broken for years; iCLASS legacy keys partly leaked; DESFire EV1 strong if defaults rotated), (4) downgrade or rollback. Companion to [[physical-pentest-tradecraft]].

## Frequency map

| Frequency | Examples |
|---|---|
| 125 kHz (LF) | HID Prox, EM4100, Indala — older buildings, cattle tags |
| 13.56 MHz (HF) | MIFARE Classic/Plus/DESFire, iCLASS, NTAG, ISO14443 |
| 860-960 MHz (UHF) | inventory tags, anti-theft, long-range |
| 2.45 GHz | active RFID, some specialty |

LF / HF dominate building access; UHF is supply-chain.

## Hardware

| Tool | Range | Purpose |
|---|---|---|
| **Proxmark 3 RDV4** | LF + HF | the gold standard; can read, write, crack, emulate |
| **Flipper Zero** | LF + HF | portable, friendly UX; limited compared to Proxmark |
| **ChameleonMini / Tiny** | HF | emulator/sniffer; battery-powered card form factor |
| **iCopy-X** | LF + HF | consumer cloner; fast but limited |
| **HID OMNIKEY / ACR122U** | HF | desktop reader for NFC research |
| **Long-range readers** (HID maxiProx in attacker hands) | LF | read at 1-3 feet — under-clothes scanning |

## Attack 1 — clone a badge

The simplest and most common attack: read UID, write to a "magic" / writable card.

```text
# Proxmark — HID Prox LF
pm3> lf hid read
# captures TAG ID e.g. 2006ec0c01

pm3> lf hid clone -r 2006ec0c01
# writes to T55x7 writable card

# MIFARE Classic HF
pm3> hf mf info
pm3> hf mf autopwn        # tries known keys + nested attack
pm3> hf mf dump
pm3> hf mf cload -f hf-mf-XXXX-dump.bin       # write to "magic" Chinese card
```

Once on a writable card or in a Proxmark/ChameleonMini emulator, you have a working clone for any reader that only checks UID.

## Attack 2 — MIFARE Classic key recovery

MIFARE Classic's Crypto-1 is broken (mfoc, mfcuk). If the issuer didn't change default keys (`FF FF FF FF FF FF`, `D3 F7 D3 F7 D3 F7`, etc.), recovery takes seconds.

```bash
# Proxmark
pm3> hf mf chk *1 ?               # try default keys
pm3> hf mf nested 1 0 A FFFFFFFFFFFF  # recover other sectors from one known key
```

Once all keys are known, dump the card, modify access bits / value blocks, write to a clone.

## Attack 3 — iCLASS legacy

HID iCLASS (pre-SE) used a global master key the community recovered. iCLASS cards in many buildings still use this.

```text
pm3> hf iclass info
pm3> hf iclass dump --ki 0    # use stored legacy key
```

iCLASS SE (newer) uses per-customer keys; not vulnerable to the legacy break but other research has shown weaknesses.

## Attack 4 — relay attacks

For payment cards and badges with HF crypto you can't crack, *relay* the conversation:
- Attacker A holds a reader next to the victim's card (e.g., in a crowded train).
- Attacker B holds an emulator next to the target reader.
- They forward APDU traffic over Bluetooth/Wi-Fi between the two.
- The target reader sees a valid response.

Tools: Proxmark, ChameleonMini, or any pair of devices with NFC + radio. Bounded by the protocol's timing tolerance (some payment systems narrow the window to 5ms; some access readers tolerate 100ms+).

## Attack 5 — Apple/Google Pay

Tokenised payments are device-bound. Cloning the underlying card from an `EMV` chip read is *not* possible (DDA signed responses). Attacks on Apple/Google Pay are at the OAuth / enrolment layer, not RF.

## Attack 6 — long-range reading

A long-range LF reader (HID maxiProx) can read HID Prox cards from 1-3 feet. Attackers conceal the reader in a backpack, capture badge data during proximity.

## NFC-specific

NFC is HF + extra layers (Card Emulation, Reader, Peer-to-Peer). Common targets:
- NTAG tags (NDEF — URL/text/wifi). Often unauthenticated; rewriteable. Used in marketing, phishing landing pages.
- NTAG-DNA / NTAG 424 DNA — authenticated, dynamic URL signing. Newer, stronger.
- Hotel keycards — MIFARE Classic or Ultralight; often weak.
- Transit cards (Octopus, Suica, OV-chipkaart, MIFARE DESFire EV1/EV2) — DESFire is strong with rotated keys.

## Workflow for a building badge engagement

1. Identify reader type — HID Prox? iCLASS? MIFARE? (Visual inspection + Proxmark `hf search` / `lf search`).
2. Capture a target's badge via long-range or hand-shake brush-by.
3. Clone to writable card or emulator.
4. Test against a non-critical door first.
5. Operate.

Engagement letter must permit RF interaction with physical doors — many do not by default.

## Defence

- Use DESFire EV2/EV3 with per-card unique keys and rotated diversification keys.
- Implement reader-side cryptographic challenge ("OSDP Secure Channel").
- Multi-factor — badge + PIN or badge + biometric.
- For high-value: anti-relay timing, distance bounding.
- Audit access logs for impossible-travel patterns ("badge used at door A and door B 200m apart, 5s apart").

## References
- [Proxmark3 wiki](https://github.com/RfidResearchGroup/proxmark3/wiki)
- [Iceman fork — Proxmark fork with extra tooling](https://github.com/RfidResearchGroup/proxmark3)
- [Chameleon — RFID emulator](https://github.com/emsec/ChameleonMini)
- [HID iCLASS research — Meriac, Kasper](https://mq.iotahoe.com/) (research index)
- [Flipper Zero docs](https://docs.flipper.net/)
- See also: [[physical-pentest-tradecraft]], [[ble-and-bluetooth-low-energy-attacks]], [[hardware-implants-and-badusb]]

{% endraw %}
