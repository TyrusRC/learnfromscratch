---
title: TunnelVision (DHCP option 121 VPN decloak)
slug: tunnelvision-dhcp-opt121
---

> **TL;DR:** A rogue DHCP server pushes DHCP option 121 (Classless Static Routes) with a `/1`-or-narrower route that beats the VPN's default-route metric, decloaking selected traffic outside the tunnel while the VPN status indicator still reads "connected" (CVE-2024-3661, disclosed May 2024).

## What it is
TunnelVision exploits a design feature, not a bug, in how the host OS combines DHCP-provided routes with routes the VPN client installs. DHCP option 121 lets a server inject classless static routes into the client's routing table. Because the OS prefers more-specific prefixes regardless of which interface they came from, a rogue DHCP server can install routes like `0.0.0.0/1` and `128.0.0.0/1` (two halves of the whole address space, each more specific than the VPN's `0.0.0.0/0` default route) and silently steer traffic onto the physical interface. The VPN tunnel stays up, kill-switches that monitor the tunnel state do not trip, and the user sees no warning.

## Preconditions / where it applies
- Attacker controls a DHCP server reachable by the victim — same Wi-Fi/Ethernet segment, a malicious hotspot, or a hostile guest network.
- Victim runs a VPN client that relies on default-route + interface metric for tunnel coverage (most consumer and many enterprise clients are affected: WireGuard, OpenVPN, IPsec via strongSwan, vendor clients).
- The OS honours DHCP option 121. Linux, Windows, iOS and macOS all do; Android historically does not.
- The attack does *not* require breaking the VPN crypto; it simply routes around it.

## Technique
Bring up a hostile DHCP server that hands out option 121 routes carving the IPv4 space:

```bash
# dnsmasq fragment — install two /1 routes pointing at our gateway (10.66.66.1)
dhcp-option=121,0.0.0.0/1,10.66.66.1,128.0.0.0/1,10.66.66.1
# plus a normal lease
dhcp-range=10.66.66.50,10.66.66.150,12h
```

When the victim's lease renews or they connect to the segment, the OS adds those routes. Anything destined to "real" IPs takes the on-link gateway path and bypasses the VPN tunnel. The attacker can sniff cleartext, MITM TLS with a hostile CA, or selectively decloak specific destinations by inserting only narrow `/24`s for high-value services rather than the full `/1` pair.

Notes:
- Original PoC by Leviathan uses standard ISC DHCP / dnsmasq plus iptables forwarding.
- IPv6 has analogous RA-based decloak vectors but is out of scope of CVE-2024-3661 specifically.
- The attack survives reconnects because each new DHCP lease re-applies the routes.

## Detection and defence
- Network namespaces or routing tables that isolate the tunnel from DHCP-provided routes mitigate completely. Linux: run the VPN process inside a netns whose only route is the tunnel.
- Firewall rules that drop traffic on the physical interface for non-VPN-destined flows (proper kill switch implemented at the firewall layer, not by polling VPN status).
- Ignore DHCP option 121 on networks deemed untrusted; some clients (Mullvad, others) now strip it.
- For corp deployments: always-on VPN with policy-routed default + iptables/`nftables` `oifname != "wg0" drop` makes the rogue routes irrelevant.
- Detect server-side by anomaly: dual default-coverage routes via different gateways appearing right after a DHCP renew is the smoking gun.

## References
- [Leviathan Security — TunnelVision disclosure](https://www.leviathansecurity.com/blog/tunnelvision) — original write-up with PoC and affected-OS matrix.
- [CVE-2024-3661 (NVD)](https://nvd.nist.gov/vuln/detail/CVE-2024-3661) — formal record.
- [RFC 3442 — Classless Static Route Option for DHCPv4](https://datatracker.ietf.org/doc/html/rfc3442) — option 121 spec the attack abuses.
- [Mullvad — TunnelVision mitigations](https://mullvad.net/en/blog/tunnelvision-mullvad-vpn-is-not-affected) — example client-side mitigation strategy.
