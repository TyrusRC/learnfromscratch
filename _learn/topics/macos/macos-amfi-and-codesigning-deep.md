---
title: macOS AMFI and code-signing deep
slug: macos-amfi-and-codesigning-deep
aliases: [amfi-deep, macos-codesign-deep]
---

> **TL;DR:** AppleMobileFileIntegrity (AMFI) is the kernel-side enforcer that turns Apple's code-signing promises into runtime reality on macOS. It is the missing piece that links userland tools like `codesign`, the App Store quarantine model, and entitlement checks into a single MAC framework policy. This note is the deep companion to [[entitlements-and-codesigning]] and [[gatekeeper-and-notarisation]], and explains why most modern macOS malware focuses on [[gatekeeper-bypasses]] and entitlement abuse rather than directly defeating AMFI.

## Why it matters

macOS code-signing is layered. From an attacker's perspective, each layer can be attacked independently:

- **Gatekeeper** decides if a fresh download is allowed to run at all.
- **Notarisation** is Apple's cloud malware scan plus signing of a ticket.
- **`codesign` / CMS signatures** prove who signed a binary and what entitlements it requests.
- **Hardened Runtime** restricts what a signed process can do at runtime (DYLD injection, JIT, etc.).
- **AMFI** is the kernel-mode policy that actually enforces "this page is signed, this entitlement is granted, this binary is allowed to execute".

If you only understand the userland half (`codesign -dvvv`, spctl) you will miss why some bypasses are catastrophic (AMFI policy hole = arbitrary entitlements) versus why others are merely annoying (quarantine bit not set = Gatekeeper skipped). See [[macos-architecture]] and [[sip]] for the surrounding kernel-protection story.

## Classes, patterns and the enforcement process

### The signing stack from disk to execve

1. A developer builds a Mach-O binary and signs it with `codesign --sign "Developer ID Application: ..."`. The signature is embedded as a `LC_CODE_SIGNATURE` load command pointing to a SuperBlob containing CodeDirectory, requirements, entitlements, and a CMS blob.
2. Optionally the app is **notarised**: uploaded to Apple, scanned, then a "ticket" is stapled to the bundle.
3. On download via a quarantine-aware app, the file gets the `com.apple.quarantine` xattr. See [[gatekeeper-and-notarisation]].
4. On first launch, Gatekeeper / `syspolicyd` consults `spctl`'s policy database, checks the ticket, and prompts the user.
5. The kernel `execve` path calls into AMFI via the MAC Framework (MACF) hooks (`mpo_vnode_check_signature`, `mpo_proc_check_run_cs_invalid`, `mpo_cred_check_label_update_execve`, etc.).
6. AMFI consults the CodeDirectory hashes, the entitlement blob, the team identifier, and provisioning profile (rare on macOS), then sets the process's CS flags (`CS_VALID`, `CS_HARD`, `CS_KILL`, `CS_RESTRICT`, `CS_REQUIRE_LV`).
7. At runtime, every page fault that brings in a code page is re-validated against the CodeDirectory hash tree. A modified page leads to `CS_KILL` and SIGKILL.

### AMFI as a MACF policy

AMFI ships as `AppleMobileFileIntegrity.kext` and registers as a MAC Framework policy. Important hooks:

- `mpo_vnode_check_signature` decides whether a Mach-O may even be mapped executable.
- `mpo_proc_check_get_task` controls whether `task_for_pid` and `processor_set_tasks` can hand out task ports, which is the gate for debugging and code injection. See [[macos-kernel-debugging]].
- `mpo_cred_label_update_execve` is where entitlements are parsed and bound to the process credential.
- `mpo_proc_check_run_cs_invalid` is what kills a process whose pages no longer match.

AMFI also exposes `amfid` in userland, a daemon the kernel asks to verify signatures it cannot finish in-kernel (for example, when CMS verification needs network or keychain access).

### Entitlements, hardened runtime, library validation

- **Entitlements** are signed XML/plist blobs in the CodeDirectory. They are *requests*. Apple-only entitlements (`com.apple.private.*`, `com.apple.rootless.*`) require Apple's signing keys; a third-party Developer ID cannot validly request them on a non-jailbroken system. Cross-reference [[entitlements-and-codesigning]].
- **Hardened Runtime** is opt-in (required for notarisation) and disables several legacy injection vectors: `DYLD_INSERT_LIBRARIES`, unsigned dylib loading, executable memory creation without `com.apple.security.cs.allow-jit`, debugger attachment, etc.
- **Library Validation (LV)** is implied by Hardened Runtime and forces every loaded dylib to be signed by the same Team ID or by Apple. LV is the single biggest defence against userland dylib hijack; turning it off requires the `com.apple.security.cs.disable-library-validation` entitlement, which notarisation rarely allows.

### SIP, AMFI and rootless

System Integrity Protection (see [[sip]]) tags certain files and directories as restricted. AMFI cooperates by treating Apple-platform binaries (those with the `platform-binary` flag in the CodeDirectory) as eligible for private entitlements. Many bypasses are really chains: an [[sip-bypasses]] primitive lets you tamper with a platform binary, which then runs with private entitlements, which AMFI honours.

### How malware bypasses or sidesteps the model

