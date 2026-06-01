---
title: AWD — Attack-with-Defence
slug: awd-overview
---

> **TL;DR:** Live CTF format where every team runs an identical vulnerable box, scores by stealing flags from rivals and losing points when their own box is popped — speed, automation and patching all matter.

## What it is
Attack-with-Defence (AWD), sometimes called Attack/Defense or A/D, is a real-time CTF where each team gets an identical VM (or container set) running buggy services. A scoring bot (the "checker" or "gamebot") periodically writes fresh flags into every team's services and polls them for liveness. You score by reading another team's current flag and submitting it; you lose points when someone reads yours, and you lose SLA points if your service goes down. Rounds typically last 60-300 seconds.

## Preconditions / where it applies
- Competition formats: DEF CON CTF finals, iCTF, FAUST CTF, RuCTF, ENOWARS, XCTF finals, DataCon AWD
- You receive root on your own box plus the source for every running service
- VPN connects all teams in a flat or routed range; teammate coordination over chat
- Identical software stack across teams — what works against one usually works against all

## Technique
The standard playbook runs four parallel workstreams from minute zero:

1. **Recon and triage.** `nmap -sV -p- <team-range>` to confirm services, then diff the provided sources against upstream versions to spot inserted bugs (`git init && git add . && git diff` against a clean baseline of the same framework works well).
2. **Exploit then weaponise.** Write a single-team exploit, then a wrapper that loops every team IP and pipes flags to the submitter:

   ```bash
   for ip in $(cat teams.txt); do
     python3 sploit.py "$ip" | tee -a flags.txt
   done
   ```
3. **Patch your own box.** Smallest possible patch that kills the bug without breaking the checker — see [[awd-patching]].
4. **Observe and steal.** Capture all inbound traffic with `tcpdump -w cap.pcap` so you can lift other teams' exploits and replay them — see [[awd-traffic-analysis]].

A flag is typically a regex like `FLAG\{[A-Za-z0-9_]{30}\}` or `[A-Z0-9]{31}=`. Submit via the gamebot's HTTP/TCP endpoint; rate-limit handling matters since most events cap submissions per round.

## Detection and defence
- Inspect `tcpdump`/Suricata captures to find which exploit hit you, then patch the underlying bug instead of just blocking the payload
- Run an integrity baseline (`sha256sum` tree, AIDE, or a tarball snapshot) so you can roll back if a rival drops a webshell — see [[awd-preparation]]
- Watch for backdoors: cron jobs, modified `/etc/passwd`, suid binaries, listener sockets (`ss -lntp`)
- Keep the checker green — a service that returns the right responses but no longer exploitable is the win condition

## References
- [FAUST CTF rules](https://2023.faustctf.net/information/rules/) — canonical A/D scoring model
- [ENOWARS gameserver](https://github.com/enowars/enochecker) — open-source checker framework explaining flag rotation
- [DEF CON CTF archives](https://archive.ooo/) — past A/D challenge sources and writeups
- [HackTricks methodology](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/pentesting-methodology.html) — general methodology that maps onto A/D recon
