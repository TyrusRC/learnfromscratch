---
title: Traffic analysis (PCAP)
slug: traffic-analysis
---

> **TL;DR:** Wireshark display filters, `tshark` for scripting, **Follow Stream** for sessions, **Export Objects** for transferred files. Reconstruct exfil, C2, and exploit chains from packets.

## What it is
Traffic analysis works against a packet capture (`.pcap`, `.pcapng`) — usually from `tcpdump`, `dumpcap`, a SPAN port, or a CTF challenge. Goals: identify protocols, reconstruct application-layer payloads, extract transferred files, decode obfuscated C2, and recover credentials. Wireshark is the GUI; `tshark` / `tcpdump` script the same dissectors; `Zeek` produces high-signal logs over large captures.

## Preconditions / where it applies
- A PCAP file or live interface with traffic to inspect.
- For encrypted protocols: TLS pre-master secrets (`SSLKEYLOGFILE`) or session keys to decrypt.
- For volume captures, sufficient RAM — Wireshark loads the whole file; `tshark` and Zeek stream.

## Technique
Start with a protocol breakdown and conversations.

```bash
tshark -r cap.pcapng -q -z io,phs                    # protocol hierarchy
tshark -r cap.pcapng -q -z conv,tcp | head           # top TCP conversations
tshark -r cap.pcapng -Y 'http.request' \
       -T fields -e ip.src -e http.host -e http.request.uri
```

Key Wireshark filters every solver memorises:

```
http.request.method == "POST"
tls.handshake.extensions_server_name contains "evil"
dns.qry.name matches "(?i)\\.exfil\\."
tcp.stream eq 7
ftp-data or smb2 or kerberos
```

**Follow Stream** (`Analyze → Follow → TCP / HTTP / TLS`) reconstructs a session as one buffer — copy out base64 payloads, JSON, shell sessions. **Export Objects** (`File → Export Objects → HTTP / SMB / TFTP`) dumps every transferred file. For decrypted TLS, set the `SSLKEYLOGFILE` path in `Preferences → Protocols → TLS → (Pre)-Master-Secret log filename`.

High-value patterns:
- **Credentials** — HTTP Basic in `Authorization` headers, FTP `USER` / `PASS`, plaintext SMTP `AUTH PLAIN`, NTLMv2 challenge/response (extract with `NetNTLMv2-to-john`).
- **DNS exfil** — abnormally long subdomains, high query-per-second to one zone, TXT responses with base32 payloads.
- **C2 beacons** — periodic small POSTs with consistent jitter, JA3/JA3S TLS fingerprints matching known frameworks.
- **File carving from streams** — `tcpflow` reassembles TCP into per-flow files; `foremost` then carves embedded objects.

Zeek over a big capture produces `conn.log`, `http.log`, `dns.log`, `ssl.log`, `files.log` — much faster to grep than reopening Wireshark.

## Detection and defence
- TLS 1.3 + ECH defeats most passive SNI-based monitoring; rely on JA3/JA4 fingerprints and DNS resolution patterns.
- Egress filtering: block outbound DNS to anything but the corporate resolver; rate-limit per-domain QPS to throttle DNS exfil.
- Network IDS (Suricata + ET rules, Zeek + custom signatures) catches known C2 patterns; for novel C2, anomaly detection on beacon periodicity (e.g. `RITA`).

## References
- [Wireshark display filters](https://www.wireshark.org/docs/dfref/) — official filter reference
- [Zeek](https://zeek.org/) — protocol-aware traffic logger
- [Malware Traffic Analysis](https://www.malware-traffic-analysis.net/) — practice PCAPs with writeups
- [tcpflow](https://github.com/simsong/tcpflow) — per-flow TCP reassembly
- See also: [[memory-image-forensics]], [[disk-image-forensics]]
