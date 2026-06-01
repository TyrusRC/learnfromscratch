---
title: iOS jailbreak-detection bypass
slug: ios-jailbreak-detection-bypass
---

> **TL;DR:** Apps that "detect jailbreak" check a small, well-known set of side effects (Cydia paths, fork() success, dyld images, SSH ports); Frida or a substrate tweak hooks the four or five primitives that back all of them and the app stops noticing.

## What it is
"Jailbreak detection" is client-side anti-tamper: refuse to run, blank sensitive screens, or notify a backend if the device looks rooted. Almost every implementation reduces to:

1. **Filesystem check** — `stat`/`NSFileManager fileExistsAtPath:` on `/Applications/Cydia.app`, `/private/var/lib/apt`, `/usr/sbin/sshd`, `/bin/bash`, `/etc/apt`.
2. **Fork check** — call `fork()`; on stock iOS sandboxed processes get `-1`, jailbroken ones often succeed.
3. **Image-list check** — `_dyld_image_count` / `_dyld_get_image_name` walk loaded dylibs looking for `MobileSubstrate`, `SubstrateLoader`, `libcycript`, `frida-agent`, `cynject`, `pspawn_payload`.
4. **`dlopen`/`dlsym` probe** — try to open `/usr/lib/libcycript.dylib`; success = jailbroken.
5. **URL-scheme probe** — `canOpenURL:` on `cydia://`, `sileo://` (requires `LSApplicationQueriesSchemes` entry, often forgotten).
6. **Symlink / sandbox probe** — write to `/private/jailbreak.txt` or read `/etc/master.passwd`; on a sandboxed app these fail.
7. **Port probe** — TCP-connect to localhost:22 (SSH).
8. **Entitlement check** — own binary has unexpected entitlements (jailbroken devices sometimes inject `get-task-allow`).

Modern detectors (commercial: Promon SHIELD, Talsec, Guardsquare iXGuard) chain dozens of these and obfuscate the underlying primitives so a naive `NSFileManager` hook misses checks done via raw `syscall(SYS_stat)`.

## Preconditions / where it applies
- Jailbroken iOS device + Frida or substrate tooling — *or* a Frida-Gadget re-pack of the IPA for non-jailbroken devices.
- Decrypted target binary so you can find the detection routines statically.

## Technique
**1. Map the detection routines.** Class-dump (see [[ios-class-dump]]) the binary and grep:
```bash
class-dump-z -H -o h Victim
grep -ri "jailb\|cydia\|RootCheck\|isCompromised\|isTampered" h/
```
Cross-reference these symbols with disassembly to find every call site.

**2. Frida script template.** One script that handles the common primitives:

```javascript
// hook stat / lstat / NSFileManager
var stat = Module.findExportByName(null, "stat");
Interceptor.attach(stat, {
  onEnter(args) {
    var path = args[0].readUtf8String();
    if (/cydia|sileo|apt|MobileSubstrate|libimo|bash/i.test(path)) this.fake = 1;
  },
  onLeave(retval) { if (this.fake) retval.replace(-1); }
});

// hook NSFileManager fileExistsAtPath:
var FM = ObjC.classes.NSFileManager;
Interceptor.attach(FM['- fileExistsAtPath:'].implementation, {
  onEnter(args) {
    var path = new ObjC.Object(args[2]).toString();
    if (/cydia|sileo|MobileSubstrate|bash|apt/i.test(path)) this.fake = 1;
  },
  onLeave(retval) { if (this.fake) retval.replace(0); }
});

// hook fork
Interceptor.replace(Module.findExportByName(null, "fork"),
  new NativeCallback(function () { return -1; }, 'int', []));

// hook _dyld_image_count / _dyld_get_image_name
var count = Module.findExportByName(null, "_dyld_image_count");
var origCount = new NativeFunction(count, 'uint32', []);
Interceptor.replace(count, new NativeCallback(() => origCount() - 3, 'uint32', []));

// hook canOpenURL:
var UIApp = ObjC.classes.UIApplication;
Interceptor.attach(UIApp['- canOpenURL:'].implementation, {
  onEnter(args) {
    var u = new ObjC.Object(args[2]).absoluteString().toString();
    if (/^cydia|^sileo|^undecimus/.test(u)) this.fake = 1;
  },
  onLeave(retval) { if (this.fake) retval.replace(0); }
});
```

**3. Off-the-shelf options.**
- `objection` ships `ios jailbreak disable` which applies the same hooks plus several anti-anti-Frida ones.
- **Liberty Lite** / **A-Bypass** / **Choicy** — substrate tweaks for jailbroken devices.
- **Shadow** — open-source detection bypass tweak (active community fork).

**4. Defeating obfuscated detectors.** Commercial detectors call `syscall(0x14, ...)` directly to avoid libc symbol hooks. Counter:
- Use `Interceptor.attach` on the raw `syscall` symbol *and* check the syscall number in `onEnter`.
- Or use `Stalker` to instrument every block and intercept the `svc 0x80` instruction.
- For inline checks, find the call in IDA and use Frida's `Interceptor.replace` at the exact offset.

**5. Defeat integrity checks that follow.** Many detectors call `home`/`telemetry` rather than blocking — silence those network calls separately (hook `NSURLSession dataTaskWithRequest:`).

**6. Non-jailbroken devices.** Repack the IPA with Frida-Gadget via `objection patchipa`. The gadget loads on app start and you inject scripts via TCP. Requires re-signing with a personal developer account.

## Detection and defence
- Accept that client checks are speedbumps. Use Apple **DeviceCheck** / **App Attest** to get a server-attested signal that the app is unmodified on a non-jailbroken device — this is the only reliable jailbreak / tamper detection.
- Combine: client signal + server attestation + behavioural anomalies (sensor-fingerprint mismatches, impossible-to-fake hardware signals).
- Don't telegraph detection — silently degrade rather than show "jailbreak detected"; this raises the cost of finding which check fired.

## References
- [OWASP MASTG — Anti-Reversing Defenses for iOS](https://mas.owasp.org/MASTG/iOS/0x06j-Testing-Resiliency-Against-Reverse-Engineering/)
- [Frida Codeshare — iOS jailbreak bypass scripts](https://codeshare.frida.re/) — community scripts
- [Apple — DeviceCheck and App Attest](https://developer.apple.com/documentation/devicecheck) — server-side attestation
- [Shadow](https://ios.jjolano.me/) — open-source bypass tweak
