---
title: RTOS shared bug classes
slug: rtos-shared-bug-classes
aliases: [rtos-bug-classes, embedded-bug-classes, urgent11]
---

> **TL;DR:** RTOS bug classes recur across implementations — FreeRTOS, Zephyr, ThreadX (Microsoft), VxWorks (Wind River), Nucleus (Mentor / Siemens), uC/OS, RIOT. The 2019 URGENT/11 disclosure of 11 VxWorks vulnerabilities and 2021 BadAlloc + 2020 Ripple20 + 2021 NAME:WRECK / NUMBER:JACK / INFRA:HALT campaigns spotlighted shared memory-corruption patterns in TCP/IP stacks. Companion to [[freertos-audit]] and [[zephyr-audit]].

## Why "shared classes"

Many RTOSes:
- Use similar C codebases.
- Implement similar TCP/IP stacks (some shared lineage).
- Share patterns from 1990s-2000s embedded development style.

The same bug class hits multiple RTOSes around the same time when researchers publish.

## Pattern 1 — TCP/IP stack memory corruption

The IPnet stack, IPnet sister stacks, and other vendor TCP/IP libraries:
- DNS response parsing buffer overflow.
- DHCP option-parsing.
- TCP option-parsing.
- IPv6 fragment reassembly.

Cluster disclosures:
- **URGENT/11** (2019, Armis) — 11 CVEs in IPnet, used by VxWorks, Nucleus, OSE, others.
- **Ripple20** (2020, JSOF) — 19 CVEs in Treck TCP/IP, used in many embedded products (Caterpillar, HP, Intel, others).
- **NAME:WRECK** (2021, Forescout) — DNS bugs in FreeBSD, NetX, IPnet, Nucleus.
- **NUMBER:JACK** (2021) — TCP initial sequence number weakness.
- **INFRA:HALT** (2021) — NicheStack TCP/IP, used in industrial controllers.
- **BadAlloc** (2021) — memory allocation issues across Zephyr, VxWorks, others.

The "X:Y" naming convention (Forescout, JSOF, Armis, Microsoft) is now standard for shared-RTOS vulnerability disclosures.

## Pattern 2 — Stack overflow in tasks

Embedded developers undersize task stacks. Trigger:
- Deeply recursive function (DNS resolution, JSON parser).
- Large local variables on stack.
- Combined with insufficient stack guard.

Crash; often exploitable for RCE.

## Pattern 3 — Heap manipulation

Many RTOSes have simple heap allocators:
- No allocation hardening.
- No metadata protection.
- Heap overflow → adjacent allocation corruption.

Exploitation similar to early-2000s glibc allocator.

## Pattern 4 — No ASLR

ASLR usually absent on RTOS:
- Fixed code addresses.
- Fixed heap base.

Predictable exploitation; once you have memory-corruption primitive, ROP / shellcode is reliable.

## Pattern 5 — No DEP / W^X

Code regions writable by misconfig. Vendor builds often skip W^X.

## Pattern 6 — Shared address space

No MMU separation by default. All tasks read/write each other:
- Compromised network parser reads crypto keys.
- Crypto key memory unprotected.

## Pattern 7 — Privilege model absence

No user/supervisor distinction. Any task can call any kernel function. Compromise = root.

Zephyr USERSPACE is a step up; many embedded products don't use it.

## Pattern 8 — Watchdog avoidance during malicious activity

Attackers know watchdog might fire. Bug-exploitation paths designed to complete before watchdog triggers — milliseconds.

## Pattern 9 — Firmware update without signature

OTA flows accept signed-but-not-verified images, or unsigned entirely.

## Pattern 10 — Default debug interfaces

UART debug, JTAG enabled in production. Physical access = read/write memory.

See [[uart-jtag-debug]].

## Pattern 11 — Hardcoded credentials

Telnet / SSH / vendor-protocol credentials hardcoded in firmware. binwalk + strings = harvest at scale.

## Pattern 12 — Random-number generator weakness

True RNG hardware not used, or used incorrectly. Cryptographic keys with low entropy.

Multiple disclosed cases of session keys / certificates with predictable RNG.

## Defensive baseline

- **Strong TCP/IP stack** — modern, audited, patched.
- **W^X enforcement** where supported.
- **ASLR** where supported.
- **MMU/MPU isolation** (USERSPACE).
- **Stack-overflow protection** (canaries).
- **Heap hardening**.
- **Signed firmware** with rollback support.
- **Disabled debug interfaces** in production.
- **Strong RNG** from hardware sources.
- **Watchdog** monitoring with anomaly alerting.

## Workflow to study

1. Read URGENT/11, Ripple20, NAME:WRECK papers.
2. Pull source for an open-source RTOS TCP/IP stack (Zephyr, FreeRTOS+TCP).
3. Look for the same bug patterns.
4. Fuzz with Boofuzz or AFL+QEMU.

## Real-world incidents

- **URGENT/11** (Armis 2019) — VxWorks fleet exposure to 11 CVEs.
- **Ripple20** (JSOF 2020) — affected hundreds of vendors.
- **NAME:WRECK / INFRA:HALT** — Forescout-disclosed, broad impact.
- **CallStranger** (2020) — UPnP-related embedded.

These shape modern embedded security thinking.

## Workflow to study

1. Pick one campaign (URGENT/11) and read end-to-end.
2. Reproduce in QEMU + vulnerable RTOS image.
3. Build detection rules (Snort / Suricata, ICS-aware).
4. Audit your own / sample firmware for similar patterns.

## Related

- [[freertos-audit]]
- [[zephyr-audit]]
- [[firmware-audit-methodology]]
- [[firmware-extraction]]
- [[firmware-emulation-firmadyne-qemu]]
- [[bootloader-and-secure-boot-attacks]]
- [[uart-jtag-debug]]
- [[ics-scada-protocols-attacks]]

## References
- [Armis URGENT/11](https://www.armis.com/research/urgent11/)
- [JSOF Ripple20](https://www.jsof-tech.com/ripple20/)
- [Forescout NAME:WRECK / INFRA:HALT](https://www.forescout.com/research-labs/)
- [Microsoft Defender for IoT — BadAlloc](https://www.microsoft.com/en-us/security/blog/2021/04/29/badalloc-memory-allocation-vulnerabilities-could-affect-wide-range-of-iot-and-ot-devices-in-industrial-medical-and-enterprise-networks/)
- See also: [[freertos-audit]], [[zephyr-audit]], [[firmware-audit-methodology]], [[bootloader-and-secure-boot-attacks]], [[ics-scada-protocols-attacks]]
