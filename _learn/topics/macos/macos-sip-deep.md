---
title: macOS SIP — deep dive
slug: macos-sip-deep
aliases: [sip-deep, system-integrity-protection-deep]
---

> **TL;DR:** System Integrity Protection (SIP, also known as "rootless") is a kernel-enforced mandatory access control layer that prevents even `root` from modifying protected system files, attaching debuggers to platform binaries, or loading unsigned kernel code. Since Big Sur it is reinforced by the Sealed System Volume (SSV), and the SIP-bypass research scene has steadily shifted from filesystem tricks to abusing privileged Apple-signed helpers (e.g. Migraine, CVE-2023-32369). Companion to [[sip]], [[sip-bypasses]], and [[macos-architecture]].

## Why it matters

SIP is the bedrock assumption behind almost every other macOS defense: [[gatekeeper-and-notarisation]], [[entitlements-and-codesigning]], [[macos-tcc]], and the platform-binary trust model all assume that an attacker who lands code as `root` still cannot rewrite `/System`, replace `launchd`, disable `tccd`, or inject into Apple-signed processes. If SIP falls, the security model collapses to "root == game over," which is precisely the pre-El-Capitan world Apple was trying to leave behind.

For offensive researchers, SIP gates the difference between a noisy post-exploitation foothold and true persistence/stealth. For defenders and incident responders ([[macos-unified-logs-forensics]], [[macos-forensics-fsevents-spotlight]]), knowing what SIP does and does not protect tells you which artefacts an attacker could plausibly tamper with.

## Classes, patterns, and process

### What SIP actually enforces

SIP is implemented primarily in the kernel via the `AppleMobileFileIntegrity` (AMFI) kext, the `Sandbox` kext, and the `rootless` policy module. It enforces three broad categories:

1. **Filesystem protection** — files and directories tagged with the `com.apple.rootless` extended attribute or listed in `/System/Library/Sandbox/rootless.conf` are read-only even to `root`. This covers `/System`, `/bin`, `/sbin`, `/usr` (except `/usr/local`), and parts of `/Applications` shipped with the OS.
2. **Runtime protection** — `task_for_pid()` and `ptrace(PT_ATTACH)` against Apple-signed platform binaries are blocked, preventing dylib injection and debugger attach. This is why you cannot `lldb` Safari without disabling SIP.
3. **Kernel extension protection** — only kexts signed with a special Apple-issued certificate (and increasingly only those in the `AuxKC` cache or system kext allowlist) can load. Combined with the broader push to [[iokit-attack-surface]] DriverKit, this is squeezing legacy kexts out of the trust boundary.

### Restricted directories and flags

The `ls -lO` output (capital O) reveals SIP flags. The interesting ones:

- `restricted` — the file is SIP-protected; the kernel will refuse writes regardless of UID.
- `sunlnk` — the file cannot be unlinked.
- `schg` / `uchg` — system/user immutable flags (older BSD heritage, predates SIP but still respected).

The authoritative manifest of protected paths is `/System/Library/Sandbox/rootless.conf`, which uses a small DSL with `*` exceptions for things like `/usr/local`, `/Library/Apple/*`, and certain caches that need to be writeable for software updates.

### csrutil and the NVRAM bit

`csrutil` is the userland interface to SIP, but the actual on/off state lives in NVRAM as `csr-active-config`, a bitmask. Individual bits control individual protections:

- `CSR_ALLOW_UNTRUSTED_KEXTS` (0x1)
- `CSR_ALLOW_UNRESTRICTED_FS` (0x2)
- `CSR_ALLOW_TASK_FOR_PID` (0x4)
- `CSR_ALLOW_KERNEL_DEBUGGER` (0x8)
- `CSR_ALLOW_APPLE_INTERNAL` (0x10)
- `CSR_ALLOW_UNRESTRICTED_DTRACE` (0x20)
- `CSR_ALLOW_UNRESTRICTED_NVRAM` (0x40)
- `CSR_ALLOW_DEVICE_CONFIGURATION` (0x80)
- `CSR_ALLOW_ANY_RECOVERY_OS` (0x100)
- `CSR_ALLOW_UNAPPROVED_KEXTS` (0x200)

Setting this requires booting into recoveryOS (`Cmd-R` on Intel, hold power on Apple Silicon) and running `csrutil disable` or `csrutil enable --without <category>`. On Apple Silicon, partial disablement is bound to a per-boot policy stored in LocalPolicy, which itself is signed by the Secure Enclave — this is why "Reduced Security" is a meaningful concept on M-series Macs and a hard prerequisite for kext loading.

### Sealed System Volume (SSV)

Since Big Sur (11.0), the system volume is cryptographically sealed. The system partition is mounted read-only and every file has a SHA-256 hash that rolls up into a Merkle tree, whose root hash is signed by Apple. At boot, the kernel verifies the seal; any modification — even ones that would have been blocked by SIP at runtime anyway — breaks the seal and the system refuses to boot normally.

This means SIP is no longer "just" a runtime MAC policy: it is anchored in a cryptographic snapshot. To modify the system volume legitimately you must `mount -uw` (which on Apple Silicon requires reduced security and breaking the seal), make changes, and rebuild the seal — which only Apple can do for the canonical snapshot.

### How legitimate updates bypass SIP

Software Update obviously needs to write to `/System`. It does so via Apple-signed helpers with the entitlement `com.apple.rootless.install` (or `.heritable`), which is honoured by the kernel as an exception. `systemmigrationd`, `installd`, and the `softwareupdated` chain are the canonical holders. The entitlement is the entire attack surface: if a non-Apple binary somehow inherits or is launched by one of these, it gets to write under `/System`.

This is the design that the SIP-bypass research community has spent the last decade poking at.

