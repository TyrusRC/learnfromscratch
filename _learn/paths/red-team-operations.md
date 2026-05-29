---
title: Red team operations
slug: red-team-operations
aliases: [red-team-ops, c2-and-evasion]
---

> The difference between "I can pop a shell" and "I can run a covert
> operation for a month against a target with EDR and a SOC". Most of
> red team is opsec discipline, not novel exploits.

## Prereqs

- Comfortable shell user across Windows and Linux.
- [[active-directory]] stage 2.
- Comfort writing C# / C / Nim / Rust for tradecraft tooling.

## Stage 1 — opsec and tradecraft mental model

- [[opsec-fundamentals]] — what your tools reveal, on disk and on wire.
- [[c2-protocol-design]] — HTTPS, DNS, malleable profiles.
- [[infrastructure-design]] — redirectors, domain fronting alternatives,
  CDN abuse, attribution hygiene.
- [[payload-staging]] — staged vs stageless, fork-and-run vs in-proc.

## Stage 2 — Windows evasion primitives

- [[amsi-bypass]] · [[etw-bypass]] · [[wldp-bypass]].
- [[dll-side-loading]] · [[com-hijacking]] ·
  [[parent-pid-spoofing]].
- [[process-injection-techniques]] — CreateRemoteThread, APC, early
  bird, mapping-section, thread hijacking, MockingJay.
- [[syscall-direct-and-indirect]] — Hell's Gate, Halo's Gate, Tartarus.
- [[edr-hooks-and-unhooking]].
- [[living-off-the-land]] — LOLBAS / LOLBins.

## Stage 3 — running an operation

- [[c2-frameworks]] — Cobalt Strike, Sliver, Mythic, Havoc, Brute Ratel.
- [[persistence-techniques-windows]] — registry, scheduled tasks, WMI
  subscriptions, COM hijacking, services.
- [[ad-persistence]] (see [[active-directory]] path).
- [[ad-recon-low-noise]] — opsec-aware enumeration patterns.
- [[purple-team-feedback-loop]] — using detections you trip as the
  training signal.

## References

- [ired.team](https://www.ired.team/) — canonical Windows tradecraft
  reference.
- [SpecterOps blog](https://posts.specterops.io/).
- [MalDev Academy / MalDev field
  manual](https://maldevacademy.com/).
- [Outflank blog](https://www.outflank.nl/blog/).
- [@modexpblog (Modexp)](https://modexp.wordpress.com/) for tradecraft
  primitives.
