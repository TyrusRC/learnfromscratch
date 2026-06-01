---
title: SNMP enumeration
slug: snmp-enum
---

> **TL;DR:** UDP 161 with a guessable community string returns a torrent of inventory data — running processes, installed software, ARP tables, route tables, user accounts on Windows, interface configs on network gear.

## What it is
SNMP is a stateless UDP query/response protocol whose v1/v2c "authentication" is a single community string. Read-only `public` and read-write `private` are the defaults vendors ship; both linger in production for decades. The MIB exposed varies by device — but a default Windows host with the SNMP service installed will leak processes (`hrSWRunName`), software (`hrSWInstalledName`), interface ARP (`ipNetToMediaPhysAddress`), and even the local user list (`lanmanager.MIB`). Network devices leak routes and full running configs.

## Preconditions / where it applies
- UDP reach to 161 on the target (often blocked at perimeter but wide-open internally).
- Valid community string for v1/v2c — `public` first, then a wordlist; or valid creds for v3 (rare in pentest context).
- Patience for UDP — packet loss means probes must be re-tried.

## Technique
Sweep for live SNMP and guess community:

```bash
nmap -sU -p161 --script snmp-info,snmp-brute 10.0.0.0/24
onesixtyone -c communities.txt -i hosts.txt
```

Once you have a community, walk the entire tree to a file then grep — far faster than ad-hoc queries:

```bash
snmpwalk -v2c -c public 10.0.0.50 .1 > walk-50.txt
grep -E 'hrSWRunName|hrSWInstalledName|ipNetToMediaPhysAddress' walk-50.txt
```

High-signal OIDs for Windows hosts:

```text
1.3.6.1.2.1.25.4.2.1.2  hrSWRunName       running processes
1.3.6.1.2.1.25.6.3.1.2  hrSWInstalledName installed software
1.3.6.1.4.1.77.1.2.25   svSvcName         services
1.3.6.1.4.1.77.1.2.27   svUserTable       local user accounts (legacy LANMAN MIB)
1.3.6.1.2.1.6.13.1.3    tcpConnLocalPort  open TCP connections
```

For network devices, `snmp-check` or `snmpwalk` against the configuration OID returns the running config — and Cisco's TFTP-export OID (`1.3.6.1.4.1.9.9.96`) can be set via SNMP write to dump config to an attacker-controlled TFTP server when you have `private`.

```bash
snmp-check 10.0.0.1 -c public
```

SNMPv3 introduces user-based auth and encryption; brute-forcing v3 is largely impractical, but mis-deployed v3 sometimes still accepts a fallback v2c community.

## Detection and defence
- Disable SNMP entirely unless monitoring requires it; if required, prefer v3 with `authPriv` (SHA + AES).
- For v1/v2c that cannot be replaced, scope community-string ACLs to monitoring-station IPs only and rotate the strings.
- Alert on SNMP queries from unexpected source IPs; baseline volume per device.
- On Cisco gear, restrict the SNMP view (`snmp-server view`) to a minimal set of OIDs so a leaked community cannot dump configs.

## References
- [HackTricks — pentesting SNMP](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-snmp/index.html) — OID cookbook and tooling.
- [Net-SNMP — snmpwalk manpage](http://www.net-snmp.org/docs/man/snmpwalk.html) — query semantics.
- [onesixtyone](https://github.com/trailofbits/onesixtyone) — fast community-string brute forcer.
- [Cisco — SNMPv3 configuration guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/snmp/configuration/15-mt/snmp-15-mt-book/nm-snmp-snmpv3.html) — secure deployment reference.
