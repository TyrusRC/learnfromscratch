---
title: Mobile bug bounty methodology
slug: mobile-bug-bounty-methodology
aliases: [mobile-bb-method, android-ios-bb-methodology]
---

> **TL;DR:** Mobile bug bounty is web-API hunting with a thicker client. The client is the recon engine: pull the APK or IPA, decompile to find every server endpoint, every deeplink, every IPC entry, every hardcoded secret, then proxy the live app to confirm what the server actually trusts. This note gives a repeatable methodology for both platforms. Pair with [[android-source-review-methodology]], [[ios-source-review-methodology]], and [[mobile-cert-pinning-source-audit]] for the static-analysis depth, and with [[testing-methodology-checklists]] for the bug-bounty hygiene around it.

## Why it matters

Mobile programs pay because triagers can't reproduce many issues without a rooted/jailbroken device, so the dupe rate is lower than web. The flip side: most reports get closed as "client-side only, no impact". The wins come from using the mobile client to discover **server-side** behaviour the web app never exposes — mobile-only endpoints, debug headers, partner-specific OAuth flows, legacy SOAP gateways — and then proving impact server-side. The client matters mostly as a map ([[expanding-attack-surface]]) and as the trust anchor you bypass to talk to those endpoints.

You also get a second income stream: pure-client bugs (deeplink ATO, IPC privilege escalation, biometric bypass, plaintext token storage) that web hunters can't touch. Programs like Shopify, Uber, Meta, GitLab, and most banks scope mobile explicitly and pay 1.5-3x web bounties on the client-side classes because the talent pool is smaller. See [[program-selection-tactics]] for picking the right program.

## Setup

### iOS test device

- A jailbroken iPhone on a supported iOS version (palera1n for A11 and below, Dopamine for A12+ up to iOS 16.x, checkra1n for older hardware). Buy a dedicated A10/A11 device second-hand — never jailbreak your daily driver.
- Tooling via Sileo or Zebra: `Frida`, `SSH`, `Filza`, `NewTerm`, `objection`, `Choicy`, `A-Bypass` or `Shadow` for jailbreak-detection bypass when you don't want to write your own. See [[ios-jailbreak-detection-bypass]].
- macOS host with Xcode (for `class-dump`, `lldb`, simulator), `ideviceinstaller`, `libimobiledevice`, `frida-tools`, `objection`, `Hopper` or `IDA Pro`, `Ghidra`.
- Decrypt IPAs with `frida-ios-dump` or `bagbak` — App Store binaries are FairPlay-encrypted and `class-dump` will return junk until you decrypt.

### Android test environment

- A rooted physical device (Pixel with GrapheneOS removed and Magisk installed, or a OnePlus with unlocked bootloader) **and** a rooted emulator (Android Studio AVD with `rootAVD`, or Genymotion). Some apps detect emulator; some detect specific Magisk modules. Have both.
- Magisk modules: `MagiskHide` / `Zygisk-DenyList`, `LSPosed`, `Shamiko`, `Frida-Server`. See [[frida-hook]].
- Host tooling: `apktool`, `jadx-gui`, `apksigner`, `bundletool`, `mob-sf` for first-pass triage, `Frida`, `objection`, `drozer`, `adb`, `aapt2`, `Ghidra` for native libs.
- Burp Suite or mitmproxy with the CA installed as a **system** trust store entry (not user store — Android 7+ ignores user CAs for most apps). Magisk module `MagiskTrustUserCerts` is the cheap path.

### Account hygiene

Two test accounts per app, ideally on different phone numbers and emails (for OTP). Many mobile bugs are [[bola]] / [[bfla]] / [[idor]] variants and need a second victim account. Read [[program-scope-reading]] before touching production tenants.

## Bug classes specific to mobile

### Deeplink hijack and intent abuse (Android-heavy, iOS-relevant)

- Exported activities, services, broadcast receivers that accept untrusted intents. `drozer` to enumerate, `jadx` to read the handler.
- Custom schemes (`myapp://`) and Android App Links / iOS Universal Links with weak verification (missing `assetlinks.json`, missing `apple-app-site-association`, wildcard paths).
- WebView `loadUrl` taking deeplink parameters, leading to XSS-in-WebView, `file://` reads, or JS bridge invocation.
- See [[android-deeplink-abuse]].

