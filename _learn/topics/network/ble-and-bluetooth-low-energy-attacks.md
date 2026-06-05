---
title: BLE and Bluetooth Low Energy attacks
slug: ble-and-bluetooth-low-energy-attacks
aliases: [ble-attacks, bluetooth-attacks]
---

{% raw %}

> **TL;DR:** Bluetooth Low Energy (BLE) is the radio under Apple AirTags, fitness wearables, smart locks, medical devices, IoT lights, and BMS systems. Attacks cluster around (1) discovery — every device that's not in non-connectable mode advertises, (2) GATT enumeration — characteristics often expose read/write without authentication, (3) pairing weaknesses — Just Works is "no security", legacy LE pairing uses short keys, (4) impersonation, (5) injection via GATT writes. Companion to [[wifi-and-802-11-primer]] and [[zigbee-and-zwave-attacks]].

## Hardware

| Tool | Purpose |
|---|---|
| Nordic nRF52 dev kit | best for protocol-level fuzzing, sniffing, BLE-CTF |
| Ubertooth One | sniffing classic Bluetooth + BLE (older) |
| HackRF / BladeRF + sdr-tools | BLE captures, but PHY-level work |
| ESP32 (cheap) | quick BLE recon and impersonation |
| Adafruit Bluefruit / Flipper Zero | recon, send custom adverts |
| `bluez` + a USB BLE adapter | software-only attacks on Linux |

## Stack quick-reference

```
Application (your app code)
GATT (Generic Attribute Profile — services + characteristics)
ATT (Attribute Protocol — read/write/notify)
SMP (Security Manager Protocol — pairing/bonding)
L2CAP (multiplexing)
LL (Link Layer)
PHY (1M, 2M, Coded — 2.4GHz)
```

GATT structure:
- **Service** — logical group (e.g., "Battery Service").
- **Characteristic** — value + properties (read/write/notify/indicate).
- **Descriptor** — metadata.

UUIDs: 16-bit assigned by Bluetooth SIG (well-known) or 128-bit custom (vendor).

## Phase 1 — survey

```bash
# Linux + BlueZ
sudo bluetoothctl
> scan le on
> devices
> info <MAC>

# nRF tools
nrfutil ble discover
```

For each device:
- MAC address (and whether it's randomised; 6 high bits identify type).
- Local name / advertised flags.
- Service UUIDs in adverts.
- RSSI (proximity).

## Phase 2 — GATT enumeration

```bash
# bluetoothctl
> connect AA:BB:CC:DD:EE:FF
> menu gatt
> list-attributes

# gatttool (legacy)
gatttool -b AA:BB:CC:DD:EE:FF -I
> primary
> characteristics

# nRF Connect (mobile app — best UX)
```

For each characteristic: try Read, Write, Notify. Many devices allow unauthenticated read of "device info" service (firmware version, serial number) and write to "control" service (commands).

## Phase 3 — pairing weaknesses

BLE pairing modes:

| Method | Security |
|---|---|
| **Just Works** | none — no MITM protection; an attacker in range can pair |
| **Passkey Entry** | 6-digit PIN; offline-crackable if you capture the pairing |
| **Numeric Comparison** | 6-digit shown on both; protects against MITM |
| **Out of Band (OOB)** | strongest; uses NFC or QR for the key |

LE Legacy pairing (pre-4.2) uses 16-bit TK; LE Secure Connections (4.2+) uses ECDH. Many devices still default to Legacy + Just Works.

Capture pairing with `btmon` or nRF sniffer; crack the TK offline with crackle.

```bash
sudo btmon -w pairing.snoop
crackle -i pairing.snoop
```

## Phase 4 — replay and command injection

Once you know a characteristic accepts write (e.g., `0x002b` = `unlock_door`):

```bash
gatttool -b AA:BB:CC:DD:EE:FF --char-write-req --handle=0x002b --value=01
```

Many smart locks, fitness apps, smart bulbs have unauthenticated control characteristics — the manufacturer didn't expect anyone to look. AirTag-style devices, on the other hand, have signed adverts and rate-limited probes.

## Phase 5 — passive sniffing (key recovery)

If pairing is observed in real-time:
1. Set nRF sniffer to follow the channel-hopping sequence.
2. Capture all packets between the two endpoints.
3. Extract LL_ENC_REQ / LL_ENC_RSP from the capture.
4. crackle (offline) recovers the LTK for LE Legacy pairings.

For LE Secure Connections (ECDH), passive recovery isn't feasible — the bug must be in the implementation.

## Common bug classes

- **Unauthenticated control characteristic** — write 1 byte to unlock.
- **PIN brute force** — characteristic accepts repeated PIN attempts without lockout.
- **Static GATT secrets** — the firmware compares an attacker-readable value to authorise an action.
- **Replay** — a recorded "unlock" command works again.
- **MAC address as auth** — code trusts MAC; spoofable.
- **Just-Works pairing on a privileged device** — anything in range pairs.
- **Privacy leak** — non-resolvable random address that doesn't actually rotate.

## BLE-CTF resources

- **BLE CTF Infinity** (and the original BLE CTF) — Frida-style puzzles on cheap nRF dev boards.
- **bleah, bettercap's BLE modules** — scriptable attack tooling.
- **micropython on ESP32** — quick custom advertisers and central-role attackers.

## Real-world classes you can reproduce

- Smart lock with replay (many garage-door openers, some Bluetooth padlocks).
- Fitness tracker leaking heart-rate / location via unauthenticated read.
- Industrial sensor exposing config write characteristic.
- Hearing aid pairing using Just Works (medical, increasingly fixed).

## Defence

- LE Secure Connections + Numeric Comparison for any sensitive device.
- Per-device unique pairing key, not factory default.
- Bonding required before sensitive characteristics are usable.
- App-layer crypto on top of GATT (AES-CCM, MAC).
- Rate-limit auth attempts and lock out devices.
- Implement MAC-randomisation correctly (rotating every 15min).

## References
- [Bluetooth SIG specifications](https://www.bluetooth.com/specifications/)
- [crackle](https://github.com/mikeryan/crackle)
- [nRF Connect for Mobile](https://www.nordicsemi.com/Products/Development-tools/nrf-connect-for-mobile)
- [bettercap BLE modules](https://www.bettercap.org/modules/ble/)
- [BLE CTF Infinity](https://github.com/hackgnar/ble_ctf_infinity)
- See also: [[wifi-and-802-11-primer]], [[zigbee-and-zwave-attacks]], [[nfc-and-rfid-cloning]], [[hardware-implants-and-badusb]]

{% endraw %}
