---
title: Gatekeeper and notarisation
slug: gatekeeper-and-notarisation
---

> **TL;DR:** When a file is tagged with `com.apple.quarantine`, first launch triggers Gatekeeper — signature check, notarisation ticket lookup, and a consent prompt. It catches drive-by downloads; it does not stop a payload the user has explicitly allowed.

## What it is
**Gatekeeper** is the userland policy daemon (`syspolicyd` + `XProtect`) that runs whenever an executable or bundle bearing the `com.apple.quarantine` extended attribute is launched. It verifies the code signature, checks Apple's **notarisation** ticket (proof Apple's automated scan reviewed the build), evaluates **XProtect** YARA-like signatures, and shows the "Are you sure you want to open …?" prompt. Quarantine itself is set by the launching app (Safari, Mail, Messages) — apps that do not set it (curl, `git clone`, third-party tools) skip Gatekeeper entirely.

## Preconditions / where it applies
- File must carry `com.apple.quarantine` xattr; only then does Gatekeeper run.
- macOS 10.15+: notarisation required for app distribution outside the App Store; macOS 13+ tightens this further with **Launch Constraints**.
- Relevant to phishing/payload delivery and to red-team tradecraft around macOS installers (`.pkg`, `.dmg`, `.app` inside `.zip`).

## Technique
Inspect quarantine and Gatekeeper state:

```bash
xattr -p com.apple.quarantine /path/to/Downloaded.app
spctl -a -vv /path/to/Downloaded.app          # assess
stapler validate /path/to/Downloaded.app      # notarisation ticket stapled?
```

What Gatekeeper actually checks at first launch:
1. **Signature integrity** — `codesign --verify` on the bundle, with the embedded Designated Requirement.
2. **Notarisation** — either a stapled ticket on the bundle, or an online lookup via `CloudKit` to Apple's notary service.
3. **XProtect** — match against Apple's signature feed (`/Library/Apple/System/Library/CoreServices/XProtect.bundle`).
4. **Translocation** — apps from quarantined locations may be launched from a read-only randomised path so they cannot read sibling files (defeats some loader tricks).

Notarisation is *not* a malware audit — it is automated static + light dynamic scanning. Apple has revoked notarisation tickets after the fact when families slip through, but expect a window.

Bypass families covered separately in [[gatekeeper-bypasses]]: missing quarantine on archive members, AppleDouble metadata abuse, signature-format edge cases, library validation gaps.

## Detection and defence
- Endpoint logs: `syspolicyd` writes to the unified log — filter with `log stream --predicate 'subsystem == "com.apple.syspolicy"'`.
- Defenders flag binaries executed without the quarantine xattr from user-writable paths (suggests an unusual delivery chain).
- Hardening: do *not* strip `com.apple.quarantine` blindly in MDM; restrict admin to remove it. Configure MDM to require notarisation for all distributed software.
- Enable **Lockdown Mode** for high-risk users (further restricts loader/JIT behaviour).

## References
- [Apple — Gatekeeper and runtime protection](https://support.apple.com/guide/security/gatekeeper-and-runtime-protection-sec5599b66df/web) — official model.
- [Apple — Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) — developer side.
- [Patrick Wardle — Objective-See blog](https://objective-see.org/blog.html) — repeated Gatekeeper bypass writeups.