### IPC abuse

- Android: content providers exported by default on older `targetSdk`, custom permissions with `signature` level confused with `normal`, `PendingIntent` mutability bugs (CVE-2021-39709 class).
- iOS: XPC services in app extensions, `NSExtensionContext` callbacks, pasteboard sniffing, keyboard extensions, share-sheet handlers.

### Insecure local storage

- Tokens, PII, encryption keys in `SharedPreferences` (Android) or `NSUserDefaults` / plist (iOS) — both plaintext by default.
- SQLite databases without SQLCipher, or with the key hardcoded next to the DB.
- Keychain items with `kSecAttrAccessibleAlways` (readable when device locked). See [[mobile-client-storage-source-audit]] and [[mobile-auth-token-handling-audit]].

### Weak biometric / auth gating

- Biometric prompt that returns success without binding to a `CryptoObject` — bypassable with Frida by hooking the callback.
- "Remember me" flows that store a refresh token and skip biometric on app launch.
- Local PIN compared client-side (jadx will show it instantly).

### Server-side mobile-only endpoints

This is where the money is. Mobile clients often hit `/api/v2/mobile/...` or `api-mobile.target.com` with relaxed auth, debug headers (`X-Debug-User-Id`), older API versions still online, or legacy gateways. Proxy every request, diff against the web app's API, hunt [[bola]], [[mass-assignment]], [[broken-access-control]], and [[ssrf]] there. Apply [[api-fuzzing-wide-vs-deep]].

### Cert pinning as a discovery signal

If pinning exists and you bypass it ([[ssl-pinning-bypass]], [[mobile-cert-pinning-source-audit]]), the endpoints behind it are usually the high-value ones the developer wanted to hide. Pinning bypass alone is rarely paid; what you find behind it is.

## Process

### Static first

1. Pull the artifact. Android: `adb shell pm path com.target.app` then `adb pull`, or grab the universal APK from APKMirror / APKPure. iOS: `frida-ios-dump -l` to get a decrypted IPA. See [[apk-reverse-tools]].
2. First-pass triage with MobSF — gives you exported components, permissions, hardcoded strings, network security config in 60 seconds.
3. Decompile. Android: `jadx-gui app.apk` and read `AndroidManifest.xml` first, then any class with `Activity`, `Service`, `Receiver`, `Provider`, `WebView`, `Intent` in the name. iOS: `class-dump` (after decrypt) for Obj-C, Hopper/IDA for Swift (Swift demangling: `swift-demangle`). Apply [[android-source-review-methodology]] and [[ios-source-review-methodology]].
4. String search the binary: `strings -n 8 binary | grep -iE 'http|api|secret|token|key|debug|admin'`. Endpoints, AWS keys, Firebase configs, third-party SDK tokens all surface here. Cross-check with [[expanding-attack-surface]].
5. Map every URL, every deeplink, every IPC component to a hypothesis: "if I hit this without auth, what happens?". This is your test plan.

### Dynamic next

