---
title: APK file structure
slug: apk-file-structure
---

> **TL;DR:** An APK is a signed ZIP holding the manifest, one or more DEX files, resources, native libraries and signing blocks — know the layout before reversing.

## What it is
APK (Android Package) is the distribution format for Android apps. It is a ZIP container with a fixed top-level layout plus a signing block appended between the central directory and the end-of-central-directory record. App Bundles (AAB) are built into APKs at install time by the store, so analysis still happens at APK level.

## Preconditions / where it applies
- Any Android binary obtained from a device (`adb pull`), store mirror, or build pipeline
- AABs require `bundletool build-apks` first
- Split APKs (base + config splits) need merging with `apkeep` or device extraction

## Technique
Standard contents:

```
AndroidManifest.xml      Binary XML — see [[android-manifest-analysis]]
classes.dex              Primary Dalvik bytecode — see [[dex-file-format]]
classes2.dex … classesN.dex   Multidex overflow
resources.arsc           Compiled resource table (strings, ids)
res/                     Compiled XML layouts, drawables
assets/                  Raw files the app reads at runtime
lib/<abi>/*.so           Native libraries per ABI (arm64-v8a, armeabi-v7a, x86_64)
kotlin/, META-INF/services/  Kotlin metadata, ServiceLoader entries
META-INF/MANIFEST.MF     v1 signature manifest
META-INF/CERT.SF, CERT.RSA  v1 signature blocks
                         v2/v3/v4 signatures live in the APK Signing Block, not META-INF
stamp-cert-sha256        Play stamp (when present)
```

Quick triage:

```bash
unzip -l app.apk | head
file lib/arm64-v8a/*.so
apksigner verify --print-certs app.apk
aapt2 dump badging app.apk | head
```

What to grab first:
- `AndroidManifest.xml` → exported components, permissions, deeplinks
- `classes*.dex` → feed to jadx / baksmali (see [[apk-reverse-tools]])
- `lib/<abi>/*.so` → native logic, JNI bridges, packers — Ghidra/IDA
- `assets/` → bundled JS bundles (React Native `index.android.bundle`), Flutter `libapp.so`, ML models, hardcoded keys
- `resources.arsc` + `res/values/strings.xml` → API endpoints, feature flags, debug strings
- `META-INF/` + signing block → certificate fingerprint, signature scheme version (v1 only is suspicious)

Note: many apps ship Kotlin metadata that exposes original parameter names and nullability; `kotlinc-metadata` or jadx renders them. Apps wrapped in packers may have a tiny `classes.dex` shim plus encrypted blobs in `assets/` — see [[apk-unpacking]].

## Detection and defence
- Ship v2+ signatures only; reject v1-only builds in CI
- Strip debug symbols from `.so` files (`llvm-strip --strip-unneeded`)
- Keep secrets out of `resources.arsc` and `assets/`; resource strings are not protected
- Enable R8/Proguard so DEX symbols are obfuscated (see [[ollvm-obfuscation]] for native)
- Use Play App Signing so the upload key is not the distribution key

## References
- [APK format overview](https://source.android.com/docs/core/runtime/dex-format) — official docs
- [APK Signature Scheme v2/v3](https://source.android.com/docs/security/features/apksigning/v2) — signing block layout
- [HackTricks – APK basics](https://book.hacktricks.wiki/en/mobile-pentesting/android-app-pentesting/index.html) — structure cheatsheet
