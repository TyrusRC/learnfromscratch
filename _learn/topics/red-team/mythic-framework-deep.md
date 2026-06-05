---
title: Mythic C2 — operator's view
slug: mythic-framework-deep
aliases: [mythic-deep, mythic-c2-framework]
---

> **TL;DR:** Mythic (by Cody Thomas, formerly at SpecterOps) is a containerised, modular C2 framework where the framework itself is transport-agnostic — every transport, payload, and feature ships as a docker container. Operators pick and mix: Apollo (.NET Windows), Apfell (Python/JXA macOS), Poseidon (Go cross-platform), Athena (.NET cross-platform), Medusa (Python multi-OS), and many more. The most flexible framework for non-Windows targets and unusual transports. Companion to [[c2-frameworks]] and [[sliver-c2-deep]].

## Why Mythic

- **Modular by design** — each agent and transport is a separate docker container. Mix and match.
- **Strong macOS support** — Apfell (JavaScript-for-Automation), Poseidon (Go), Athena (.NET) all run macOS.
- **Cross-platform Linux** — Poseidon, Medusa.
- **Custom protocol support** — easy to write a new C2 profile (HTTP / DNS / Slack / Discord / IMAP / WebSockets).
- **Web-based UI** — Mythic UI is React, accessible from anywhere.
- **Active community** — popular agents include callback profiles for many obscure transports.

## Architecture

- **Mythic server** — docker-compose stack (Postgres, Mythic API, Mythic React UI).
- **Agents** — one container per agent type; talk to Mythic via gRPC.
- **C2 profiles** — one container per profile (HTTP, HTTPS, DNS, websocket, etc.).
- **Translation containers** — implement payload <-> Mythic message translation.

Operator interacts via web UI or `mythic-cli`.

## Agents (selection)

- **Apollo** — .NET Windows agent; mature, BOF-compatible.
- **Apfell** — macOS JXA agent; minimal footprint, useful for macOS-specific operations.
- **Poseidon** — Go agent for Windows / Linux / macOS; well-balanced.
- **Athena** — .NET cross-platform (Windows / Linux / macOS via .NET Core).
- **Medusa** — Python agent.
- **Service Wrapper / leviathan** — embedded / specialised.

Each agent has its own feature set; check the agent's docs.

## C2 profiles (selection)

- **HTTP / HTTPS** — standard, profile-customisable.
- **DNS** — slow but useful for highly restricted egress.
- **Slack / Discord / Teams** — C2 over collaboration tools.
- **IMAP** — C2 via email (operator polls inbox).
- **Websocket** — long-lived bidirectional.

The Slack / Discord profiles in particular are useful for testing detection of C2-via-SaaS — many environments don't inspect Slack traffic.

## Operational flow

1. Spin up Mythic server (docker-compose up).
2. Install agent container (e.g., Apollo).
3. Install profile container (e.g., HTTP).
4. Generate payload from web UI (pick agent + profile + parameters).
5. Deploy payload to target.
6. Operate from web UI.

## Strengths

- **Modular** — adopt only the agents and profiles you need.
- **Easy to write new agents / profiles** — the gRPC interface is documented.
- **macOS coverage** stronger than Sliver and Havoc.
- **C2-via-SaaS profiles** useful for testing modern detection.

## Weaknesses

- **More moving parts** — more containers to keep healthy.
- **Less BOF-compat than Cobalt Strike** — each agent decides what BOF support to offer.
- **Less default OPSEC** — Apollo / Apfell defaults can be detected; tune per engagement.

## OPSEC considerations

- **Container traffic** — Mythic containers talk to each other on a docker network; if running on a VPS, ensure the docker network isn't externally reachable.
- **Web UI access** — restrict to operator VPN / WireGuard.
- **Per-engagement keys** — rotate AES keys per payload; don't share across operations.
- **Payload signing** — sign your Apollo / Athena DLLs with a per-engagement certificate.

## Threat-actor adoption

Less adopted by criminal actors than Sliver or Havoc — Mythic's complexity and modularity favour red teams over crime crews. Reports of state-actor use exist; rare in public IR.

## Comparing to Sliver / Havoc

| Property | Sliver | Havoc | Mythic |
|----------|--------|-------|--------|
| Setup complexity | Low | Mid | High |
| Cross-platform | Yes | Limited | Yes (best) |
| Customisation | Mid | High | Highest |
| BOF support | Subset | Yes | Per-agent |
| Default OPSEC | Mid | Strong | Per-agent |
| C2 via SaaS | Limited | Limited | Strong (multiple profiles) |

For a macOS-heavy engagement, Mythic + Apfell or Poseidon is usually the right choice.

## Workflow to study

1. Spin up Mythic via docker-compose on a Linux VPS.
2. Install Apollo (Windows .NET) and HTTP profile.
3. Generate a payload; deploy to Windows test VM.
4. Test basic functionality.
5. Install Apfell + HTTPS profile; deploy to macOS VM.
6. Compare callbacks and capabilities.
7. Try a C2-via-Slack profile to understand the operator UX.

## Related

- [[c2-frameworks]] — generic.
- [[sliver-c2-deep]] — alternative.
- [[havoc-c2-deep]] — alternative.
- [[c2-protocol-design]] — building your own.
- [[domain-fronting-and-cdn-abuse]] — infrastructure.

## References
- [Mythic project](https://github.com/its-a-feature/Mythic)
- [Mythic documentation](https://docs.mythic-c2.net/)
- [Cody Thomas — SpecterOps blog](https://posts.specterops.io/)
- See also: [[c2-frameworks]], [[sliver-c2-deep]], [[havoc-c2-deep]], [[macos-security]]
