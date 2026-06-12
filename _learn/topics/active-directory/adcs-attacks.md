---
title: AD CS attacks
slug: adcs-attacks
---

> **TL;DR:** Active Directory Certificate Services exposes a fleet of misconfigurations (ESC1–ESC16) that let low-privileged principals enrol certificates impersonating high-privileged users — usable for PKINIT auth as Domain Admin or for NTLM-relay chains.

## What it is
AD CS is the on-prem PKI that issues smart-card, EFS, code-signing, and authentication certificates. Misconfigured templates, vulnerable endpoints, and weak default ACLs let an attacker request a certificate whose Subject Alternative Name (or implicit identity) is a privileged account, then authenticate as that account via Kerberos PKINIT or Schannel. The technique family was popularised by SpecterOps' "Certified Pre-Owned" research and now numbers over a dozen distinct escalations.

## Preconditions / where it applies
- Domain user (or even unauthenticated, for ESC8/ESC11) with line of sight to a CA web/RPC endpoint
- Vulnerable template published and enrollable, or vulnerable endpoint (HTTP/RPC), or weak ACL on a CA object
- A KDC that accepts PKINIT for the cert (default), or a relay target accepting Schannel/HTTP NTLM

## Technique
The numbered escalations cluster into three groups:

**Template-based (ESC1–ESC3, ESC9, ESC10, ESC13–ESC15):** template grants client-auth EKU, lets the requester supply SAN, or has a chained Enrollment Agent / V1-schema flaw. Request the cert with `certipy req`, then auth.

```bash
certipy find -u user@corp -p pass -dc-ip 10.0.0.10 -vulnerable -stdout
certipy req -u user@corp -p pass -ca CORP-CA -template VulnTemplate \
  -upn administrator@corp.local -dc-ip 10.0.0.10
certipy auth -pfx administrator.pfx -dc-ip 10.0.0.10
```

**Endpoint-based (ESC8, ESC11):** the CA Web Enrollment (HTTP) or RPC (ICertPassage) interface accepts NTLM without channel binding. Coerce a DC or Exchange machine account (PetitPotam) and relay to `/certsrv/certfnsh.asp` to get a machine cert — then S4U2self for any user.

**Object-/CA-based (ESC4–ESC7, ESC12, ESC16):** weak ACL on a template (ESC4) or CA (ESC7) lets you write `mspki-certificate-name-flag` to add `ENROLLEE_SUPPLIES_SUBJECT`, then enrol as anyone. ESC16 disables the `szOID_NTDS_CA_SECURITY_EXT` SID extension globally on the CA so SAN spoofing slips past the 2022 patch.

PKINIT yields a TGT with the user's NT hash inside (`UnPAC-the-hash`) — useful for further lateral movement.

When Certipy is off the table, the same enrollment can be done by hand: build an OpenSSL CSR whose `subjectAltName` includes `otherName:1.3.6.1.4.1.311.20.2.3;UTF8:administrator@corp.local` (the Microsoft UPN OID), submit it via `/certsrv` advanced enrollment, and convert the response with `openssl pkcs12 -keyex -CSP "Microsoft Enhanced Cryptographic Provider v1.0" -export` so the resulting PFX is consumable by Rubeus's `asktgt /certificate /ptt`. The CSP string matters — without it Windows refuses to use the cert for PKINIT.

## Detection and defence
- Audit template ACLs and the `mspki-enrollment-flag` / `mspki-certificate-name-flag` bits; remove `ENROLLEE_SUPPLIES_SUBJECT` from client-auth templates
- Enable EPA + signing-only on `/certsrv` and disable NTLM on the CA web role; patch KB5014754 and confirm `StrongCertificateBindingEnforcement = 2`
- Hunt event 4886/4887 (cert requested/issued) where SAN ≠ requester and EKU includes Client Authentication
- BloodHound CE ships AD CS edges; Certipy `find -vulnerable` enumerates the same surface as a red-teamer

## References
- [Certified Pre-Owned (SpecterOps)](https://posts.specterops.io/certified-pre-owned-d95910965cd2) — original ESC1–ESC8 paper
- [Certipy wiki](https://github.com/ly4k/Certipy/wiki) — current ESC catalogue and command reference
- [HackTricks — AD CS abuse](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/ad-certificates/domain-escalation.html) — concise per-ESC playbook
- [ired.team — Misconfigured cert template to DA](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/from-misconfigured-certificate-template-to-domain-admin) — Certify + manual OpenSSL CSR workflow for ESC1
- See also: [[adcs-esc14-altsecidentities]], [[adcs-esc15-ekuwu]], [[adcs-esc16-securityext-disabled]], [[shadow-credentials]], [[certipy-toolkit-deep]]
