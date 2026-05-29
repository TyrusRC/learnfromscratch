---
title: Mobile security (Android + iOS)
slug: mobile-security
aliases: [mobile-pentesting, android-pentesting]
---

> Mobile app pentesting and reverse — what bug-bounty researchers,
> red-teamers, and audit reviewers actually do on Android and iOS.
> Heavy on Android because Android is heavier on attack surface.

## Prereqs

- Comfortable shell user; one scripting language.
- A test Android device or emulator (Genymotion, Android Studio AVD).
- Burp Suite or Caido for traffic inspection.

## Stage 1 — Android fundamentals

Goal: read any APK and explain its attack surface inside thirty
minutes.

- [[android-components]] — Activity, Service, Receiver, Provider.
- [[apk-file-structure]] · [[dex-file-format]].
- [[android-manifest-analysis]] — exported flags, intent filters,
  permissions, deeplinks.
- Tooling: [[apk-reverse-tools]] (jadx for free, JEB for serious work).

## Stage 2 — dynamic analysis and traffic

Goal: make any app's network traffic visible in Burp; observe runtime
behaviour you couldn't predict from static analysis alone.

- [[ssl-pinning-bypass]] — the universal first step.
- [[frida-hook]] — instrument any method without recompiling.
- [[xposed-hook]] — alternative on rooted devices.
- WebView attack surface — JS bridges, file://, mixed-content scope.

## Stage 3 — attack surfaces and bug classes

- [[android-deeplink-abuse]] — exported activities with intent extras
  as the canonical authZ-bypass pattern.
- Content provider abuse — unsanitised URI parameters → SQLi / path
  traversal.
- Insecure storage — SharedPreferences in cleartext, world-readable
  files, screenshot leakage.
- Crypto in mobile — hardcoded keys, mode misuse (see
  [[applied-crypto|applied cryptography]]).
- IPC abuse — Bound services, Messenger, AIDL.

## Stage 4 — anti-analysis and obfuscation

- [[apk-anti-debug]] — root detection, Magisk Hide check, signature
  verification, Frida detection.
- [[apk-unpacking]] — common packers and dump-from-memory approach.
- [[ollvm-obfuscation]] — control-flow flattening; defeated with
  symbolic execution or Triton.

## Stage 5 — iOS divergence

- [[ios-reverse-overview]] — Mach-O, Objective-C runtime, Frida-iOS-dump.
- Keychain semantics, App Group sharing.
- See [[macos-security]] for shared concepts (TCC, sandbox, code
  signing).

## Where this earns money / impact

- Bug-bounty: deeplink-based authZ bypass, IDOR in mobile API
  endpoints, cleartext-stored auth tokens.
- Audit: mandatory checklist items on OWASP MASVS.
- Red team: rogue-MDM scenarios, mobile-app supply-chain.

## References

- [OWASP MASTG / MASVS](https://mas.owasp.org/) — definitive
  methodology.
- [HackTricks Mobile
  Pentesting](https://book.hacktricks.wiki/en/mobile-pentesting/index.html).
- [Oversecured blog](https://blog.oversecured.com/) — real-world
  Android vuln research.
- [Frida documentation](https://frida.re/docs/home/).
- *Handbook for CTFers* (Nu1L Team, Springer) — informed the Android /
  APK structural coverage.
