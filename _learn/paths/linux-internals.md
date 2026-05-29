---
title: Linux internals & post-exploitation
slug: linux-internals
aliases: [linux-privesc-path, linux-exploit-dev]
---

> Linux looks simpler than Windows until you actually try to escalate on
> a hardened container host. The path covers the privilege model,
> classic privesc, kernel surface, and container escapes.

## Prereqs

- Solid Linux shell and process model.
- C and x86_64 assembly basics.

## Stage 1 — privilege model

- Users, groups, UIDs/GIDs, supplementary groups.
- [[linux-capabilities]] — what they replace and what they enable.
- [[setuid-setgid-sticky]] — semantics and pitfalls.
- [[suid-sgid-binaries]] — GTFOBins as a triage shortcut.
- [[namespaces-and-cgroups]] — the container-shaped lens on Linux.

## Stage 2 — post-exploitation and privesc

- [[linux-enumeration]] — `linpeas`, `linux-smart-enumeration`,
  manual triage.
- Classic vectors:
  - [[sudo-misconfig]] · [[cron-jobs]] ·
    [[path-hijacking]] · [[ld-preload-abuse]].
  - [[writable-passwd-shadow]] · [[nfs-no-root-squash]].
  - [[docker-socket-mounted]] / privileged containers.
- [[capabilities-privesc]] — what each capability gives you.
- [[kernel-exploits-linux]] — when and how to use a public CVE PoC.

## Stage 3 — kernel and container escape

- [[linux-kernel-architecture]] — syscalls, modules, eBPF surface.
- [[heap-exploitation-linux]] — glibc tcache, fastbin, unsorted bin.
- [[ret2libc]] · [[srop]] · [[ret2csu]].
- [[user-namespace-attacks]].
- [[container-escape-techniques]] — capabilities, CAP_SYS_ADMIN,
  release_agent, runc CVEs.
- Hardening blind spots — seccomp, AppArmor, SELinux differences and
  bypass categories.

## References

- [LiveOverflow's binary
  exploitation playlist](https://www.youtube.com/c/LiveOverflow).
- [HackTricks Linux
  privesc](https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html).
- [GTFOBins](https://gtfobins.github.io/) — bookmark it.
- [Container Security](https://containersecurity.tech/) (Liz Rice).
