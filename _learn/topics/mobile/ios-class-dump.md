---
title: iOS class-dump (Obj-C / Swift metadata extraction)
slug: ios-class-dump
---

> **TL;DR:** Objective-C keeps every class name, method selector, and ivar layout in plain text inside the Mach-O so `class-dump-z`/`jtool2`/`Hopper` recover the entire interface; Swift exposes less but `__swift5_types` still leaks type names and conformances if you dump it.

## What it is
Objective-C is dynamic: the runtime needs runtime-resolvable class and selector names, so the compiler stores them in dedicated Mach-O sections (`__objc_classlist`, `__objc_classname`, `__objc_methname`, `__objc_ivar`, `__objc_protolist`, `__objc_const`). Reading those sections rebuilds something close to the original `.h` interface — class names, instance/class methods, ivar offsets, protocol conformances. Swift adds richer reflection in `__swift5_types`, `__swift5_protos`, and `__swift5_fieldmd` but compiler optimisations and `private`/`fileprivate` access modifiers strip more away.

## Preconditions / where it applies
- A **decrypted** Mach-O (after FairPlay strip; see [[ios-reverse-overview]]).
- macOS or Linux with class-dump tooling. Works fully offline.

## Technique
**1. Verify decryption.** `class-dump` reads `__TEXT` directly; encrypted binaries yield gibberish class names.
```bash
otool -l Victim | grep -A4 LC_ENCRYPTION_INFO    # cryptid 0 = decrypted
```

**2. Obj-C class dump.**
```bash
# class-dump-z (Cydia / brew tap)
class-dump-z -H -o headers/ Victim

# Alternative: jtool2
jtool2 --analyze --objc Victim | tee objc.txt

# Hopper / IDA / Ghidra do this automatically on load
```
Output is a tree of `@interface` declarations. Useful patterns to grep for:
- `@property` + `nonatomic, retain` → ivars worth UAF-spraying.
- Methods named `validate*`, `is*Jailbroken`, `verify*Signature`, `check*Integrity` → anti-tamper logic to neutralise.
- Methods that take `NSURL*` or `NSString*` and forward to `NSURLSession` → network attack surface; cross-ref with [[android-intent-redirection|the Android equivalent in deep-link routing]].
- Categories on Apple classes (e.g., `@interface NSData (CustomCrypto)`) → drop-in points for [[frida-hook|Frida hooks]].

**3. Swift metadata.**
- `class-dump` Swift support is partial — best tools today: **Ghidra's Swift loader**, **`swiftdump`**, **IDA's Swift plugin**, **`r2` with `-aaaa`**.
- Even without symbols, `__swift5_types` reveals type names; `__swift5_fieldmd` reveals field names and types. Method signatures often demangle if you run `swift-demangle` on the stripped symbols.
```bash
nm Victim | swift-demangle | head -50
```
- Swift's name mangling is documented at swift.org. `$s` prefix introduces a Swift symbol; the mangled body encodes module + type + member.

**4. Cross-reference with disassembly.** Hopper/IDA correlate `__objc_methname` strings with the corresponding `IMP` addresses (`__objc_methlist` slots) so you can right-click any selector and jump to the implementation. For dynamic message dispatch (`objc_msgSend(x, @selector(foo:))`), the receiver type comes from the surrounding code.

**5. Quick attack-surface map.**
```bash
class-dump-z -H -o /tmp/h Victim
grep -r "URL" /tmp/h | head            # URL-taking methods
grep -r "WKUserContentController" /tmp/h   # JS bridges (RCE surface in WebViews)
grep -r "LAContext\|TouchID\|FaceID" /tmp/h  # biometric checks (commonly bypassed)
grep -r "Jailb\|Cydia\|RootCheck" /tmp/h    # JB detection
```

**6. Verify with runtime introspection.** Once you have a target class, confirm at runtime via Frida:
```javascript
var cls = ObjC.classes.AuthManager;
console.log(cls.$ownMethods);              // every selector
console.log(cls.$ivars);                   // ivar layout
console.log(cls['- isLoggedIn'].implementation);  // pointer to IMP
```

## Detection and defence
- For developers: prefer Swift over Obj-C for sensitive logic; strip symbols (`-Xlinker -no_symbols`) and disable Swift reflection (`-disable-reflection-metadata`, `-disable-reflection-names`) for release builds.
- Move sensitive checks into server-side flows; treat client class-dump output as essentially public.
- Use opaque names for security-critical classes (`Q9F1` instead of `JailbreakDetector`) — minor obfuscation but raises analysis cost.

## References
- [class-dump-z (nygard/limneos branches)](https://github.com/nygard/class-dump) — long-running Obj-C dumper
- [jtool2](https://www.newosxbook.com/tools/jtool.html) — Jonathan Levin's combined Mach-O / class-dump tool
- [Swift name mangling spec](https://github.com/swiftlang/swift/blob/main/docs/ABI/Mangling.rst) — official rules
- [OWASP MASTG — iOS static analysis](https://mas.owasp.org/MASTG/iOS/0x06c-Reverse-Engineering-and-Tampering/)
