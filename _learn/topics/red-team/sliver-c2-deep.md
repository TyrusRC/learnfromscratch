---
title: Sliver C2 — operator's view
slug: sliver-c2-deep
aliases: [sliver-deep, sliver-c2-tradecraft]
---

> **TL;DR:** Sliver is BishopFox's open-source C2 framework written in Go, designed as a modern Cobalt Strike alternative. Cross-platform (Windows / Linux / macOS), supports mTLS / WireGuard / DNS / HTTPS transports, generates implants per-engagement (no shared static signatures), and is widely used by both red teams and threat actors. Companion to [[c2-frameworks]] and [[havoc-c2-deep]].

## Why Sliver

- **Open source**, MIT licensed — auditable, free.
- **Cross-platform implant** — works against macOS and Linux, not just Windows.
- **Per-engagement implants** — staticly compiled with embedded keys; no shared signatures across operations.
- **Multiple transport protocols** — mTLS, HTTP(S), DNS, WireGuard.
- **In-process Go** implant — less reliance on .NET / PowerShell that's heavily monitored.
- **Modern crypto** — Curve25519 for key exchange, AES-GCM for messages, no legacy.

## Architecture

- **Server** — Go binary; listens for operator client connections (gRPC + mTLS) and implant connections (configurable transports).
- **Client** — Go binary; operator CLI / GUI.
- **Implant** — Go binary per-target; embeds operator's public key + implant ID + transport config.
- **Listener** — server module accepting implant connections on a specific transport.

Operator runs `sliver-server`, then `sliver-client` connects locally. Generate an implant with `generate`, deploy by your chosen method.

## Implant features

- **Process injection** — spawn-and-inject into a target process.
- **In-memory loading** — execute .NET assemblies (DLL host), shellcode, PE files in-memory.
- **File operations** — upload / download / `ls` / `cat`.
- **Shell** — `shell` for interactive prompt; `execute` for one-shot commands.
- **Pivot** — relay implants for internal pivoting.
- **BOF support** — execute Cobalt Strike Beacon Object Files (compatible subset).
- **Migrate** — move implant from one process to another.
- **Tasks queue** — async work with status tracking.

## Transports

- **mTLS** — operator's CA issues cert per implant; mutual auth.
- **HTTPS** — implant POSTs to operator-chosen URI; supports custom HTTP profile.
- **DNS** — encoded payload in DNS queries / responses.
- **WireGuard** — full WG tunnel between implant and operator (rare; high-OPSEC environments).

For OPSEC, HTTPS is the typical choice — looks like normal web traffic; can be Cloudflare / domain-fronted ([[domain-fronting-and-cdn-abuse]]).

## Profile tuning (HTTP)

Sliver supports custom HTTP profiles to mimic legitimate traffic:
- Path / parameter naming.
- Header set and order.
- Sleep / jitter.
- Maximum dataset chunking.

Tune to match the target environment's normal traffic — random `/api/v3/whatever` won't blend with corporate finance traffic; mimic that traffic's profile.

## Pivoting

Sliver supports two pivot models:
- **TCP pivot** — a parent implant accepts connections from child implants on an internal IP.
- **Named-pipe pivot** (Windows) — child implants connect through a named pipe to the parent.

Useful for reaching internal hosts that can't egress directly.

## Cross-platform considerations

### Windows

- Implant runs as a benign Go binary.
- Direct syscalls supported via syscallx package — see [[syscall-direct-and-indirect]].
- BOF compatibility allows reuse of much Cobalt Strike tooling.

### macOS

- Implant is a Mach-O binary; codesigning required for some persistence vectors.
- Sandbox-aware execution (see [[macos-sandbox-escape]]).
- TCC interactions limited by default ([[macos-tcc]]).

### Linux

- Implant is an ELF binary.
- Capability awareness ([[linux-capabilities]]).
- Container-aware execution.

Each platform has its own OPSEC profile; the same implant binary won't blend equally well.

## EDR interactions

Common detection patterns:
- **Go binary entropy** — Go binaries have characteristic signatures.
- **Sliver-specific strings** — older builds had detectable strings; modern builds are stripped.
- **HTTP profile** — default profile pattern.
- **DNS C2 traffic** — long-domain queries, high frequency.

EDR vendor coverage of Sliver is now substantial (CrowdStrike, SentinelOne, Defender). Operators tune profiles, obfuscate Go binaries (garble, gobfuscate), and rotate transports.

## Threat actor adoption

- Multiple ransomware crews observed using Sliver in 2023–2025.
- Public IR reports often identify Sliver C2 by network signatures.
- The same operational hygiene that makes it good for red teams makes it attractive to criminals.

## Operational notes for red team

- **Per-engagement server, per-engagement implants** — no shared infrastructure across clients.
- **Sleep / jitter** appropriate for engagement length.
- **Cleanup** — remove implants and persistence post-engagement; don't leave dormant implants.
- **Document** every implant deployed with file path + persistence mechanism for IR handoff.

## Workflow to study

1. Install Sliver server on a VPS.
2. Generate an HTTPS implant.
3. Deploy to a benign test Windows VM.
4. Test core commands: shell, file ops, screenshot, persistence.
5. Configure custom HTTP profile.
6. Test detection from defender side with Defender / Sysmon.
7. Test BOF compatibility with a known Beacon BOF.

## Related

- [[c2-frameworks]] — generic C2 concepts.
- [[havoc-c2-deep]] — alternative framework.
- [[mythic-framework-deep]] — Mythic.
- [[syscall-direct-and-indirect]] — implant evasion.
- [[domain-fronting-and-cdn-abuse]] — infrastructure.
- [[edr-hooks-and-unhooking]] — evasion.

## References
- [Sliver project](https://github.com/BishopFox/sliver)
- [Sliver documentation](https://sliver.sh/)
- [BishopFox blog](https://bishopfox.com/blog)
- See also: [[c2-frameworks]], [[havoc-c2-deep]], [[mythic-framework-deep]], [[c2-protocol-design]]
