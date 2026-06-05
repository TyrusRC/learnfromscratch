---
title: SDR and radio recon
slug: sdr-and-radio-recon
aliases: [sdr-primer, radio-recon]
---

{% raw %}

> **TL;DR:** Software-Defined Radio receives any radio signal in its tuning range and demodulates it in software. For security work, use it to capture rolling-code key fobs, drone telemetry, ADS-B, GSM/LTE legacy traffic, ISM-band (433MHz, 868MHz, 915MHz) devices, and pager networks. The big wins come from cheap devices with hardcoded crypto. Companion to [[ble-and-bluetooth-low-energy-attacks]] and [[zigbee-and-zwave-attacks]].

## Hardware

| Tool | Range | Notes |
|---|---|---|
| RTL-SDR (RTL2832U) | 24 MHz – 1.7 GHz | $25; receive-only; the default starter |
| HackRF One | 1 MHz – 6 GHz | $300; TX+RX; half-duplex |
| BladeRF 2.0 | 47 MHz – 6 GHz | $500-1000; full-duplex; better dynamic range |
| LimeSDR | 100 kHz – 3.8 GHz | $300-600; full-duplex |
| USRP B200/B210 | 70 MHz – 6 GHz | $1000+; lab-grade, GNU Radio reference |

For most security work: RTL-SDR for receive, HackRF for transmit.

## Software

- **GQRX** — quick visual + audio demodulation.
- **GNU Radio Companion** — drag-drop signal flow graphs.
- **Universal Radio Hacker (URH)** — protocol reverse engineering with sliders.
- **inspectrum** — frequency-domain analyser for captures.
- **rtl_433** — auto-decodes 433MHz ISM (weather stations, doorbells, sensors).
- **gr-gsm** — legacy 2G/3G; mostly historical now.
- **multimon-ng** — POCSAG/FLEX pagers, ACARS, etc.

## The recon loop

1. Tune to the band.
2. Look at the waterfall — strong bursts at a frequency = candidate signal.
3. Capture an IQ recording.
4. In URH or inspectrum, identify modulation (OOK / FSK / GFSK / GMSK / QAM).
5. Decode the bits.
6. Identify the protocol — preamble, sync word, length field, payload, CRC.
7. Build a replay or attack.

## Common targets and attack patterns

### Rolling-code key fobs (cars, garage doors)

Vintage fobs (pre-2000) sent the same code every press → replay.
Modern (KeeLoq, Hi-Tag, KeeLoq AES) use a counter — but the *Rolljam* attack captures one press, jams the receiver simultaneously, lets the user press again (frustrated), captures that too, replays code #1 to unlock, keeps code #2 in reserve.

```bash
# Capture + replay
hackrf_transfer -r capture.iq -f 433920000 -s 2000000
hackrf_transfer -t capture.iq -f 433920000 -s 2000000
```

### Smart-home sensors (433MHz / 868MHz / 915MHz)

Wireless doorbells, motion sensors, door/window contacts — most send unencrypted ID + state. `rtl_433` decodes hundreds of these out of the box.

```bash
rtl_433 -f 433920000
# {"protocol":40,"id":"123","state":"open","model":"Acme-Door"}
```

Attacker replays "closed" while opening the door, or spoofs alarms.

### Drone telemetry / control

DJI uses OcuSync; older drones used 2.4GHz Wi-Fi-ish protocols. Telemetry often leaks position; control can be spoofed against unprotected models.

### ADS-B (aircraft transponders)

1090 MHz, broadcast-only by spec. Receive with RTL-SDR + `dump1090`. Used legitimately for hobbyist tracking; not an attack vector unless you transmit (which is illegal in most jurisdictions).

### POCSAG pagers

Pager traffic is still used by hospitals and emergency services. POCSAG is unencrypted. multimon-ng decodes.

```bash
rtl_fm -f 138.85M -s 22050 - | multimon-ng -t raw -a POCSAG1200 -
```

Often reveals patient data — privacy concern for healthcare.

### Industrial / IoT sensors

UHF / ISM-band sensors (915MHz in NA, 868MHz in EU) — meter readers, smart parking, etc. Many use unencrypted LoRa, Sigfox, or proprietary modulation. See [[lorawan-attacks]].

## Identifying modulation (the hard part for beginners)

- **OOK (On-Off Keying)** — looks like rectangular pulses; binary on/off.
- **FSK (Frequency Shift Keying)** — two distinct frequencies for 0/1.
- **GFSK** — FSK with Gaussian filter; smoother.
- **QAM** — amplitude + phase changes; harder to recover.

URH and `inspectrum` show waveforms; experience builds fast. Start with rtl_433-supported devices (known protocols) and reverse-engineer the unknowns.

## Legal considerations

- Receive-only: usually legal across most jurisdictions; some bands (cellular) are explicitly off-limits in some countries.
- Transmit: requires a license except in ISM bands and at very low power. Transmitting on cellular / GPS / aircraft bands is a federal crime in most countries.
- Engagement letter must explicitly include RF in scope before any TX work.

## Defence

- AES + counter on any RF protocol carrying actionable signals.
- For rolling code: short window of acceptance + jam detection.
- For sensors: don't leak useful information unencrypted.
- For health-system pagers: encrypt at gateway, or migrate to encrypted alerting.

## Practical OSEP / OSCP relevance

Low — OffSec exams don't include RF. But for real-world engagements with physical scope (warehouse, lab, factory, hospital), RF surface is often unmonitored and high-impact.

## References
- [GNU Radio](https://wiki.gnuradio.org/)
- [rtl_433](https://github.com/merbanan/rtl_433)
- [Universal Radio Hacker](https://github.com/jopohl/urh)
- [Samy Kamkar — Rolljam](https://samy.pl/keysweeper/)
- [Michael Ossmann — SDR talks (Great Scott Gadgets)](https://greatscottgadgets.com/)
- See also: [[ble-and-bluetooth-low-energy-attacks]], [[zigbee-and-zwave-attacks]], [[lorawan-attacks]], [[nfc-and-rfid-cloning]]

{% endraw %}
