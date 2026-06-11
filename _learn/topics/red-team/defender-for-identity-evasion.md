---
title: Defender for Identity (MDI) evasion
slug: defender-for-identity-evasion
aliases: [mdi-evasion, azure-atp-evasion, defender-identity-evasion]
---

> **TL;DR:** Defender for Identity (formerly Azure ATP) is Microsoft's identity ITDR. It sits on DCs as a lightweight sensor and reads kernel ETW + LDAP + DNS + NTLM/Kerberos traffic to score behaviour. Evasion isn't about disabling it; it's about staying under the thresholds, using primitives MDI doesn't model, and timing operations so they don't cluster. Pair with [[itdr-identity-threat-detection-response]] (defender view) and [[opsec-fundamentals]].

## Mental model

MDI sensor (`Microsoft.Tri.Sensor.Updater.exe` / `AzureAdvancedThreatProtectionSensorSetup.exe`) runs as a service on every DC (and any AD FS / AD CS servers you target). It feeds three pipelines:

1. **Network parsing** — captures Kerberos, NTLM, LDAP, DNS, RPC, SMB traffic (NDIS-level on the DC NIC). Doesn't *block*; observes.
2. **ETW + Event Log subscription** — security events (4768, 4769, 4776, 4624), directory-service-changes, account lockouts.
3. **AAD Connect / cloud signal correlation** — joins on-prem activity with Entra sign-ins (this is what makes "Suspicious hybrid identity activity" alerts possible).

MDI ships ~70 detections (~2025 catalogue). Three categories matter:

- **Reconnaissance** — high signal, low severity. Triggered by enumeration patterns: BloodHound LDAP, SMB session enum, SAMR reach, DNS AXFR, etc.
- **Lateral movement / credential** — DCSync from non-DC, NTLM relay shape, Pass-the-Hash patterns, Kerberoasting, Golden/Silver/Diamond ticket indicators.
- **Domain dominance** — skeleton key, DCShadow, suspicious additions to sensitive groups, malicious replication.

## Detections that bite — and how operators dodge

### "Reconnaissance using directory services" (LDAP enum)

Trigger: high LDAP query rate with sensitive-attribute filters from a non-tier-0 source.

Dodge:
- `SharpHound -CollectionMethod DCOnly --Stealth` — single LDAP search, no SMB session/local-group queries.
- Use `ldapsearch` paginated (`-E pr=200/noprompt`) with `<5 req/s`, focused queries (`(servicePrincipalName=*)` once, not 50 times).
- `nxc ldap dc --kerberoasting` is loud — use `GetUserSPNs.py -outputfile` and a single query.

### "Reconnaissance using SMB session enumeration"

Trigger: `SAMR`/`SRVSVC` session enumeration across many hosts (`NetSessionEnum`).

Dodge:
- BloodHound CE no longer requires `Session` for high-value pathing; collect `DCOnly` and skip `Session`.
- If you need sessions: `Restrict-NetSessionEnum` is the *defensive* knob — assume it's set, fall back to ETW logon events or `GetMembersBySSID` indirection.

### "Suspicious additions to sensitive groups"

Trigger: any add to Domain/Enterprise/Schema Admins, DnsAdmins, Backup Operators, Account Operators.

