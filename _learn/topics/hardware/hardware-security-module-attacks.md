---
title: HSM (Hardware Security Module) attacks
slug: hardware-security-module-attacks
aliases: [hsm-attacks, secure-element-attacks, pkcs11-attacks]
---

> **TL;DR:** HSMs are tamper-resistant devices that hold private keys and perform crypto operations without exposing keys. Used for: CA root keys, payment-card crypto, code signing, cloud KMS backends, TPM-equivalent in servers. Attack surface: API misuse (PKCS#11 / KMIP / vendor-specific), key-attribute confusion, signing-oracle abuse, firmware bugs, network-management interface vulnerabilities, and side-channels in the device itself. Companion to [[side-channel-power-em]] and [[hardware-glitching-deep]].

## Why HSMs matter

- **Highest-assurance crypto** for an organisation.
- **Single-point-of-trust** for everything that depends on them.
- **Compliance**: FIPS 140-2/3, Common Criteria, PCI HSM.
- **Misuse is more common than direct compromise** — API misuse leaks keys without breaking the HSM.

## HSM types

### General-purpose

- **Thales Luna**, **Utimaco**, **nCipher (Entrust)**, **AWS CloudHSM**, **Azure Dedicated HSM**, **Google Cloud HSM**.
- PKCS#11 / JCE / KMIP interfaces.

### Payment

- **Thales payShield**, **Atalla** (Micro Focus).
- PIN translation, ATM key management, EMV.
- ANSI X9.24 / PCI HSM-specific APIs.

### TPMs

- Server-embedded.
- TPM 2.0 standard.
- Lower-assurance than dedicated HSM but ubiquitous.

### Smart cards / FIDO2 / Yubikey

- Personal-use HSM-equivalents.
- Small attack surface, often hardware-rooted.

## Class 1 — PKCS#11 attribute confusion

The PKCS#11 API has key attributes:
- `CKA_EXTRACTABLE` — can be exported (wrapped).
- `CKA_WRAP` — can wrap other keys.
- `CKA_UNWRAP` — can unwrap incoming keys.
- `CKA_DECRYPT` — can decrypt.
- `CKA_SIGN` — can sign.

Implementations have shipped with bugs:
- Setting `CKA_EXTRACTABLE = false` post-creation allowed via separate API.
- Wrap-then-decrypt chain extracts keys.
- Wrap-decrypt-with-wrap-key allows key recovery.

Many academic papers documented PKCS#11 attribute bypasses across multiple vendors.

## Class 2 — Wrap-decrypt key extraction

Pattern:
1. Use HSM to wrap private key with a known wrapping key.
2. Use HSM to decrypt the wrapped blob.
3. Recover private key.

If wrap+decrypt operations both available on the same key, extraction possible.

Defence: separate wrap-only keys; strict attribute discipline; vendor patches.

## Class 3 — Signing oracle abuse

HSM signs messages; signing without semantic checks creates oracle:
- Sign arbitrary message digest = full signature forgery.
- Sign transactions chosen by attacker = financial theft.
- Sign code-signing requests = malware signing.

Defence: structured signing requests; HSM enforces format checks; audit trail.

## Class 4 — Payment HSM API misuse

PCI HSM defines APIs for PIN block translation. Bugs:
- **Decimalisation table attacks** (1980s/2000s) — recover PIN digit-by-digit via mistreatment of decimalisation tables.
- **PIN-block format confusion** — translate between formats reveals PIN.
- **Key-block authentication weakness**.

Each new payment-HSM generation patches but new variants surface.

## Class 5 — Firmware vulnerabilities

HSM firmware is C/C++ on constrained hardware. Bugs:
- **CVE-2019-19590** — Utimaco firmware buffer overflow.
- **NXP secure-element CVEs**.
- **Thales firmware updates** — various.

Some bugs give remote code execution on the HSM itself; recover keys.

## Class 6 — Management interface

HSMs have management interfaces (network or serial) for configuration, key import, policy:
- Default credentials.
- Weak admin auth.
- Plaintext protocols on internal network.
- Cross-tenant misconfig in cloud HSM.

Compromise of management = key-policy compromise.

## Class 7 — Side-channels in the HSM

The HSM itself is a chip with side-channel surface ([[side-channel-power-em]], [[hardware-glitching-deep]]):
- Power analysis.
- EM analysis.
- Timing.
- Fault injection.

Production HSMs include countermeasures but research has demonstrated key extraction from some.

For an attacker with physical access (rare, but possible for stolen-HSM forensics), keys recoverable.

## Class 8 — Cloud HSM trust model

AWS / Azure / GCP HSMs are FIPS-validated devices in the provider's datacenter. Trust:
- **Provider operators**: are they trusted with key material?
- **Provider's compute** that accesses HSM has IAM grants.
- **Network path** between customer-side caller and HSM.

Cross-account / cross-tenant misuse if IAM misconfigured.

Customer-managed keys vs provider-managed keys are different trust models.

## Class 9 — TPM-specific

- **TPM-FAIL (2019)** — ECDSA side-channel extracted keys.
- **TPM bus sniffing** — research showed bus traffic carries keys; some configurations.
- **fTPM (firmware TPM)** — bugs in some vendor implementations (e.g., AMD fTPM 2024).

## Audit shape

For an HSM deployment:
1. **Inventory keys**: which key, what use, what attributes.
2. **Attribute discipline**: keys with `EXTRACTABLE` flagged.
3. **Wrap policy**: which keys can wrap others.
4. **Operation policy**: signing endpoints, decryption endpoints.
5. **Auth model**: who can call which operation.
6. **Audit log**: every key operation logged.
7. **Firmware version**: current.
8. **Management interface**: hardened.

## Defensive baseline

- **Strict attribute policy** — explicit, audited, change-controlled.
- **Wrap-key separation** — no key both wrappable and decryptable.
- **Signing format validation** — HSM-side, not just application-side.
- **Multi-person authorisation** for high-risk operations (key export, policy change).
- **Firmware current** — vendor security updates.
- **Management interface segregation** from network.
- **HSM logs to SIEM** with anomaly detection.
- **Periodic certified pen test** of deployment.

## Recovery considerations

If HSM compromise suspected:
- Rotate all keys held by the HSM (often catastrophic — root CA rotation is months of work).
- Re-issue certificates downstream.
- Forensic preservation of the HSM (if physical access).
- Vendor advisory check + firmware update.

## Workflow to study

1. Read PKCS#11 standard.
2. Read CHES / Real World Crypto talks on HSM attacks.
3. Read FIPS 140-3 standard.
4. Set up `softhsm` (software HSM); practice PKCS#11 API.
5. Read disclosed HSM CVE writeups.

## Real-world incidents

- **Multiple bank HSM** key-extraction research (academic).
- **Cosmos Bank, Punjab National Bank** — payment-HSM-related fraud cases.
- **Utimaco CVE-2019-19590** — buffer overflow.
- **AMD fTPM (2024)** — firmware TPM vulnerabilities.
- **Cloud HSM IAM misconfigurations** — periodic.

## Related

- [[side-channel-power-em]]
- [[hardware-glitching-deep]]
- [[fault-injection-laser-emfi]]
- [[cryptography-side-channels-survey]]
- [[bootloader-and-secure-boot-attacks]]
- [[android-trusty-tee-attacks]]
- [[ios-keychain-and-secure-enclave-audit]]
- [[post-quantum-crypto-attack-surface]]
- [[pqc-migration-risk]]

## References
- [PKCS#11 standard (OASIS)](https://www.oasis-open.org/standard/pkcs-11/)
- [Riad Wahby / Stanford — HSM research](https://crypto.stanford.edu/)
- [Steel Industries — HSM research overview](https://steelcyber.io/)
- [Real World Crypto talks](https://rwc.iacr.org/)
- [NIST FIPS 140-3](https://csrc.nist.gov/projects/cryptographic-module-validation-program)
- See also: [[side-channel-power-em]], [[hardware-glitching-deep]], [[cryptography-side-channels-survey]], [[android-trusty-tee-attacks]]
