---
title: Passkey BLE-range mobile phishing
slug: passkey-mobile-ble-phish
---

> **TL;DR:** Within Bluetooth range an attacker runs a hybrid authenticator that advertises itself to a victim's browser, completing a passkey sign-in to an attacker-controlled session (CVE-2024-9956 in Chromium's handling).

## What it is
WebAuthn's hybrid transport ("cloud-assisted BLE", CABLE/caBLEv2) lets a desktop browser pair with a mobile phone over Bluetooth to use the phone's passkey. The protocol pairs via a QR-code-style state exchange. CVE-2024-9956 in Chromium let a malicious site initiate the hybrid handshake without the QR step in the right conditions, so a nearby attacker could trigger the victim's phone to authenticate to an attacker-controlled relying party using a legitimate passkey for that site.

## Preconditions / where it applies
- Victim with Bluetooth and a passkey for the target site on a mobile device (Chrome / Safari / Firefox on iOS/Android).
- Attacker within BLE range (~10 m typical, much further with directional gear).
- Vulnerable Chromium build (fixed in Chrome 129 / equivalent), or any client that accepted hybrid pairing without user-gesture confirmation.

## Technique
1. **Stand up a malicious RP.** Host an attacker site that initiates a WebAuthn `get()` request mirroring the legitimate site's RP ID via a near-look-alike domain or a downgrade. The novel piece is to fire a hybrid handshake without rendering a QR.
2. **Drive the hybrid transport.** Use a custom CTAP2 / caBLEv2 implementation. Public research released a PoC that crafts the BLE advertisement and pairing messages to look like the desktop side of a legitimate hybrid sign-in. The victim phone, on receiving the advertisement, prompts the user to confirm a sign-in to the site whose RP ID the attacker presented.
3. **Same-RP confusion.** If the attacker can also match the RP ID (look-alike domain, IDN homoglyph, or a true open-redirect / [[subdomain-takeover]] on the target apex), the assertion returned is accepted by the real site's relying party.
4. **Capture the assertion.** Attacker receives `authenticatorData` + `signature` over the BLE channel, relays to the real RP, and pockets a logged-in session — see [[webauthn-api-hijacking-downgrade]] for the broader downgrade family.

## Detection and defence
- Browser patches: require a fresh user gesture and on-screen pairing UI for every hybrid handshake; reject silent BLE-initiated CTAP from cold start.
- Authenticator UX: phone prompts that name the RP ID prominently and require an explicit confirm + biometric.
- RP-side: enforce strict origin checks, `authenticatorAttachment: platform` where the deployment doesn't actually need cross-device, and monitor signature counters for anomalies.
- Awareness: users should disable Bluetooth in untrusted environments; enterprise can suppress hybrid transport via policy on managed devices.
- Detection: spikes in WebAuthn sign-ins from new locations followed by passkey use seconds later from a different IP/UA.

## References
- [mastersplinter — Passkey phishing over BLE (CVE-2024-9956)](https://mastersplinter.work/research/passkey/) — original research.
- [Chromium bug 369337918](https://issues.chromium.org/issues/369337918) — vendor tracker for the fix.
- [W3C — Web Authentication Level 3](https://www.w3.org/TR/webauthn-3/) — protocol reference incl. hybrid transport.
