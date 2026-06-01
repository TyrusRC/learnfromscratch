---
title: Port scanning
slug: port-scanning
---

> **TL;DR:** Two-stage workflow — fast wide sweep with masscan/rustscan, deep service/version scripts with nmap on the hits. Tune timing to avoid IDS/IPS dropping you mid-engagement.

## What it is
Port scanning identifies reachable TCP/UDP services on target hosts. The TCP three-way handshake leaks state via SYN/ACK vs RST; the standard primitives are SYN (`-sS`, half-open), connect (`-sT`, full handshake — needed when raw sockets are unavailable), ACK (`-sA`, firewall ruleset mapping), and UDP (`-sU`, slow because there is no positive ack — only ICMP unreachable infers closed). Version probes (`-sV`) and NSE scripts then turn open ports into actionable banners and known-CVE candidates.

## Preconditions / where it applies
- Layer-3 reachability — direct, via a SOCKS proxy ([[chisel]], [[ligolo-ng]]), or via [[ssh-tunneling]].
- Root/CAP_NET_RAW for SYN scan; otherwise connect scan from unprivileged context.
- Time budget — `/24` deep scan is minutes; `/16` full TCP+UDP is hours without parallelism.
- Related: [[host-discovery]], [[exposed-services]], [[known-cve-triage]].

## Technique
Stage 1 — wide and fast. masscan rips through internet-scale ranges at packet rates limited only by NIC and upstream:

```bash
sudo masscan -p1-65535 --rate 10000 -oL masscan.lst 10.10.0.0/16 --excludefile noscan.txt
```

rustscan is friendlier on internal /24s and pipes straight into nmap:

```bash
rustscan -a 10.10.10.0/24 --ulimit 5000 -- -sV -sC -oA nmap_deep
```

Stage 2 — deep on the hits. Feed only open ports into nmap to keep run times sane:

```bash
nmap -Pn -n -sS -sV -sC -p$(cut -d' ' -f4 masscan.lst | sort -u | paste -sd,) \
     -oA nmap_deep --reason --version-all -iL live_hosts.txt
```

UDP is slow but high-value (SNMP, NTP, DNS, IPMI, IKE, NetBIOS). Top-100 plus targeted ports:

```bash
sudo nmap -sU --top-ports 100 -sV -oA udp_top100 TARGET
sudo nmap -sU -p 53,69,123,137,161,500,623 -sV -oA udp_targeted TARGET
```

Evasion / IDS-aware timing — drop to `-T2` or `-T1`, fragment (`-f`), randomise host order (`--randomize-hosts`), decoy (`-D RND:5,ME`), source-port spoof (`--source-port 53`) where stateless ACLs trust 53/UDP and 88/TCP as common return ports. Behind a proxy use `proxychains4 -q nmap -sT -Pn ...` — only connect scan works through SOCKS.

Version-probe deeper with `--version-intensity 9` when fingerprint is ambiguous, but it is loud. NSE categories worth running on enterprise networks: `default,safe,discovery,vuln` (avoid `intrusive` on production without sign-off).

For IPv6 add `-6`; nmap supports SYN/UDP/script over v6 against listed targets (no broadcast discovery).

## Detection and defence
- IDS/IPS signatures fire on SYN-without-ACK floods, ordered port sweeps, and tool-specific user-agents (`Mozilla/5.0 (compatible; Nmap Scripting Engine)`). Zeek `scan.log` captures aggregated scan behaviour.
- Defences: stateful firewalls dropping unsolicited inbound, port-knock or single-packet-auth for admin services, microsegmentation so a compromised host cannot enumerate peers, rate limits on TCP-RST per source.
- Honeypots/canaries on commonly-scanned ports (Thinkst Canary) catch the scanner before it reaches the real estate.

## References
- [Nmap — Port Scanning Techniques](https://nmap.org/book/man-port-scanning-techniques.html) — canonical reference for `-sS/-sT/-sA/-sU`.
- [masscan README](https://github.com/robertdavidgraham/masscan) — rates, exclude files, banner mode.
- [HackTricks — Pentesting Network](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/pentesting-network/index.html) — recipes that combine scanning with downstream enumeration.