Dodge:
- Don't add yourself to DA. Use ACL-grant primitives ([[acl-abuse]], [[adminsdholder-abuse]]) or RBCD instead — they yield equivalent power without group membership.
- If you must add: do it via the *delegated* admin context (a real admin's TGS) and immediately remove. MDI alert is real-time but post-action.

### "Suspected DCSync attack"

Trigger: `IDL_DRSGetNCChanges` from a non-DC source IP.

Dodge:
- Stage the dump from a *compromised DC* itself (run secretsdump locally; suppress the network call).
- Use `-use-vss` to read NTDS off a shadow copy — alerts on disk-side telemetry but not on DRSR.
- Use `ntdsutil "activate instance ntds" "ifm" "create full c:\dump" quit quit` from a DA session on the DC — looks like backup work.
- Diamond-ticket detection avoidance ≠ DCSync detection avoidance; you still need a path to krbtgt or NTDS contents.

### "Kerberoasting" / "AS-REP roasting"

Trigger: large number of `TGS-REQ` / `AS-REQ` for accounts without pre-auth in a short window; encryption type RC4 when AES is enabled tenant-wide.

Dodge:
- Use `-aes` (`GetUserSPNs.py -outputfile` with explicit AES request) — fewer alerts than RC4 default.
- Roast one SPN at a time, ~5+ min apart. Hard for SOC to glue together.
- AS-REP roast on a single user, not a list.

### "Suspected Golden Ticket usage / Encryption downgrade activity"

Trigger: Kerberos ticket whose properties (ticket lifetime > policy, RC4 in AES domain, missing PAC fields) deviate from norm; usage of a service ticket whose TGT was issued >domain-max-lifetime ago.

Dodge:
- Use [[diamond-and-sapphire-tickets]] not classic golden — PAC structure is real.
- Don't set 10-year lifetimes. Respect the domain's `MaxTicketAge` (10h default).
- AES256-only encryption for any forged tickets.

### "Suspected NTLM relay attack"

Trigger: same NTLM challenge seen authenticating against multiple servers in a short window (the relay smoking gun).

Dodge:
- Use one challenge per target. `ntlmrelayx --remove-target-after-first-success` (custom patches do this) — by default Impacket reuses sessions efficiently and that's the detection.
- Prefer Kerberos relay primitives (RBCD, Shadow Creds) where possible — MDI's NTLM-relay detection doesn't trip on Kerberos handlers.

### "Suspected identity theft (pass-the-hash)"

Trigger: hash material reused across hosts in patterns that don't match normal user behaviour; correlation of `4624 LogonType 3 + KerberosTicketEncryption RC4`.

Dodge:
- Overpass-the-hash to AES Kerberos (request TGT with the NT hash, use Kerberos onward) — pure NTLM pass-the-hash is the loud variant.
- Stagger uses; one logon per minute, not a sweep.

### "Honeytoken activity"

Trigger: any auth against a designated honeytoken account.

Dodge:
- Enumerate honeytokens before touching anything. They live in MDI portal config but you can fingerprint them by **abnormal attribute combos** (never-logged-on, recently created, highly privileged, no SPN, in a hidden OU). LDAP query for users with `lastLogonTimestamp=0` and `pwdLastSet > 1 year` plus admin SID history is the standard hunt.
- Don't kerberoast every SPN — filter by `lastLogonTimestamp > 30d` and skip the dormant ones.

## Operational discipline

- **Pre-engagement**: Run `Get-MpComputerStatus` on any compromised endpoint to confirm MDE; ETW providers `Microsoft-Windows-Kerberos/Operational`, `Microsoft-Windows-NTLM/Operational` indicate MDI sensor presence. `Get-Service AATPSensorUpdater` on a DC = MDI installed.
- **Throttle**: `--jitter 30 --delay 5` on anything that touches a DC.
- **Reorder**: do recon from a *trusted* tier-0 foothold (e.g., an SCCM box) so signal looks like legitimate management activity.
- **Source-IP discipline**: route through the workstation of an actual admin (if compromised) so the source IP and host name match normal admin behaviour.

## Detection (defender side)

- MDI alerts live in the **Microsoft Defender XDR** portal (`security.microsoft.com → Identities → Alerts`). Severity tagging: Low (recon), Medium (lateral), High (dominance).
- Each alert has an "Affected entities" graph — that graph is the analyst's first move. Mucking with the timeline (clock skew, source-IP jitter) muddies it.
- MDI sensor health: red sensor = blind DC. Watch for sensor crashes after privileged ops on the DC — that itself is a forensic flag.

## OPSEC pitfalls

- MDI is a *detection* product; it doesn't block. The risk is the SOC alert + IR — but a well-tuned SOC responds in minutes to identity alerts. Optimise for *not generating the alert*, not for "what does the alert look like".
- Honeytoken users are sometimes named with adversary bait keywords (`backup`, `svc-old`, `legacy-admin`). The naming is intentional. Skip plausible bait.
- MDI rolls new detections monthly. A 2024-vintage operator playbook may be detected by a 2026 detection model. Re-read the alert catalogue before each engagement.
- Disabling the sensor on a DC requires SYSTEM on the DC and is itself a high-severity alert ("Sensor became unhealthy"). Don't.
- MDI's "lateral movement path" graph correlates on-prem and Entra signals. If you do post-exploit M365 work from the same operator IP, MDI joins them and you get a "Suspicious hybrid identity activity" composite.

## References

- https://learn.microsoft.com/en-us/defender-for-identity/alerts-overview
- https://learn.microsoft.com/en-us/defender-for-identity/what-is
- https://m365internals.com/ — community catalogue of MDI detections
- https://github.com/JumpsecLabs/Defender-for-Identity-evasion
- https://posts.specterops.io/ (multiple MDI-evasion posts)
- https://github.com/microsoft/Microsoft-Defender-for-Identity

See also: [[itdr-identity-threat-detection-response]], [[opsec-fundamentals]], [[detection-engineering-pyramid-of-pain]], [[bloodhound-ce-deployment]], [[diamond-and-sapphire-tickets]], [[ad-coercion-and-relay-matrix-2025]], [[dcsync]], [[kerberoasting]], [[asreproast]], [[ntlm-relay]], [[ad-recon-low-noise]]
