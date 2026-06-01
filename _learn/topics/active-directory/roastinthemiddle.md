---
title: RoastInTheMiddle (RITM)
slug: roastinthemiddle
---

> **TL;DR:** Dirk-jan Mollema's RoastInTheMiddle injects attacker-chosen parameters into in-flight AS-REQ pre-auth traffic, harvesting Kerberos hashes without ever touching a credential store.

## What it is
Presented at Black Hat EU 2022 by Dirk-jan Mollema, RoastInTheMiddle is an on-path Kerberos attack that tampers with AS-REQ messages flowing between victims and the KDC. By rewriting the pre-auth `etype-info2` advertisement or the requested encryption types, the attacker downgrades a target to RC4 or coerces an AS-REP that can be cracked offline — essentially mass AS-REP roasting *with* pre-auth enabled. Outcome: bulk recovery of Kerberos long-term keys for any user that authenticates through the controlled network segment.

## Preconditions / where it applies
- Position on-path (ARP poisoning, IPv6 mitm6, rogue DHCP, SMB relay pivot, etc.)
- Target traffic is unsigned Kerberos over UDP/TCP 88 — typical for workstation logon
- Domain still permits RC4 in `msDS-SupportedEncryptionTypes` (default before Windows Server 2025)
- Users with weak passwords (offline crack feasibility)

## Technique
Run the public PoC `roastinthemiddle` while poisoning the segment with mitm6 or arpspoof.

```bash
# 1. Position: IPv6 takeover of the local segment
mitm6 -d corp.local -i eth0 --no-ra

# 2. Capture and rewrite AS-REQ flows
git clone https://github.com/dirkjanm/krbrelayx
python3 krbrelayx/roastinthemiddle.py \
    -i eth0 -d corp.local --downgrade-rc4 \
    -o ritm-hashes.txt

# 3. Crack the harvested $krb5asrep$23$ hashes offline
hashcat -m 18200 ritm-hashes.txt rockyou.txt -r best64.rule
```

The tool emits standard `$krb5asrep$` strings even for accounts that *require* pre-auth, because the response is captured post-downgrade before validation.

## Detection and defence
- Event ID 4768 with `Ticket Encryption Type 0x17` (RC4) on accounts whose `msDS-SupportedEncryptionTypes` no longer allows it
- Sudden surge of 4768s from a single source IP for many distinct users
- Enforce Kerberos armoring (FAST) via group policy and disable RC4 domain-wide
- Defender for Identity "Suspected encryption downgrade activity (Skeleton Key)" rule covers similar telemetry
- Network: alert on IPv6 RAs from non-router MACs (mitm6 fingerprint) and on Kerberos pre-auth retries with mismatched etypes

## References
- [Black Hat EU 2022 — Kerberos' RC4-HMAC fall and rise](https://www.blackhat.com/eu-22/briefings/schedule/index.html) — Mollema's talk slot
- [krbrelayx repository](https://github.com/dirkjanm/krbrelayx) — RITM tool source

See also: [[asreproast]], [[kerberos]], [[ntlm-relay-ws2025-mitigations]].
