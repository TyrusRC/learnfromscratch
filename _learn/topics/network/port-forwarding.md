---
title: Port forwarding
slug: port-forwarding
---

> **TL;DR:** Three directions — local (bring a remote port to you), remote (push a local port to a remote listener), and dynamic (SOCKS). Pick by where the listener needs to live and which direction egress allows.

## What it is
Port forwarding tunnels a TCP (and sometimes UDP) stream through an existing connection so a service on one side of a network boundary is reachable from the other. The classic implementation is SSH, but the same three directional patterns apply to chisel, ligolo, socat, plink, and meterpreter portfwd. Understanding the semantic difference between local/remote/dynamic is more important than memorising flags — once you can map "where does the listener bind?" to "which direction?" every tool's syntax falls out.

## Preconditions / where it applies
- An established control channel between attacker and pivot (SSH session, C2 implant, chisel session, etc.).
- For local forwarding: pivot can reach the target service.
- For remote forwarding: attacker host can accept inbound from the pivot or holds the listener.
- Egress policy that allows the control-channel protocol (key constraint — drives [[chisel]] vs [[ssh-tunneling]] choice).

## Technique
**Local forward (`-L`)** — listener on attacker host, traffic emerges on the pivot side:

```bash
# Reach internal SQL Server through a pivot you SSH'd into
ssh -L 1433:10.10.20.5:1433 alice@pivot
# Now: mssqlclient.py CORP/u:p@127.0.0.1
```

**Remote forward (`-R`)** — listener on the *far* end, traffic emerges on the side that issued the command. The fundamental pivot-out-of-a-foothold pattern when only outbound is allowed:

```bash
# From compromised host that has only egress on 22/tcp
ssh -R 8000:127.0.0.1:8080 attacker@vps
# attacker:8000 -> foothold:8080
```

**Dynamic (`-D`)** — SOCKS proxy on the side issuing the command, exit on the far side:

```bash
ssh -D 1080 alice@pivot
proxychains4 -q nmap -sT -Pn 10.10.20.0/24
```

Non-SSH equivalents to keep in mind:

```bash
# socat — quick TCP relay on a Linux pivot
socat TCP-LISTEN:9001,fork,reuseaddr TCP:10.10.20.5:445

# netsh — Windows pivot, persistent across reboots if needed
netsh interface portproxy add v4tov4 listenport=9001 \
  listenaddress=0.0.0.0 connectport=445 connectaddress=10.10.20.5
```

For chains of three or more hops, use SSH `ProxyJump` (`-J host1,host2`) or stack chisel/ligolo sessions — see [[ssh-tunneling]], [[chisel]], [[ligolo-ng]].

## Detection and defence
- Long-lived SSH connections with unusual bytes-out-to-bytes-in ratios — Zeek `ssh.log` plus volumetric heuristics.
- Windows `netsh portproxy` registers a service; EDR rules around `iphlpsvc` plus the registry key `HKLM\SYSTEM\CurrentControlSet\Services\PortProxy` catch it.
- Restrict outbound from server segments to an allow-listed set of ports/destinations; force egress through an authenticated proxy with TLS interception.
- On hardened jump hosts, disable `AllowTcpForwarding`, `PermitTunnel`, and `GatewayPorts` in sshd_config.

## References
- [HackTricks — tunneling and port forwarding](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/tunneling-and-port-forwarding.html) — directional cheat sheet across tools.
- [OpenSSH manpage — `-L`/`-R`/`-D`](https://man.openbsd.org/ssh) — authoritative semantics.
- [ired.team — port forwarding and tunneling](https://www.ired.team/offensive-security/lateral-movement/port-forwarding-and-tunneling) — Windows-side patterns including netsh portproxy.
