---
title: Android Trusty TEE attacks
slug: android-trusty-tee-attacks
aliases: [trusty-tee-attacks, trustzone-android-attacks, qsee-attacks]
---

> **TL;DR:** Trusty is Google's open-source TEE OS used on Pixel devices; Qualcomm devices use QSEE; Samsung uses Knox / TEEgris. All run in ARM TrustZone — a hardware-isolated "secure world" alongside the normal Android OS. The TEE handles fingerprint matching, KeyMaster operations, payment apps. Bugs here cross "normal world → secure world" or "secure world → kernel" boundaries. Companion to [[android-mali-gpu-exploitation]] and [[ios-keychain-and-secure-enclave-audit]].

## Why TEE matters

- TEEs hold **the strongest cryptographic root** in the device — device-bound keys, biometric templates, DRM.
- A TEE compromise breaks: biometric auth assurance, KeyStore-bound creds, DRM, attestation.
- Bugs are rare but high-impact; surveillance vendors target.
- Vendor diversity (Trusty, QSEE, TEEgris, Knox) means each TEE has its own bug surface.

## ARM TrustZone basics

- TrustZone divides each ARM core into **secure** and **normal** world states.
- World transitions via Secure Monitor Call (`smc`).
- Secure-world has its own MMU, page tables, peripherals.
- Memory regions tagged as secure or normal.

The TEE OS runs in secure world. It provides services to the normal-world Android kernel via SMC handlers.

## TEE OS landscape

- **Trusty** — Google's. Open source on AOSP. Used on Pixel.
- **QSEE (Qualcomm Secure Execution Environment)** — Qualcomm.
- **TEEgris** — Samsung.
- **Kinibi** — Trustonic, used on some non-Samsung Android.
- **OP-TEE** — open-source reference, used in some embedded.

For Android attack research, Pixel/Trusty has the most open documentation.

## Trusted Applications (TAs)

TEE OSes run "trusted applications" — small programs in secure world. Examples:
- **Gatekeeper** — password / PIN verification.
- **Keymaster / KeyMint** — KeyStore-backed cryptographic ops.
- **Fingerprint** — biometric template matching.
- **Widevine** — DRM.
- **Authmint** — newer authentication primitives.
- **StrongBox** — hardware-backed key storage.

Each TA has its own IPC interface and its own bug surface.

## Class 1 — TA input parser bugs

Normal-world Android passes requests to TAs over IPC. TAs parse the input. Buffer overflows, integer overflows, format-string bugs in TA code give attacker code execution in secure world.

These are the most-published class:
- Quarkslab disclosed multiple TA bugs across vendors.
- Various Black Hat / Project Zero publications.

## Class 2 — SMC handler bugs

The TEE OS itself handles SMCs from normal world. Bugs in SMC dispatchers (parsing argument structure, validating world state) give kernel-of-secure-world code execution.

These are rarer but more impactful — compromise of the OS, not just an app.

## Class 3 — Cryptographic implementation bugs

TA cryptographic code is often custom for size / certification reasons. Side-channel issues (timing, cache, power) leak keys without code-execution.

Has affected:
- Samsung TEEgris ECDSA implementation (CVE-2022-22431) — nonce reuse leading to key extraction.
- Various Widevine analysis.

## Class 4 — Replay / state-machine bugs in Gatekeeper

Gatekeeper has rate-limiting on PIN attempts. Bugs:
- State-machine confusion allowing reset of rate-limit counter.
- Replay of "pass" tokens after the user passes once.
- Auth-token forgery.

These are biometric/PIN bypasses with real privacy impact.

## Class 5 — Inter-TA confusion

Multiple TAs share secure-world memory. Bugs:
- TA A reading TA B's memory.
- TA A's IPC reply confused for TA B.
- Privileged TA endpoints reachable from non-privileged TA.

## Class 6 — Side-channel from normal world

Spectre-class attacks against secure-world via shared cache / branch predictor have been demonstrated academically. Practical exploitation against modern Trusty / QSEE is constrained but exists.

## Recent public research

- **Project Zero** has published Pixel Trusty bug chains.
- **Quarkslab** — Samsung TEEgris and others.
- **Github Security Lab** — recurring Trusty / QSEE writeups.
- **Pwn2Own** — TEE category bugs have paid 6-figure bounties.

## Defensive baseline

For users:
- Apply Android security updates.
- Pixel and Samsung flagship devices have better TEE patching cadence.
- Don't sideload TA-equivalent components.

For platform vendors:
- Code-review TA implementations to high standard.
- Fuzz-test SMC handlers.
- Side-channel resistant crypto.
- Memory tagging in TEE (MTE) emerging.

## Workflow to study

1. Pull Trusty source from AOSP.
2. Identify TA list and IPC surface.
3. Audit one TA's input parser.
4. Read public bug-class writeups (Quarkslab, Project Zero).
5. Set up a Pixel with a debug Trusty build (Google's research device program supports this for select researchers).

## Forensic / IR angle

If TEE compromise is suspected:
- Keymaster attestation reports may show unusual patterns.
- Hardware-bound keys behaving unexpectedly.
- Biometric auth bypass without alerts.

Most TEE compromises don't leave normal-world artefacts; forensics is correspondingly hard.

## Related

- [[android-mali-gpu-exploitation]] — parallel privileged surface.
- [[ios-keychain-and-secure-enclave-audit]] — iOS analogue.
- [[bootloader-and-secure-boot-attacks]] — adjacent root-of-trust.
- [[android-keystore-and-crypto-audit]] — Android side of TEE-backed crypto.
- [[browser-exploitation-primer]] — adjacent chain target.

## References
- [Trusty source (AOSP)](https://android.googlesource.com/trusty/)
- [Quarkslab — TEE research](https://blog.quarkslab.com/)
- [Project Zero — TEE posts](https://googleprojectzero.blogspot.com/)
- [Trustonic Kinibi — overview docs](https://www.trustonic.com/)
- See also: [[android-mali-gpu-exploitation]], [[android-keystore-and-crypto-audit]], [[ios-keychain-and-secure-enclave-audit]], [[bootloader-and-secure-boot-attacks]]
