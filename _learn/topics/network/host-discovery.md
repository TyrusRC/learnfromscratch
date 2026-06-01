---
title: Host discovery
slug: host-discovery
---

> **TL;DR:** Build a set of live IPs before you port-scan. Probe choice (ARP, ICMP, TCP-SYN, TCP-ACK, UDP) depends on adjacency and what the network filters.

## What it is
Host discovery is the first measurement step of a network engagement: turning a target range into a set of responsive IPs so you don't waste time port-scanning empty space. The trick is that no single probe works everywhere. Layer-2 ARP is authoritative on a local segment, ICMP is often filtered at egress, and a stateful firewall may drop SYN to closed ports but accept ACK. A blended sweep — using whichever probe the segment cannot suppress — is the realistic answer.

## Preconditions / where it applies
- An IP range or list of targets (CIDR, file of IPs, or a discovered subnet from [[osint-recon]]).
- Network position: layer-2 adjacent for ARP; routed reach for ICMP/TCP; on the right VLAN for broadcast.
- Permission to probe — host discovery is still scanning and triggers IDS in most environments.

## Technique
Probe selection by position:

```bash
# Layer-2 adjacent — ARP is unfilterable on the local broadcast domain
nmap -sn -PR 10.10.10.0/24
# fast pure-ARP alternative
arp-scan --localnet
```

```bash
# Routed: blend ICMP echo, timestamp, TCP-SYN 443, TCP-ACK 80, UDP 40125
nmap -sn -PE -PP -PS443 -PA80 -PU40125 --min-rate 500 10.0.0.0/16
```

```bash
# Internet-facing — masscan for raw speed, then nmap to refine
masscan -p80,443,22 10.0.0.0/16 --rate 10000 -oG masscan.gnmap
awk '/Host:/ {print $2}' masscan.gnmap | sort -u > live.txt
```

Notes:
- `-Pn` disables discovery and treats every IP as up — useful when you know hosts filter ICMP but expensive on /16 ranges.
- TCP-ACK probes (`-PA`) elicit RST from anything not behind a stateful filter, so they distinguish "host alive but filtering SYN" from "no host".
- A high `--source-port 53` or `--source-port 88` sometimes bypasses naive ACL rules built around expected return traffic.

For Windows-only segments, an `nbtscan` or `nmap --script smb-discover` sweep against 137/445 catches hosts that drop ICMP but answer to NetBIOS. For IPv6, link-local multicast (`ping6 ff02::1%iface`) discovers everything on segment.

## Detection and defence
- ARP storms and sequential SYN sweeps stand out in NDR (Zeek `conn.log` with high `orig_pkts` and low `resp_pkts`).
- Rate-limit ICMP and enforce egress filtering so external scanners get less ground truth.
- Disable answers to NetBIOS name service if unused, and consider LLMNR/mDNS suppression — they leak hosts as a side effect.
- Honeypot IPs on otherwise empty subnets flag scanners on first packet — cheap and high-signal.

## References
- [Nmap — host discovery](https://nmap.org/book/man-host-discovery.html) — definitive reference for each `-P*` probe.
- [HackTricks — pentesting network](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/pentesting-network/index.html) — discovery cheats and IPv6 tricks.
- [arp-scan manpage](https://github.com/royhills/arp-scan) — layer-2 alternative to nmap for local segments.
