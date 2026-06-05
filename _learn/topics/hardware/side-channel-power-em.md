---
title: Power and EM side-channel analysis
slug: side-channel-power-em
aliases: [power-analysis, dpa, em-analysis, side-channel-cryptanalysis]
---

> **TL;DR:** Cryptographic operations leak through physical channels — power consumption (DPA), electromagnetic emanation (EM analysis), acoustic noise, and even photonic emissions. Capture traces, statistically correlate with hypotheses, recover secret keys. Practical against embedded AES, RSA, ECDSA implementations without constant-time / blinded code. Defeated by constant-time crypto, hiding (noise), masking (split secrets), or anti-tamper hardware. Companion to [[hardware-glitching-deep]] and [[cryptography-side-channels-survey]].

## Why this class matters

- **Bypasses crypto strength** — AES-128 with side-channel leak recovered in hours.
- **Affects embedded everywhere** — smart cards, ATM, automotive, IoT.
- **Detectable from a distance** in some cases — EM remotely captured (TEMPEST).
- **Even constant-time can be insufficient** — masking, micro-architecture all matter.
- **Cloud-grade**: DRAM / cache side-channels related; covered in [[spectre-meltdown-deep]] and [[cryptography-side-channels-survey]].

## Background — what leaks

Every transistor switching consumes a tiny amount of power. Aggregated:
- AES round operations consume measurably different amounts depending on key bits.
- RSA modular exponentiation timing reveals key bits if branches differ.
- ECDSA double-and-add vs Montgomery ladder differ.

EM emanation from on-chip wires carries similar information.

## SPA — Simple Power Analysis

Capture one trace; identify operations by eye. Useful when operations differ visibly:
- RSA square vs square-multiply.
- ECDSA double vs add.

Often reveals secret bits if not blinded.

## DPA — Differential Power Analysis

Statistical attack:
1. Capture many traces with varying input.
2. For each candidate sub-key value, predict intermediate (e.g., AES SubBytes output).
3. Correlate prediction with trace at suspected time.
4. Correct sub-key has strongest correlation.

DPA recovers AES key with thousands of traces on typical embedded chips.

## CPA — Correlation Power Analysis

Variant using Pearson correlation. Standard for academic / practical work.

## Template attacks

Profile target with known-key traces; build statistical models. Apply to unknown-key target. More efficient than DPA for some attacks.

## ML-aided SCA

Neural networks trained on traces. Modern works show ML approaches reducing required trace count significantly.

## EM side-channel

Same principles, capture EM rather than power. Advantages:
- Non-contact.
- Can be remote.
- Higher bandwidth.

ChipWhisperer + EM probe + low-noise amplifier suffices for basic attacks.

## Acoustic / photonic / thermal

Less common but demonstrated:
- **Acoustic** — power supplies emit audible whine correlating with computation. Demonstrated for RSA over Skype call.
- **Photonic** — chip-photo emissions decoded.
- **Thermal** — chip temperature side-channel.

## Targets

### Cryptographic accelerators

Smart cards, TPM, secure enclaves, HSM (see [[hardware-security-module-attacks]]).

### Embedded crypto

AES on STM32, nRF52, ESP32 routinely SCA-able if not protected.

### TLS / SSH on embedded

Server-side key on a low-end embedded device may be vulnerable to remote timing or local power.

### Cloud-VM crypto

Side-channels between co-located VMs (cache, memory bus) — adjacent to [[spectre-meltdown-deep]] family.

## Defences

### Constant-time

No data-dependent branches or memory accesses. AES with bitsliced implementation, ECDSA with Montgomery ladder.

### Masking

Split secret into shares; operate on shares separately. Attacker must correlate multiple variables, requiring more traces (exponentially harder).

### Hiding

Add noise: random delays, dummy operations, clock jitter. Raises required trace count.

### Hardware countermeasures

- Dual-rail logic (each bit by two signals; balanced consumption).
- Charge balancing.
- Shielded packaging.
- Anti-probe meshes.

### Algorithm choice

- Modern AES implementations are constant-time.
- Use EdDSA (constant-time) over ECDSA if possible.
- Curve25519 / Curve448 constant-time by design.

## Workflow to learn

1. ChipWhisperer Lite + AES tutorial — captures + DPA.
2. Recover an AES key from an unprotected target.
3. Implement masking; observe required trace count increases.
4. Read CHES (Cryptographic Hardware and Embedded Systems) papers.
5. Try EM probe with custom target.

3-6 month investment to be productive.

## Tools

- **ChipWhisperer** + Python (`chipwhisperer.analyzer`).
- **Riscure Inspector** — commercial.
- **`pysca`**, **`lascar`** — open analysis frameworks.
- **`tinybcurve`** — for ECDSA.
- **SDR + spectrum analyser** for EM at distance.

## Real-world impact

- **Pay TV smart card SCA** broke several DRM schemes historically.
- **Banking card SCA** has driven multi-generation hardware updates.
- **TPM SCA** — academic; production hardware mostly resistant.
- **Crypto library SCA** — periodic CVEs (e.g., on OpenSSL ECDSA — CVE-2018-0735).
- **Cloud-isolation SCA** — academic / theoretical concerns more than practical exploits.

## Workflow to study

Theoretical:
- "Power Analysis Attacks: Revealing the Secrets of Smart Cards" (Mangard et al.) — book.
- "Cryptographic Engineering" (Koç) — comprehensive.

Practical:
- ChipWhisperer hands-on.
- CHES proceedings.

## Related

- [[hardware-glitching-deep]] — adjacent.
- [[fault-injection-laser-emfi]] — adjacent.
- [[spectre-meltdown-deep]] — adjacent.
- [[cryptography-side-channels-survey]] — adjacent.
- [[hardware-security-module-attacks]] — adjacent target.
- [[bootloader-and-secure-boot-attacks]] — adjacent.

## References
- [ChipWhisperer docs](https://chipwhisperer.readthedocs.io/)
- [Riscure publications](https://www.riscure.com/news-events/)
- [CHES proceedings](https://ches.iacr.org/)
- [Marc Witteman talks (Riscure)](https://www.youtube.com/c/Riscure)
- See also: [[hardware-glitching-deep]], [[fault-injection-laser-emfi]], [[spectre-meltdown-deep]], [[cryptography-side-channels-survey]]
