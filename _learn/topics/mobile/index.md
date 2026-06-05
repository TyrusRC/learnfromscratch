---
title: Mobile — topics
slug: mobile-index
aliases: [mobile-topics, android-index]
---

Android and iOS-side reverse + pentest primitives. See
[[mobile-security]] for ordering.

## Whitebox source review (Android)
- [[android-source-review-methodology]]
- [[android-ipc-and-intent-source-audit]]
- [[android-webview-audit]]
- [[android-content-provider-audit]]
- [[android-deeplink-source-audit]]
- [[android-keystore-and-crypto-audit]]
- [[jni-native-bridge-audit]]

## Whitebox source review (iOS)
- [[ios-source-review-methodology]]
- [[ios-url-scheme-and-universal-link-audit]]
- [[ios-keychain-and-secure-enclave-audit]]
- [[ios-ipc-xpc-audit]]
- [[ios-wkwebview-audit]]
- [[ios-objc-runtime-bridging-audit]]

## Cross-platform mobile audit
- [[mobile-cert-pinning-source-audit]]
- [[mobile-client-storage-source-audit]]
- [[mobile-auth-token-handling-audit]]

## Android fundamentals
- [[android-components]] · [[apk-file-structure]]
- [[dex-file-format]] · [[android-manifest-analysis]]

## Tooling
- [[apk-reverse-tools]]
- [[jeb-decompiler]]
- [[xposed-hook]] · [[frida-hook]]

## Attack surface
- [[android-deeplink-abuse]]
- [[android-intent-redirection]]
- [[strandhogg-task-affinity]]
- [[ssl-pinning-bypass]]

## Anti-analysis
- [[apk-anti-debug]] · [[apk-unpacking]]
- [[apk-class-overloading-dex-rebuild]]
- [[ollvm-obfuscation]]

## iOS
- [[ios-reverse-overview]]
- [[ios-ipa-structure]] · [[ios-class-dump]]
- [[ios-jailbreak-detection-bypass]]
- [[ios-keychain-extraction]]
- [[dyld-shared-cache-extraction]]

## Platform deep dives
- [[android-mali-gpu-exploitation]]
- [[android-baseband-attacks]]
- [[android-trusty-tee-attacks]]
- [[ios-baseband-attacks]]
- [[ios-bootrom-checkm8]]
