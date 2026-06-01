---
title: Entitlements and code signing
slug: entitlements-and-codesigning
---

> **TL;DR:** An entitlement is a plist key embedded in a Mach-O code signature that grants the binary a specific privilege (TCC bypass, sandbox exception, debugger access). Abuse paths: weakly signed Apple helpers, inheritance into child processes, and `get-task-allow` letting you attach.

## What it is
macOS code signing is enforced by AppleMobileFileIntegrity (AMFI) in the kernel and `taskgated`/`taskgated-helper` in userland. Every Mach-O has a `LC_CODE_SIGNATURE` blob: hashes of code pages, the **CodeDirectory**, a **requirement** expression, and the **entitlements** plist. The kernel checks signatures at `exec` and at Mach-port lookup; entitlements are queried by services (TCC, sandbox, SecKeychain, EndpointSecurity) to authorise privileged operations.

## Preconditions / where it applies
- Any local privesc, sandbox escape, or TCC bypass on macOS — the entitlements model is what divides "anybody" from "this specific Apple binary".
- Apple Silicon enforces code signing for *all* executable pages; Intel macOS does the same for hardened binaries.
- Particularly relevant on apps shipped with `com.apple.security.cs.disable-library-validation` or `com.apple.security.get-task-allow`.

## Technique
Read what a binary asks for:

```bash
codesign -dv --entitlements - /Applications/Foo.app/Contents/MacOS/Foo
codesign -d --requirements - /Applications/Foo.app/Contents/MacOS/Foo
spctl --assess --verbose /Applications/Foo.app
```

Common abuse patterns:

1. **`com.apple.security.cs.disable-library-validation`** — the app accepts unsigned or third-party-signed dylibs. Plant a dylib named like a weak-linked dependency and load via `DYLD_INSERT_LIBRARIES` or a hijack path. Now your code runs *inside* a process that may hold TCC grants (Full Disk Access, Accessibility, Camera).
2. **`com.apple.security.get-task-allow`** — the binary is debuggable. `task_for_pid` from a peer process succeeds and you can inject via Mach ports.
3. **`com.apple.private.*` entitlements on shipped Apple binaries** — historically researchers found Apple helpers with sweeping private entitlements (e.g. `com.apple.rootless.install.heritable`) reachable from a less-privileged context. Hijacking the binary inherits the entitlement.
4. **Inheritance via `posix_spawn`/`exec`** — entitlements do *not* persist across exec to a different binary; they re-evaluate against the new code signature. But child *tasks* inherit a `task_port` you can drive.
5. **Ad-hoc / linker-resigned binaries** — `codesign -s -` strips real identity but retains structure; combined with disabled library validation this becomes a stealth-injection path on user-installed apps.

Search system for interesting entitlements:

```bash
sudo find /System /Applications -type f -perm -u+x -exec \
  sh -c 'codesign -d --entitlements - "$1" 2>/dev/null | grep -q "$2" && echo "$1"' _ {} "get-task-allow" \;
```

## Detection and defence
- EndpointSecurity emits `ES_EVENT_TYPE_NOTIFY_EXEC` with the full code-signing info — defenders alert on unexpected entitlements on user-writable paths.
- Enable Hardened Runtime + Library Validation on every internally built app; never ship the "disable-library-validation" entitlement to production.
- Use the App Sandbox where possible — entitlements then double as the sandbox's allow-list, narrowing the blast radius. See [[macos-sandbox-escape]] and [[macos-tcc]].

## References
- [Apple — Code Signing Guide](https://developer.apple.com/documentation/security/code-signing-services) — official API surface.
- [Apple — Entitlements reference](https://developer.apple.com/documentation/bundleresources/entitlements) — list of public entitlements.
- [HackTricks — macOS code signing](https://book.hacktricks.wiki/en/macos-hardening/macos-security-and-privilege-escalation/macos-files-folders-and-binaries/macos-bundles.html) — offensive notes.
