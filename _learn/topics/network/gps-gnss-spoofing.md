---
title: GPS / GNSS spoofing and jamming
slug: gps-gnss-spoofing
aliases: [gps-spoofing, gnss-spoofing, gps-jamming]
---

> **TL;DR:** GPS / GLONASS / Galileo / BeiDou (collectively GNSS) civilian signals are unauthenticated broadcasts. With SDR + commodity power, attackers can spoof — convince a receiver it's at a chosen location or shifted time — or jam, denying service. Demonstrated against drones, ships, cars, aircraft, financial-timing systems. Galileo's Open Service Navigation Message Authentication (OSNMA) is the first widely-deploying defence. Companion to [[cubesat-attacks]] and [[ground-station-attacks]].

## Why this matters

- **Almost everything modern uses GNSS** for position or time — phones, vehicles, ships, drones, aircraft, power grids, finance.
- **Civilian signals are unauthenticated** by design (1970s-era spec). Galileo OSNMA changes this for that constellation.
- **Real-world spoofing** documented in conflict zones, near borders, in commercial-fishing fraud, drone-jamming hotspots.
- **Financial-timing** for high-frequency trading depends on GPS time; spoofing GPS time disrupts.
- **Power-grid sync** uses PMUs (phasor measurement units) tied to GPS time.

## GNSS recap

Constellations:
- **GPS (US)** — 31 active satellites.
- **GLONASS (Russia)** — 24+ satellites.
- **Galileo (EU)** — 28+ satellites; supports OSNMA on E1-B signal.
- **BeiDou (China)** — 35+ satellites.
- Plus regional: QZSS (Japan), NavIC (India).

Receivers compute position from time-of-arrival differences across multiple satellites. Time + 3D position requires 4 satellites minimum.

## Class 1 — Spoofing — false position

Attacker transmits signals impersonating multiple satellites. Receiver computes position based on attacker signals.

For sophisticated spoofing:
- Match relative timing of all satellites consistently with target's true position initially.
- Gradually drift the apparent position to attacker-chosen location.
- Receiver doesn't notice the smooth drift.

For brute spoofing:
- Stronger transmit signal overpowers real satellites.
- Receiver locks to spoof; jumps to attacker location.

Hardware: HackRF / BladeRF / USRP + GPS-SDR-SIM software. <$1000.

## Class 2 — Spoofing — false time

Time-only spoof shifts the receiver's clock. Disrupts:
- Time-sensitive applications.
- HFT systems (microsecond-level matters).
- Synchrophasor measurements (power grid).
- Encrypted protocols with time-bound certificates.

## Class 3 — Jamming

Transmit noise on GNSS frequency. Receivers can't decode signals; lose lock. Recovery requires signal restoration.

Often illegal but trivial to do. Truck drivers with "GPS jammers" in cabs unintentionally interfere with nearby airports.

## Class 4 — Selective spoofing of specific constellations

Modern receivers use multiple constellations for resilience. Selective:
- Spoof GPS, let GLONASS through — confuse multi-constellation fusion.
- Spoof L1, let L5 through.

Modern multi-band receivers are harder to spoof comprehensively.

## Class 5 — Replay

Capture legitimate GNSS signal at location A; replay at location B (with appropriate delay). Receiver thinks it's at A.

Used for vehicle / cargo tracking fraud, fishery violation evasion.

## Real-world incidents

- **Iran 2011** — claimed GPS spoofing of US RQ-170 Stealth drone leading to capture.
- **Black Sea 2017** — reported GPS spoofing of ~20 ships near Russian coast, displayed positions far inland.
- **Israel 2023+** — extensive jamming + spoofing reported in regional airspace.
- **Russia / Ukraine 2022+** — widespread GPS denial and spoofing.
- **Newark Liberty airport 2009-2013** — repeated GPS interference from a single GPS-jamming truck on adjacent highway.

## OSNMA — Galileo authentication

Galileo's Open Service Navigation Message Authentication (OSNMA) added to E1-B signal:
- TESLA-based authentication (time-delayed key disclosure).
- Each satellite broadcasts authentication info that receivers can verify after the fact.
- Detects spoof of Galileo signal.

Rolled out 2023+. Receivers need firmware update to use.

Doesn't help against jamming.

## Defensive baseline

### Receivers

- **Multi-constellation** + **multi-band** receivers.
- **Use OSNMA** where Galileo supported.
- **Plausibility checks** — sudden position jumps, sudden time shifts, signal-to-noise anomalies.
- **Inertial-aided positioning** — IMU plus GPS, with IMU detecting GPS jumps.
- **Antenna-array (CRPA — Controlled Reception Pattern Antenna)** — directional null toward spoofers; military / aviation grade.
- **Anti-spoofing modules** — commercial (Septentrio, Hexagon NovAtel).

### Mission designers

- **Don't trust GPS time** for crypto / business-critical without secondary check.
- **Diversified time sources** — NTP from multiple stratums, PTP, atomic clock + GPS hybrid.
- **GPS-denial procedure** — what's the fallback when GPS unavailable.

### Infrastructure operators

- **GPS-disciplined oscillators** — local oscillator continues providing time after GPS loss.
- **eLORAN** — secondary terrestrial alternative.
- **Quantum clocks** — emerging.

## Workflow to study (lab only)

Spoofing requires transmitter licence in most jurisdictions. **Don't transmit** without:
- Faraday cage / RF-shielded room.
- Licensed test setup.
- Explicit authorisation.

Receiving GNSS is legal:
- Use a GNSS receiver (u-blox + Raspberry Pi).
- Capture signals.
- Read SDR-based receiver code (RTKLIB).

Simulated spoofing in lab via cable connection (not over the air):
- HackRF → cable → u-blox.
- Run GPS-SDR-SIM.
- Observe u-blox jumping to spoof location.

## Detection

- **CRPA antennas** for high-value targets.
- **Receiver autonomous integrity monitoring (RAIM)** — built into aviation receivers.
- **GNSS interference detection services** (HawkEye 360, Aireon).
- **Sky-Coverage map** comparison.

## Regulatory and operational

- Jamming + spoofing GPS is felony in US, similar in EU.
- DoD GPS Modernisation includes M-Code for military (signed).
- FAA / EASA increasingly track GPS interference for aviation safety.

## Workflow to study

1. Read RTKLIB documentation.
2. Read OSNMA specification (ESA).
3. Build a GNSS receiver from a u-blox + Pi.
4. Simulate spoofing via cable in a controlled lab.
5. Read aviation / maritime incident reports for real-world context.

## Related

- [[cubesat-attacks]]
- [[ground-station-attacks]]
- [[satellite-modem-attacks]]
- [[sdr-and-radio-recon]]
- [[wifi-and-802-11-primer]] — adjacent radio class
- [[can-bus-attacks]] — adjacent vehicle target
- [[obd2-uds-attacks]] — adjacent

## References
- [GPS.gov](https://www.gps.gov/)
- [ESA OSNMA documentation](https://www.gsc-europa.eu/galileo/services/galileo-open-service-navigation-message-authentication-osnma)
- [HawkEye 360 — interference monitoring](https://www.he360.com/)
- [Todd Humphreys lab — UT Austin](https://radionavlab.ae.utexas.edu/)
- [`gps-sdr-sim`](https://github.com/osqzss/gps-sdr-sim)
- See also: [[cubesat-attacks]], [[ground-station-attacks]], [[satellite-modem-attacks]], [[sdr-and-radio-recon]]