- **Skip the model entirely**: drop a non-quarantined file (LOLBin chain, AppleScript, curl writing to disk, an `xattr -d com.apple.quarantine` once code is running). Gatekeeper never runs; AMFI still validates the signature but a self-signed ad-hoc binary can still execute as long as it requests no privileged entitlements. This is the bread and butter of commodity Mac malware.
- **Use a real Developer ID**: buy or steal one, sign the loader, notarise it (Apple's scan is shallow and stage-2 payloads are fetched later). Lazarus and various adware vendors have done this for years. Cross-reference [[apt-tradecraft-dprk-lazarus]] and [[case-study-3cx-supply-chain]].
- **Notarisation abuse**: get a clean first-stage notarised, then download a second-stage that is unsigned but launched via `dlopen` from an already-validated host with `disable-library-validation`, or executed via `NSTask` of an interpreter.
- **Entitlement extraction**: find an Apple binary holding `com.apple.private.*` and abuse it (XPC service confusion, env var injection on an entitled helper, dyld cache abuse). The classic CVE-2019-8513 family and many [[macos-sandbox-escape]] bugs work this way.
- **AMFI itself**: pure AMFI bypasses (forging signatures the kernel accepts) are rare and usually chained with a kernel info-leak or a logic bug in `amfid`. Linus Henze's "CVE-2021-30724 amfid bypass" lineage and earlier `amfid` MitM tricks via `task_for_pid` of `amfid` are good study material.

## Defensive baseline

- Treat **notarisation as a weak signal**: it means "not obviously malware on a single day", not "safe".
- Require **Hardened Runtime + Library Validation** for in-house Mac apps; reject build configurations that enable `disable-library-validation` or `allow-dyld-environment-variables` without review.
- Inventory Developer ID certificates and rotate / revoke aggressively. Stolen Developer IDs are the primary signing-key supply-chain risk on macOS.
- Endpoint detection: alert on `xattr -d com.apple.quarantine`, on `spctl --master-disable`, on `csrutil disable`, on processes with `CS_VALID=0` running for more than a few seconds, and on children of `Installer.app` writing to `LaunchAgents`. Tie to [[macos-unified-logs-forensics]].
- Hunt for entitlement anomalies: scan all third-party signed code on managed endpoints for any `com.apple.private.*`, `com.apple.rootless.*`, or `get-task-allow` entitlement that is not Apple-signed. These are immediate red flags.
- Validate the **provenance chain** in CI: only ship binaries whose `codesign -dvvv --entitlements :- --xml` output matches a pinned baseline.

## Workflow to study

1. Read Apple's TN3127 "Inside Code Signing: Provisioning Profiles" and TN3125 "Inside Code Signing: Hashes" end to end.
2. Take any signed app and dump every layer:
   - `codesign -dvvv --entitlements :- /path/app`
   - `codesign --display --requirements - /path/app`
   - `spctl -a -vv /path/app`
   - `stapler validate /path/app`
   - `otool -l /path/binary | grep -A4 LC_CODE_SIGNATURE`
3. Read the open-source pieces: `Security/OSX/libsecurity_codesigning/`, the `cctools` `codesign_allocate`, and Patrick Wardle's *The Art of Mac Malware Vol. 1* chapters on signing.
4. Walk the AMFI hooks in xnu (`security/mac_*`) and in the published kext symbol names. Map each hook to a userland symptom you can reproduce.
5. Reproduce a benign "quarantine skip" lab: download a signed app two ways, with and without quarantine, and watch the difference in `log stream --predicate 'subsystem == "com.apple.syspolicy"'`.
6. Read recent advisories tagged AMFI or `_RET` in Apple's security release notes and diff with the xnu open-source drop for that release; this is the same one-day pattern in [[one-day-from-patch-diff]].
7. Build a tiny harness that calls `csops` / `csops_audittoken` on every running PID and flags processes whose CS flags mismatch their on-disk signature; this is a great detection primitive.

## Related

- [[entitlements-and-codesigning]]
- [[gatekeeper-and-notarisation]]
- [[gatekeeper-bypasses]]
- [[sip]]
- [[sip-bypasses]]
- [[macos-architecture]]
- [[macos-sandbox-escape]]
- [[macos-userland-mitigations]]
- [[macos-kernel-debugging]]
- [[macos-unified-logs-forensics]]
- [[apple-mitigations]]
- [[ios-vs-macos-divergence]]
- [[mach-and-xpc]]
- [[apt-tradecraft-dprk-lazarus]]
- [[case-study-3cx-supply-chain]]
- [[one-day-from-patch-diff]]

## References

- Apple, "TN3127: Inside Code Signing: Requirements, Hashes, and Signatures": https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements
- Apple, "Hardened Runtime": https://developer.apple.com/documentation/security/hardened_runtime
- Patrick Wardle, "The Art of Mac Malware, Volume 1" (free online): https://taomm.org/
- Csaba Fitzl, "AMFI and code signing on macOS" talk notes (Objective by the Sea): https://objectivebythesea.org/
- Linus Henze, write-up on amfid bypass lineage (Pwn2Own / public PoCs): https://github.com/LinusHenze
- jonathanlevin.net, "*OS Internals Vol. III" companion materials on AMFI: https://newosxbook.com/