1. Install on test device, sign in with account A, proxy through Burp with the CA trusted system-wide.
2. If TLS errors: kill pinning with `objection --gadget com.target.app explore` then `android sslpinning disable` (or iOS equivalent), or write a custom Frida script. [[ssl-pinning-bypass]].
3. Walk every screen, log every request, label by feature. This is the [[getting-feel-for-target]] step.
4. Replay account A's tokens against account B's resource IDs — classic [[bola]] / [[idor]] sweep.
5. Frida-hook security-relevant functions: jailbreak/root checks, biometric callbacks, signature verifiers, crypto key derivation. Use Frida to invoke internal methods directly (`objection`'s "invoke" or `Java.use(...).method()`). This is how you reach code paths the UI doesn't expose.
6. Trigger deeplinks externally: `adb shell am start -a android.intent.action.VIEW -d "myapp://path"` from a second device or a malicious app PoC. iOS: `xcrun simctl openurl booted "myapp://path"` or a Safari redirect.

### Program-specific differences

- **Android-only programs** (some Asian fintech, lots of telco): focus on IPC, deeplink, WebView JS bridges, native library bugs.
- **iOS-only programs** (some banking, Apple itself): keychain ACL, Universal Links, share extensions, jailbreak-detection logic worth less than the endpoints behind it.
- **Both**: always diff the two platforms. iOS team and Android team frequently implement the same feature differently, and one will have a stricter server check than the other. The weaker one is your foothold. See [[case-study-h1-top-disclosed-2024-2025]] for examples.

## Defensive baseline (what programs expect to see)

You don't get paid for telling them "you should pin certs" — they know. To set realistic expectations and avoid wasting triage cycles, internalise the baseline:

- TLS pinning to a backup pin set, with kill-switch. Bypass alone is informational.
- Root/jailbreak detection as defense-in-depth, not a security boundary. Bypass alone is informational.
- Obfuscation (R8, iXGuard, Arxan). Not in scope as a bug.
- Local storage encrypted with hardware-backed keys (Keystore, Secure Enclave). "I extracted the DB on a rooted device with the user's PIN" is usually not paid.
- Anti-Frida, anti-debug. Bypass alone is informational.

Map your finding to **server impact** or **realistic client attack** (malicious app, malicious deeplink, malicious nearby device for NFC/BLE). See [[demonstrating-impact]].

## Workflow to study

1. Pick one mobile-scoped program from HackerOne / Bugcrowd with both iOS and Android in scope. Apply [[program-selection-tactics]] and [[target-selection-heuristics]].
2. Pull both binaries. Spend day one fully static: every endpoint, every deeplink, every exported component into a spreadsheet.
3. Day two: set up proxy, walk the app, label every request with the feature that triggered it, diff against the static list. What endpoints in the binary did you not see fired? Why? Hit them directly.
4. Day three: pick three hypotheses (one server-side, one deeplink, one storage/biometric) and test each on actual devices.
5. Write up the server-side one with a clean PoC ([[report-writing]], [[report-writing-step-by-step]]), include device/OS, app version, proxy capture, and a one-tap PoC video.
6. After triage, journal what bypassed pinning, what the developer caught, what stayed hidden. Feed this into [[automation-and-rinse-repeat]] for the next program.
7. For exotic platforms, also study [[ios-baseband-attacks]] and [[android-baseband-attacks]] to know what's out of mobile-bb scope.

## Related

- [[android-source-review-methodology]] — static depth on Android
- [[ios-source-review-methodology]] — static depth on iOS
- [[mobile-cert-pinning-source-audit]] — pinning code review
- [[mobile-auth-token-handling-audit]] — token storage review
- [[mobile-client-storage-source-audit]] — local data review
- [[android-deeplink-abuse]] — deeplink class
- [[ssl-pinning-bypass]], [[ios-jailbreak-detection-bypass]] — runtime bypasses
- [[frida-hook]], [[apk-reverse-tools]] — tooling
- [[mobile-security]] — broader topic
- [[api-security]], [[bola]], [[bfla]], [[idor]], [[broken-access-control]], [[mass-assignment]] — server-side bugs to chase via mobile recon
- [[expanding-attack-surface]], [[getting-feel-for-target]], [[testing-methodology-checklists]] — bug-bounty hygiene
- [[demonstrating-impact]], [[report-writing-step-by-step]] — closing the loop
- [[case-study-h1-top-disclosed-2024-2025]] — patterns in public reports

## References

- [OWASP Mobile Application Security Testing Guide (MASTG)](https://mas.owasp.org/MASTG/)
- [OWASP Mobile Application Security Verification Standard (MASVS)](https://mas.owasp.org/MASVS/)
- [HackTricks — Mobile Pentesting](https://book.hacktricks.wiki/en/mobile-pentesting/index.html)
- [Frida documentation](https://frida.re/docs/home/)
- [objection runtime mobile exploration](https://github.com/sensepost/objection)
- [Android App Security Best Practices (Google)](https://developer.android.com/privacy-and-security/security-tips)
