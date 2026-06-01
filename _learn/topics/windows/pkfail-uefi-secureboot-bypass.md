---
title: PKfail — UEFI Secure Boot bypass
slug: pkfail-uefi-secureboot-bypass
---

> **TL;DR:** Hundreds of OEM firmware images ship with non-production AMI test Platform Keys (PKs) whose private halves are public — anyone holding them can sign their own KEK/db updates and load arbitrary bootloaders, breaking Secure Boot's chain of trust on ~900 device models.

## What it is
PKfail (Binarly, 2024, CVE-2024-8105) is the disclosure that multiple firmware vendors built shipping production firmware on top of AMI/Insyde reference images whose Platform Key was a test certificate explicitly labelled "DO NOT TRUST" and whose private key leaked years earlier in a vendor repo. The PK is the root of Secure Boot's key hierarchy: it signs Key Exchange Keys (KEKs), which sign db (allowed signers) and dbx (revoked) updates. Owning the PK private key lets an attacker rewrite db at runtime and authenticate any bootloader — including BlackLotus-class bootkits that survive OS reinstall.

## Preconditions / where it applies
- Affected firmware shipped by Acer, Dell, Fujitsu, Gigabyte, HP, Intel, Lenovo, Supermicro and others (see Binarly's PKfail.io list)
- Local administrator / kernel-mode access on the running OS to call `SetVariable` against the auth EFI variables
- Or physical/SPI access to reflash the firmware
- The host has not been re-keyed with a vendor production PK after the OEM patched firmware

## Technique
Detect first: extract `PK`, `KEK`, `db`, `dbx` variables and check the issuer/subject of the PK certificate against Binarly's known-bad list.

```bash
# Linux
efi-readvar -v PK -o pk.esl
sbsiglist --show pk.esl   # look for "DO NOT TRUST - AMI Test PK"
```

Or Binarly's `efiXplorer` / their `pk.fail` checker tool.

Exploit (conceptual) — with the leaked private key for that PK in hand:

1. Generate an attacker KEK certificate, sign its `EFI_SIGNATURE_LIST` with the leaked PK → `KEK.auth`.
2. Generate a db entry containing the certificate that signs your malicious bootloader → `db.auth`.
3. From an admin OS session, call `SetVariable("KEK", AUTHENTICATED_WRITE_ACCESS, KEK.auth)` and similarly for `db`. The firmware validates against the (compromised) PK and accepts the update.
4. Replace the EFI bootloader on the ESP with the attacker-signed payload. On next boot, Secure Boot validates against the now-attacker-controlled db and lets it run.

End result: persistent, pre-OS code execution that survives reinstall and disk swap, with full pre-kernel control (DMA, SMM hooking, kernel patch).

## Detection and defence
- Run Binarly's free pk.fail scanner against the firmware image or live system
- Apply the OEM firmware update that ships a production PK and rotate keys (`KEK`, `db`, `dbx`)
- Push the Microsoft-signed dbx revocations that block the known-bad PK certificates where possible
- Monitor for EFI variable writes to `PK`, `KEK`, `db` from the OS — these are rare in steady state
- Hardware root of trust (Intel BootGuard, AMD PSB) and measured boot to TPM provide defence-in-depth against tampered firmware

## References
- [Binarly — PKfail disclosure](https://www.binarly.io/blog/pkfail-untrusted-platform-keys-undermine-secure-boot-on-uefi-ecosystem) — full technical writeup
- [pk.fail scanner](https://pk.fail/) — check a firmware image or device
- [NVD — CVE-2024-8105](https://nvd.nist.gov/vuln/detail/CVE-2024-8105) — CVE entry
