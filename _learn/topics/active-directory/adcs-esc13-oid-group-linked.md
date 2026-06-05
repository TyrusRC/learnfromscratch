---
title: ADCS ESC13 — OID group-linked certificates
slug: adcs-esc13-oid-group-linked
aliases: [esc13, adcs-oid-group, oid-group-linked-cert]
---

> **TL;DR:** ESC13 is an ADCS misconfiguration where a certificate template's Issuance Policy includes an OID that has been linked to an Active Directory group via the `msDS-OIDToGroupLink` attribute. A user who enrols a certificate carrying that OID is treated as a member of the linked group at logon — without any actual AD group membership change. If the linked group is privileged, the user escalates. Disclosed by Jonas Knudsen (SpecterOps). Joins the ESC1–ESC16+ family. Companion to [[adcs-attacks]] and [[adcs-esc14-altsecidentities]].

## Why this matters

- A subtle escalation primitive that **doesn't modify any group membership** in the directory — auditing on `member`/`memberOf` won't catch it.
- ADCS templates with issuance policies are common in mature deployments; many include sensitive OIDs.
- The misconfiguration is **invisible from group-management consoles**; only `msDS-OIDToGroupLink` traversal surfaces it.
- Part of the long-tail of ADCS abuse SpecterOps and others have documented; new ESC numbers continue to appear.

## How the trust works

Active Directory ties Issuance Policy OIDs to security groups via the `msPKI-Enterprise-OID` objects under `CN=OID,CN=Public Key Services,CN=Services,CN=Configuration,DC=…`. Each such OID object may have an `msDS-OIDToGroupLink` linking it to a security group.

At Kerberos PKINIT logon (smartcard or certificate logon):

- The user's certificate carries one or more Issuance Policy OIDs in the cert extensions.
- The DC consults `msDS-OIDToGroupLink` for each OID.
- If linked, the DC adds the linked group's SID to the user's logon token (as if the user were a member).

The user is **effectively a member** of the linked group for the duration of the session.

## Pre-conditions for ESC13

- A certificate template with an Issuance Policy OID configured.
- That OID's AD object has `msDS-OIDToGroupLink` set to a group of operator interest.
- A principal (user or computer) the attacker controls has `Enroll` permission on the template.
- ADCS Enterprise CA can issue certificates with the OID's extension.

If all four hold, the attacker enrols, gets a cert, logs in via PKINIT, and is in the linked group.

## Exploit shape

1. Enumerate ADCS templates with issuance-policy OIDs (Certipy `find`).
2. For each, look up the OID in `CN=OID,...` and check `msDS-OIDToGroupLink`.
3. Identify linked groups; pick one of interest (Domain Admins, Backup Operators, etc.).
4. Confirm enrolment rights on the template (Authenticated Users is the worst-case).
5. Enrol — `certipy req`.
6. PKINIT — `certipy auth` or Rubeus.
7. Use the TGT; token now contains the linked group's SID.

(Lab only. Authorisation required.)

## Detection

- Audit `msDS-OIDToGroupLink` writes on `msPKI-Enterprise-OID` objects — change events should be rare.
- Audit certificate enrolment events (`4886`, `4887`) for templates that carry sensitive OIDs.
- Correlate cert-enrolment subject with subsequent PKINIT logons and the resulting token groups.

## Defensive baseline

- **Inventory** all `msPKI-Enterprise-OID` objects. Map any with `msDS-OIDToGroupLink` set.
- For each, confirm the linkage is intentional and the group is appropriate.
- For each linked-OID template, **restrict enrolment** to a specific narrow group.
- **Avoid** linking high-privilege groups (Domain Admins, Enterprise Admins) to any OID.
- Treat the `CN=OID` container as **tier-0** — only Enterprise Admins should write.

## How ESC13 fits the ESC family

- ESC1–ESC3 — template / enrolment / supplier misconfigs.
- ESC4 — vulnerable template ACLs.
- ESC5 — vulnerable CA configuration.
- ESC6 — `EDITF_ATTRIBUTESUBJECTALTNAME2`.
- ESC7 — CA permissions / ICertAdmin.
- ESC8 — NTLM relay to ADCS web enrollment.
- ESC9, ESC10 — `userPrincipalName` mapping with weak SAN handling.
- ESC11 — relay to ICPR ([[adcs-attacks]]).
- ESC12 — YubiKey / smart card enrolment bypass.
- ESC13 — *this note*.
- ESC14 — see [[adcs-esc14-altsecidentities]].
- ESC15 — see [[adcs-esc15-ekuwu]].
- ESC16 — see [[adcs-esc16-securityext-disabled]].

The list grows as researchers find new edge cases. New entries land roughly twice a year. Treat ADCS as a moving target.

## Workflow to study in a lab

1. Stand up AD + ADCS lab.
2. Create a security group `linked-target`.
3. Create an OID object under `CN=OID` and set `msDS-OIDToGroupLink` to point at `linked-target`.
4. Create a cert template referencing the OID as Issuance Policy; allow Authenticated Users to enrol.
5. Enrol from a low-priv user; PKINIT.
6. Check the user's token (`whoami /groups`) — observe `linked-target` SID present.

## References
- [Jonas Knudsen — ESC13 disclosure (SpecterOps)](https://posts.specterops.io/)
- [Will Schroeder & Lee Christensen — Certified Pre-Owned (original ADCS research)](https://specterops.io/wp-content/uploads/sites/3/2022/06/Certified_Pre-Owned.pdf)
- [Certipy](https://github.com/ly4k/Certipy)
- See also: [[adcs-attacks]], [[adcs-esc14-altsecidentities]], [[adcs-esc15-ekuwu]], [[adcs-esc16-securityext-disabled]]
