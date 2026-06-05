---
title: iOS baseband (cellular modem) attacks
slug: ios-baseband-attacks
aliases: [ios-modem-attacks, iphone-baseband, qualcomm-iphone-baseband]
---

> **TL;DR:** iPhones use Qualcomm modems (current iPhones) or in-house Apple baseband (planned future). The baseband attack surface is conceptually identical to Android: protocol parsers reachable over-the-air, separate processor, DMA-into-AP. Apple's mitigations are stronger than most Android vendors (modem sandbox, BlastDoor, message-attachment isolation), but rather than eliminating risk, they shift it to user-facing parsers and IPC boundaries. NSO Group's Pegasus and similar tools have targeted iOS via baseband-adjacent surfaces. Companion to [[android-baseband-attacks]] and [[ios-source-review-methodology]].

## Why iOS baseband matters

- iPhones run iOS with strong app sandbox; baseband bypasses much of this.
- Apple's coordinated patching is faster than most Android OEMs — vendor advantage.
- Public researcher access to baseband is even more constrained on iOS than Android.
- iOS targeted heavily by surveillance vendors (NSO, Intellexa, Cytrox).

## Modem in iPhone

- iPhone modem (recent: Qualcomm X-series) is a separate die with shared memory + IPC.
- Apple wraps the modem with their own subsystem (CommCenter) handling IPC, telephony app interactions.
- Apple's in-house modem (planned for Bionic-derived future iPhones) shifts the firmware surface to Apple's responsibility.

## Attack-surface adjacent to baseband

Apple has reduced direct-modem-RCE via mitigations, so research increasingly targets:

### iMessage / BlastDoor surface

Messages received become parser input — image decode, GIF, PDF, message metadata. Apple's BlastDoor sandbox isolates message parsing from the rest of iOS. Bug surface:
- BlastDoor sandbox escape.
- iMessage metadata pre-BlastDoor.
- Attachment formats (PDF, GIF, HEIC, etc.) — see [[image-decoder-exploitation]] (if present, else this note).

Famous: **NSO FORCEDENTRY** (2021) — CVE-2021-30860, ImageIO parsing of a malformed PDF embedded in an iMessage attachment. Zero-click on every iPhone running iOS < 14.8.

### CallKit / FaceTime

Incoming calls trigger parsers. Bugs here are remote-triggered without user interaction (the call ring is the trigger).

### NetworkExtension / VPN profiles

Configuration profiles pushed via various paths. Bugs allow path traversal, profile injection.

### Lockdown Mode

Apple's "Lockdown Mode" (iOS 16+) disables several attack surfaces:
- Most iMessage attachments.
- FaceTime calls from unknown numbers.
- JIT in Safari.
- Wired connections in lock state.
- Configuration profiles.

Reduces but doesn't eliminate exposure. Designed for high-risk users.

### IMEISV / SIM provisioning

eSIM provisioning over IPv4/IPv6 has its own parser surface.

## Specific in-the-wild exploitation

- **FORCEDENTRY** (Sept 2021) — NSO Group; ImageIO parsing CVE-2021-30860.
- **BLASTPASS** (Sept 2023) — NSO Group again; ImageIO + Wallet PassKit chain.
- **TRIANGULATION** (2023) — Russian APT-style sophisticated chain across multiple iOS components (Kaspersky-disclosed).
- **2024 disclosed chains** — multiple zero-day chains via various message parsers and WebKit.

Pattern: parser-of-attacker-data → sandbox escape → privilege elevation → persistence.

## Why iPhone is hard to target end-to-end

Even with a parser RCE:
- BlastDoor sandbox → must escape.
- Limited filesystem access → must elevate.
- TCC / sandbox layered → must escape per resource.
- Pointer authentication (PAC) on arm64e — see [[pac-arm64e-bypass]].
- Kernel mitigations — sealed pages, kPPL, etc.
- Persistent malware needs to evade boot integrity (Secure Boot chain).

A working zero-click chain requires multiple bugs. Surveillance vendors spend significant R&D per chain; chains burn (get patched) every few months.

## Defensive baseline (users)

- **Apply iOS updates immediately**; Apple patches faster than most.
- **Lockdown Mode** for high-risk users (journalists, activists, executives).
- **Don't receive iMessages from unknown senders** when targeted.
- **Apple's Rapid Security Response** patches drop without full point releases for critical bugs.
- **Hardware refresh** — older iPhones lose attack surface mitigations.

## Workflow to study

iPhone baseband / iOS deep research requires:
- Older jailbroken iPhone (iPhone X / 11 with checkm8-vulnerable BootROM — see [[ios-bootrom-checkm8]]).
- Frida / objection / lldb-via-debugserver setup.
- IDA / Ghidra for kernelcache and dyld_shared_cache analysis.
- iOS Security Research Device Program for Apple-supported research (very limited).

Public PoCs from Project Zero, Citizen Lab, Kaspersky GReAT are the open corpus.

## Detection

- **Project Zero**, **Citizen Lab** publish when disclosing.
- **iVerify**, **mvt-mobile** (Mobile Verification Toolkit) for indicator-based scanning of iOS devices.
- **Lockdown Mode notifications** when a threat-actor target is detected.
- **Apple Threat Notifications** to specific users (state-actor targeting).

## Related

- [[android-baseband-attacks]] — parallel.
- [[ios-source-review-methodology]] — source-audit (iOS apps mostly).
- [[ios-bootrom-checkm8]] — BootROM exploitation.
- [[pac-arm64e-bypass]] — pointer-authentication.
- [[browser-exploitation-primer]] — WebKit chain.
- [[firmware-extraction]] — modem firmware.

## References
- [Project Zero — iOS posts](https://googleprojectzero.blogspot.com/)
- [Citizen Lab — Pegasus / NSO writeups](https://citizenlab.ca/)
- [Kaspersky GReAT — TRIANGULATION analysis](https://securelist.com/triangle-operation-mobile-malware/)
- [Apple Security Research Device Program](https://security.apple.com/research-device/)
- [mvt-mobile](https://docs.mvt.re/)
- See also: [[android-baseband-attacks]], [[ios-source-review-methodology]], [[browser-exploitation-primer]], [[pac-arm64e-bypass]]
