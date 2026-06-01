---
title: AWD traffic analysis
slug: awd-traffic-analysis
---

> **TL;DR:** Capture every inbound packet, watch for unfamiliar payloads, and replay rivals' exploits across the whole field before they patch — the cheapest source of new exploits in an A/D event.

## What it is
Other teams are attacking you with their best exploits. Their payloads land on your box in cleartext (or TLS you terminate). Recording and mining that traffic lets you copy a working exploit, re-target it at every other team, and submit their flags — often before the originating team even realises they have leaked their attack. See [[awd-overview]] and [[awd-flag-strategy]].

## Preconditions / where it applies
- You control the host or a span port on the game network
- Game traffic crosses a known interface (often a VPN tunnel like `tun0` or `game0`)
- Services are HTTP, TCP text protocols, or something where you can decrypt — purely binary protocols with crypto are harder but rarely used in A/D

## Technique
1. **Rotating capture** from minute zero, stored off-box if possible:

   ```bash
   tcpdump -i game0 -G 60 -w 'cap-%Y%m%d-%H%M.pcap' \
           -Z root 'tcp and not port 22'
   ```
2. **Live grep for the flag regex.** A flag in an HTTP response means someone already exploited you successfully — trace the request that triggered it:

   ```bash
   tcpdump -i game0 -A -s0 -l 'tcp' | grep --line-buffered -E 'FLAG\{[A-Za-z0-9_]{30}\}' &
   ```
3. **Per-service splitters.** `tcpflow -r cap.pcap -o flows/` reconstructs streams; then `grep -RIl` for known payload markers (e.g. `__import__`, `<?php`, suspicious `User-Agent`).
4. **Replay harness.** Once a captured request reads a flag, parameterise the target host and loop across the team list:

   ```python
   for ip in teams:
       req = captured.replace(b'Host: 10.60.7.1', f'Host: {ip}'.encode())
       s = socket.create_connection((ip, 8080)); s.sendall(req)
       print(s.recv(65536))
   ```
5. **Diff-based exploit discovery.** Sort flows by uniqueness — a request type you've never seen, hitting only the vulnerable endpoint, is probably an exploit. Tools like `ngrep`, `mitmproxy`, and `zeek` accelerate this.

Keep replayed exploits in your harness with the rest of your in-house ones — see [[awd-preparation]].

## Detection and defence
- Assume rivals are doing the same to you — encrypt payloads or randomise markers to make replay harder, but only if it does not break the checker
- A sudden spike in identical-shape requests across all teams' IPs to your box is a sign someone has replayed your exploit against the field — rotate that bug's patch fast
- Logging at the application layer (Suricata, mod_security) is easier to search than raw pcap once the game is over

## References
- [Wireshark display filters](https://wiki.wireshark.org/DisplayFilters) — fast pcap triage
- [tcpflow](https://github.com/simsong/tcpflow) — per-stream reconstruction for grep-friendly analysis
- [Zeek](https://zeek.org/) — structured logs from raw traffic for protocol-aware mining
- [HackTricks pcap inspection](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/pentesting-network/pcap-inspection/index.html) — general triage patterns
