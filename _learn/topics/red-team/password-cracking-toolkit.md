---
title: Password Cracking Toolkit Fundamentals
slug: password-cracking-toolkit
---

> **TL;DR:** Identify the hash, pick hashcat or john with the right mode, layer a good wordlist with rules, and throw GPUs at it — order matters more than raw horsepower.

## What it is
Offline cracking turns captured hashes into plaintext credentials for lateral movement and persistence. The workflow is always: classify the hash, choose the engine (`hashcat` for GPU, `john` for exotic formats), select wordlist + rules, and budget cracking time against engagement deadlines. Beginners waste hours brute-forcing what a 30-minute targeted rule run would have solved.

## Preconditions / where it applies
- Foothold type: any — cracking happens on attacker hardware, not the victim
- Target OS: attacker side; common hash sources are `/etc/shadow`, NTDS.dit, SAM, Kerberos AS-REP/TGS, WPA handshakes
- Egress restrictions: none — fully offline, can be done in a hotel room

## Technique
Identify first (don't guess):
```bash
hashid 'aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0'
hash-identifier
```

Common hashcat modes worth memorising:
```bash
# 1000  = NTLM
# 1800  = sha512crypt ($6$ shadow)
# 5500  = NetNTLMv1
# 5600  = NetNTLMv2
# 13100 = Kerberos TGS-REP (Kerberoasting)
# 18200 = Kerberos AS-REP (AS-REP roasting)
# 22000 = WPA-PBKDF2-PMKID+EAPOL
hashcat -m 1000 ntlm.txt rockyou.txt -r rules/best64.rule
hashcat -m 13100 tgs.txt rockyou.txt -r rules/OneRuleToRuleThemAll.rule
```

John for shadow files and odd formats:
```bash
unshadow /etc/passwd /etc/shadow > combined
john --format=sha512crypt --wordlist=rockyou.txt combined
john --show combined
```

WPA workflow with hcxdumptool:
```bash
hcxdumptool -i wlan0 -o cap.pcapng --enable_status=1
hcxpcapngtool -o hash.hc22000 cap.pcapng
hashcat -m 22000 hash.hc22000 rockyou.txt -r rules/best64.rule
```

Performance rules of thumb:
- GPU dominates fast hashes (NTLM, MD5, SHA1) — millions/sec on a 3090
- CPU still relevant for bcrypt, scrypt, argon2 — `john --fork=N`
- Distribute across hosts with hashcat brain mode (`--brain-client`) or split wordlist chunks

## Detection and defence
- Cracking itself is undetectable — defence is making hashes useless
- Hardening: long passphrases (16+), enforce bcrypt/argon2 for app passwords, disable NTLMv1, require AES-only Kerberos tickets, set service accounts to gMSA so they have 120-char random passwords immune to dictionary attacks

## References
- [hashcat example hashes](https://hashcat.net/wiki/doku.php?id=example_hashes) — mode reference
- [OneRuleToRuleThemAll](https://github.com/NotSoSecure/password_cracking_rules) — high-yield rule file

See also: [[living-off-the-land]], [[linpeas-and-enumeration-flow]], [[pivoting-and-tunneling]].
