---
title: iOS reverse overview
slug: ios-reverse-overview
---

> **TL;DR:** Decrypt the IPA, load the Mach-O into Hopper/Ghidra/IDA, walk the Objective-C / Swift runtime, and use Frida on a jailbroken device or with a Frida-Gadget repack to instrument live.

## What it is
iOS apps ship as IPAs (ZIPs containing a `.app` bundle with a Mach-O binary, Info.plist, resources and frameworks). FairPlay encrypts the `__TEXT` segment of the main binary on App Store builds, so the first step is always a decrypted dump from a real device. Once decrypted, the binary exposes Objective-C class/method metadata and (partially) Swift symbols that make reversing far more productive than stripped C++.

## Preconditions / where it applies
- Jailbroken iOS device (checkra1n / palera1n / Dopamine depending on iOS version + chip) with SSH
- Or a sideloaded build with Frida-Gadget embedded via `objection patchipa` / `insert_dylib`
- Mach-O knowledge: load commands, segments (`__TEXT`, `__DATA`), sections (`__objc_classlist`, `__objc_methname`, `__swift5_types`)

## Technique
**1. Acquire a decrypted IPA.**

```bash
# On jailbroken device
frida-ios-dump -u <device-ip> -P alpine VictimApp     # dumps decrypted .ipa
# or
ipainstaller -l ; sudo dumpdecrypted /var/.../VictimApp.app/VictimApp
```

`otool -l VictimApp | grep -A4 LC_ENCRYPTION_INFO` should show `cryptid 0` after dumping.

**2. Static analysis.**

- Hopper / IDA / Ghidra load Mach-O directly. Apply the ObjC class-dump first: `class-dump-z` or `jtool2 -d objc` lists every class, method and ivar.
- Swift: use `swift-demangle` on symbols; reflective metadata in `__swift5_types` reveals types but parameter names are stripped unless `@objc` exposed.
- Strings live in `__cstring` / `__cfstring`; pull endpoints, debug flags, key fragments.
- Universal binaries: `lipo -thin arm64 in -output out` before disassembly.

**3. Dynamic instrumentation.**

```bash
# Frida on jailbroken iOS
frida-ps -Uai                                   # installed apps
frida -U -f com.victim.app --no-pause -l hook.js
```

```javascript
// Hook an Objective-C method
var cls = ObjC.classes.AuthManager;
Interceptor.attach(cls['- isLoggedIn'].implementation, {
  onLeave: function (retval) { retval.replace(ptr(1)); }
});
```

**4. Bypass anti-jailbreak.** Common checks: `/Applications/Cydia.app` `stat`, `fork()` succeeding outside sandbox, `dyld` images for `MobileSubstrate`. Frida hooks on `NSFileManager.fileExistsAtPath:`, `stat`, `dlopen`, `dlsym` defeat most. See parallel concepts in [[apk-anti-debug]].

**5. Network.** [[ssl-pinning-bypass]] works the same idea — hook `SecTrustEvaluate*`, `NSURLSession` delegates, or use SSL Kill Switch 2.

**6. Keychain + plist + Realm/SQLite.** Pull `~/Library/Keychains/`, app `Documents/`, `Caches/`. Frida's `ObjC.classes.SSKeychain` or `objection ios keychain dump` enumerates entries by access group.

Useful tools: Hopper (cheap commercial), IDA Pro (gold standard), Ghidra (free), `class-dump-z`, `jtool2`, `otool`, `nm`, `lipo`, `frida-ios-dump`, `objection`, `passionfruit`, `r2` with `iOS-class-guesser`.

## Detection and defence
- Use Apple's DeviceCheck / App Attest for server-side jailbreak signal, not client `stat` checks
- Encrypt sensitive strings, decrypt with hardware-backed keys via Secure Enclave
- Pin certificates using `NSURLSessionDelegate` plus a native re-check
- Detect Frida by scanning loaded images (`_dyld_image_count`, `_dyld_get_image_name`) for `gum-js-loop` / `frida`
- Treat all client checks as delays; enforce identity server-side

## References
- [HackTricks – iOS pentesting](https://book.hacktricks.wiki/en/mobile-pentesting/ios-pentesting/index.html) — full workflow
- [Frida iOS guide](https://frida.re/docs/ios/) — setup + ObjC bridge
- [OWASP MASTG iOS](https://mas.owasp.org/MASTG/iOS/) — testing techniques catalogue