### How SIP-bypass research evolves

The early years (2015-2018) were dominated by **filesystem confusion**: symlinks, race conditions in `rootless.conf` exceptions, and abuse of `/Library` paths that were on the exception list. Patrick Wardle, Pedro Vilaça, and Csaba Fitzl mined that vein heavily.

The middle era (2018-2021) shifted to **entitled-helper abuse**: find an Apple binary with `com.apple.rootless.install`, find a way to make it open or extract a file under your control into a SIP-protected location. `system_installd`, `fsck_cs`, and a string of installer plugins were repeated victims.

The current era (2022-) focuses on **logic flaws in update plumbing and migration assistants**, plus exotic gadgets like XPC services that proxy filesystem operations. Migraine (CVE-2023-32369) is the canonical recent example: Microsoft researchers found that the `systemmigrationd` daemon, which holds `com.apple.rootless.install.heritable`, would execute arbitrary scripts during migration without sufficiently validating their origin — letting an attacker drop a payload that inherited SIP-bypass entitlements.

Other recent ones worth knowing:

- **Shrootless (CVE-2021-30892)** — Microsoft again, abusing `system_installd`'s handling of post-install scripts in package payloads.
- **CVE-2022-32826** — Mickey Jin's chain abusing the `softwareupdated` install pipeline.
- **CVE-2023-32369 (Migraine)** — `systemmigrationd` script execution.
- **CVE-2024-44243** — abuse of the kernel's third-party kext storage allowing SIP bypass via the kext staging area.

The pattern is consistent: find an entitled helper, find an input it accepts, find a way to make it act on attacker-controlled data.

### Kexts, system extensions, and DriverKit

SIP's third leg — kext signing — has been progressively tightened. On Apple Silicon, third-party kexts require reduced security mode and explicit user approval per-kext. Apple's stated direction is that all third-party kernel code moves to either System Extensions (user-space daemons with kernel-mediated APIs) or DriverKit (a restricted IOKit-in-userspace runtime). See [[macos-architecture]] and [[iokit-attack-surface]] for the broader shift.

For attackers this means: planting a malicious kext is no longer a realistic persistence mechanism on modern Macs. For defenders, it means kext-based EDR is dying and your detection has to move up to ES (Endpoint Security) framework consumers.

## Defensive baseline

- **Never disable SIP on production endpoints.** Mark `csrutil status` as a required compliance check; alert on `Disabled` or any non-default `csr-active-config`.
- **Monitor `com.apple.rootless` entitlement holders.** Maintain an allowlist; investigate any unsigned or third-party binary that somehow holds it.
- **Watch SSV seal state.** `csrutil authenticated-root status` should always say `enabled`. A broken seal on a production machine is a strong tampering signal.
- **Track Apple security updates aggressively** — SIP bypasses are routinely patched silently or with vague notes. Diff `rootless.conf` and the entitlement manifests across point releases (see [[one-day-from-patch-diff]]).
- **In IR, do not trust system binaries on a SIP-disabled host.** Treat them as potentially modified; pull from a known-good image. See [[ir-from-source-signals]].

## Workflow to study SIP

1. Stand up a dedicated VM or spare Mac per [[building-a-research-home-lab]] guidance. Apple Silicon VMs in UTM/Parallels are sufficient for userland SIP study.
2. Read `man csrutil`, then enumerate `csr-active-config` semantics from the open-source `xnu` headers (`bsd/sys/csr.h`).
3. Dump `/System/Library/Sandbox/rootless.conf` and walk every exception path — understand what is and is not protected.
4. Enumerate entitled helpers: `find / -perm -4000 -o -type f -name '*' 2>/dev/null | xargs -I{} codesign -d --entitlements - {} 2>/dev/null | grep -l rootless`.
5. Read the writeups for Shrootless, Migraine, and CVE-2024-44243 back-to-back; the pattern repetition is the point.
6. Practice patch-diffing a SIP-relevant CVE per [[one-day-from-patch-diff]] — diff the affected daemon binary across the patched and unpatched OS versions.
7. Pair this with [[macos-kernel-debugging]] on a SIP-disabled research VM to observe AMFI and sandbox decisions in action.

## Related

- [[sip]]
- [[sip-bypasses]]
- [[macos-architecture]]
- [[macos-tcc]]
- [[macos-sandbox-escape]]
- [[macos-privesc]]
- [[gatekeeper-and-notarisation]]
- [[gatekeeper-bypasses]]
- [[entitlements-and-codesigning]]
- [[macos-userland-mitigations]]
- [[macos-kernel-debugging]]
- [[iokit-attack-surface]]
- [[apple-mitigations]]
- [[ios-vs-macos-divergence]]
- [[one-day-from-patch-diff]]

## References

- Apple Platform Security guide, "System Integrity Protection" — https://support.apple.com/guide/security/system-integrity-protection-secb7ea06b49/web
- Apple Platform Security guide, "Signed system volume security" — https://support.apple.com/guide/security/signed-system-volume-security-secd698747c9/web
- Microsoft Security Blog, "Migraine: SIP bypass via systemmigrationd (CVE-2023-32369)" — https://www.microsoft.com/en-us/security/blog/2023/05/30/new-macos-vulnerability-migraine-could-bypass-system-integrity-protection/
- Microsoft Security Blog, "Shrootless: SIP bypass in macOS (CVE-2021-30892)" — https://www.microsoft.com/en-us/security/blog/2021/10/28/microsoft-finds-new-macos-vulnerability-shrootless-that-could-bypass-system-integrity-protection/
- Csaba Fitzl, "macOS SIP bypass research index" — https://theevilbit.github.io/posts/
- Patrick Wardle, "The Art of Mac Malware" (SIP chapter) — https://taomm.org/
