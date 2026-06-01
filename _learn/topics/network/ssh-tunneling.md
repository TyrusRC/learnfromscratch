---
title: SSH tunneling
slug: ssh-tunneling
---

> **TL;DR:** SSH gives free, encrypted pivoting via `-L`, `-R`, `-D`, and `ProxyJump`. Layer them to traverse multi-hop networks without dropping additional implants.

## What it is
SSH tunneling reuses an authenticated SSH session as a generic transport for arbitrary TCP (and, with `-w`, layer-3). It is the default pivot whenever the foothold runs sshd or you can SSH into the foothold — no extra binary to drop, no novel protocol on the wire that an EDR will flag specifically. The three flag families correspond to the three port-forwarding directions covered in [[port-forwarding]], and `ProxyJump` chains them.

## Preconditions / where it applies
- SSH connectivity in the relevant direction (you to pivot, or pivot to you for reverse).
- `AllowTcpForwarding yes` on the sshd you tunnel through (the OpenSSH default; hardened boxes set it to `no` or `local`).
- For dynamic SOCKS chained through proxychains: target tools that respect SOCKS (most `nmap` scan types do, but ICMP and SYN-scan do not — use `-sT`).

## Technique
**Local forward — bring a remote service to your loopback:**

```bash
ssh -L 8443:internal.app:443 alice@pivot
curl -k https://127.0.0.1:8443/
```

**Remote forward — push your listener through the pivot to a remote network:**

```bash
ssh -R 9001:127.0.0.1:9001 alice@pivot
# attacker:9001 (Metasploit handler) is now reachable from inside pivot's network
```

**Dynamic SOCKS — operator-side SOCKS5 proxy through the SSH session:**

```bash
ssh -D 1080 -fNT alice@pivot
proxychains4 -q nmap -sT -Pn -p- 10.10.20.0/24
```

**Multi-hop with ProxyJump** — chain through bastion → pivot → target without expanding local listeners on each hop:

```bash
ssh -J alice@bastion,alice@pivot alice@target
# ~/.ssh/config equivalent makes it persistent:
Host target
    HostName 10.10.20.5
    ProxyJump alice@bastion,alice@pivot
```

For a routed layer-3 pivot (when you need ICMP, UDP-scan, etc.), use `-w` to set up TUN devices on both ends and route a subnet across — heavyweight compared with [[ligolo-ng]], but built into OpenSSH.

Useful flags: `-fNT` (background, no command, no TTY), `-o ServerAliveInterval=30` (keep idle tunnels open), `-o ExitOnForwardFailure=yes` (fail fast instead of hanging if the bind port is taken).

## Detection and defence
- Long-lived outbound SSH from server segments to internet IPs — Zeek `ssh.log` plus a duration threshold.
- `sshd` logs the forwarded ports (`forwarding from`, `direct-tcpip`) at `LogLevel VERBOSE` — enable on bastions and ship to SIEM.
- Disable `AllowTcpForwarding`, `PermitTunnel`, `AllowAgentForwarding`, and `GatewayPorts` on hosts that don't legitimately need them.
- Require certificate-based SSH (CA-signed user certs) so revocation is centralised; deny password auth.
- Enforce egress so server VLANs can only reach approved SSH bastions.

## References
- [OpenSSH manpage](https://man.openbsd.org/ssh) — authoritative `-L`/`-R`/`-D`/`-J` semantics.
- [HackTricks — tunneling and port forwarding](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/tunneling-and-port-forwarding.html) — directional cheat sheet and proxychains pattern.
- [ired.team — SSH port forwarding](https://www.ired.team/offensive-security/lateral-movement/port-forwarding-and-tunneling) — operator-perspective examples including `-w` layer-3 tunnels.
