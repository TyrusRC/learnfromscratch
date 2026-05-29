---
title: macOS security
slug: macos-security
aliases: [macos-pentesting, macos-control-bypasses]
---

> macOS has its own access control layers (TCC, SIP, App Sandbox,
> Gatekeeper, notarisation). This path is about understanding each one
> and the typical bug shapes that defeat it.

## Prereqs

- Comfort with Unix shells.
- Objective-C / Swift familiarity (you can read it, not necessarily
  write it).
- A macOS VM or test machine you can break.

## Stage 1 — fundamentals

- [[macos-architecture]] — XNU kernel, Mach + BSD layers.
- [[mach-and-xpc]] — message passing as the OS-level RPC.
- [[entitlements-and-codesigning]].
- [[macos-tcc]] — what the privacy database actually protects.
- [[sip]] — System Integrity Protection scope and limits.
- [[gatekeeper-and-notarisation]].

## Stage 2 — control bypasses

- [[tcc-bypasses]] — historical CVE patterns and detection.
- [[sip-bypasses]] — root-with-SIP vs root-without-SIP.
- [[macos-sandbox-escape]] — abusing IPC and entitlement inheritance.
- [[macos-privesc]] — auth services, helper tools, launchd misconfig.
- [[gatekeeper-bypasses]] — quarantine attribute, archive tricks.

## Stage 3 — exploit dev on Apple platforms

- [[macos-kernel-debugging]].
- [[iokit-attack-surface]].
- [[apple-mitigations]] — PAC, BTI, kernel hardening.
- [[ios-vs-macos-divergence]] — what crosses over.

## References

- [Patrick Wardle's Objective-See blog](https://objective-see.org/blog.html).
- [theevilbit's macOS posts](https://theevilbit.github.io/).
- [Wojciech Reguła's posts](https://wojciechregula.blog/).
- *The Art of Mac Malware* (Patrick Wardle).
