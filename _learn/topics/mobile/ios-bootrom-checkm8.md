---
title: iOS BootROM exploitation (checkm8 / checkra1n)
slug: ios-bootrom-checkm8
aliases: [checkm8, checkra1n, ios-bootrom-attacks]
---

> **TL;DR:** `checkm8` (2019, axi0mX) is a use-after-free in the SecureROM (BootROM) on Apple A5 through A11 SoCs — iPhone 4S through iPhone X. Because BootROM is read-only and unpatchable in silicon, every affected device is permanently exploitable for tethered jailbreak. checkra1n is the public jailbreak built on it. The class is a teaching gem for hardware-rooted exploitation; modern devices (A12+) added BootROM mitigations preventing the specific bug, but the lesson — that immutable code is a fragile assurance — remains. Companion to [[bootloader-and-secure-boot-attacks]] and [[ios-baseband-attacks]].

## Why this matters

- **First public BootROM exploit** of modern iOS in years.
- **Unpatchable** — silicon is silicon; affected devices stay exploitable forever.
- Enabled a generation of researcher access to iOS internals.
- Showed the limits of "secure boot rooted in immutable ROM" as a security argument.

## The vulnerability

DFU (Device Firmware Update) mode on iPhone exposes the SecureROM stack to USB commands. checkm8 exploits a use-after-free in USB IRecv / DFU stack:

1. The DFU stack allocates a structure for an incoming USB transfer.
2. Specific commands cause the structure to be freed but a pointer remains.
3. A subsequent operation uses the dangling pointer.
4. Attacker controls the contents at that memory location.
5. The dangling pointer reads attacker-controlled data; results in code execution in SecureROM context.

Because SecureROM has full system privilege at that boot stage, code execution lets you:
- Bypass the iBoot signature check.
- Boot a custom iBoot / kernel.
- Tether the device into a jailbroken state.

Reboot returns to normal state (tethered jailbreak: must re-exploit every boot).

## Affected SoCs

- **A5** (iPhone 4S, iPad 2/3).
- **A6** (iPhone 5).
- **A7** (iPhone 5S).
- **A8** (iPhone 6).
- **A9** (iPhone 6s).
- **A10** (iPhone 7).
- **A11** (iPhone 8 / X).

A12+ (iPhone Xs and newer) are not affected.

## What it enables

For researchers:
- **Filesystem dump** of a sealed iOS device.
- **Kernel debugging** via SecureROM-installed handlers.
- **TFP0** (Task For Pid 0 = kernel task access) → kernel R/W.
- **AMFI bypass** for installing unsigned binaries.
- **SEP analysis** — Secure Enclave processor is a separate die; checkm8 doesn't compromise it, but it enables more research access.

For users / criminals:
- **Tethered jailbreak** — every boot needs re-exploit.
- **Activation-lock bypass** — controversial, used by phone-resellers; Apple has pushed back.
- **Forensic access to physically-acquired devices** — GrayKey, Cellebrite incorporate.

## Mitigations on A12+

Apple added BootROM-level mitigations specifically targeting this class:
- DFU USB stack hardened.
- Additional state checks before transfer-buffer access.
- Smaller SecureROM footprint for fewer bugs.

No public BootROM exploit on A12+ has been disclosed.

## The "unpatchable forever" lesson

BootROM is silicon. Apple cannot patch it post-tape-out. Affected devices stay exploitable indefinitely. The mitigation is to **buy newer hardware** — an unsatisfying answer for the install-base.

For security architects: hardware mitigations are *layered defence*; relying on a single unpatchable root for chain-of-trust is a known fragility class.

## checkra1n — the jailbreak

checkra1n (2019+) is the production-quality jailbreak built on checkm8:
- Linux / macOS GUI + CLI.
- Tethered jailbreak; semi-untethered when paired with a payload that persists user-space changes.
- Supports installing Cydia / Sileo / Zebra package managers.

By 2025 checkra1n is largely superseded by **palera1n** for newer iOS versions on A11-and-below devices.

## Workflow to study

1. Acquire a checkm8-vulnerable iPhone (used iPhone X is ~$100–200; iPhone 7 cheaper).
2. Run **palera1n** or **checkra1n** to jailbreak.
3. SSH into device; explore the filesystem.
4. Set up **lldb-via-debugserver** for kernel debugging.
5. Read public iOS internals books / blogs (Levin's *MacOS and iOS Internals* series; Levitan).
6. Study iOS kernelcache, dyld_shared_cache.

This setup enables much of the rest of iOS research and is the standard starting investment for iOS exploit-dev study.

## Research enabled by checkm8

The bug indirectly enabled:
- **Comprehensive iOS kernel research** by Project Zero and others.
- **Public iOS internals education** — books, conference talks.
- **Forensic tools** for law-enforcement (controversial).
- **Older-iPhone preservation** — running modern security research on devices Apple has stopped patching.

## Defensive baseline (for high-risk users)

- Don't use iPhone X or older for high-risk work.
- Apple stopped iOS major-version updates for iPhone X / 8 series; security-only updates for some time, eventually nothing.
- Lockdown Mode unavailable on these devices.

## Related

- [[bootloader-and-secure-boot-attacks]] — generic class.
- [[ios-baseband-attacks]] — adjacent.
- [[ios-source-review-methodology]] — what you can do with jailbroken iOS.
- [[pac-arm64e-bypass]] — adjacent for A12+ research.
- [[ios-keychain-and-secure-enclave-audit]].

## References
- [axi0mX — checkm8 release](https://twitter.com/axi0mX/status/1177542201670168576)
- [checkra1n](https://checkra.in/)
- [palera1n](https://palera.in/)
- [Jonathan Levin — *MacOS and iOS Internals*](https://newosxbook.com/)
- [Project Zero — iOS research on checkm8-enabled devices](https://googleprojectzero.blogspot.com/)
- See also: [[bootloader-and-secure-boot-attacks]], [[ios-baseband-attacks]], [[ios-source-review-methodology]], [[pac-arm64e-bypass]]
