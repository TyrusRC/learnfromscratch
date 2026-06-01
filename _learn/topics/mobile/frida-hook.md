---
title: Frida hooks (Android)
slug: frida-hook
---

> **TL;DR:** Frida injects a JavaScript engine into the target process and lets you replace Java/native methods at runtime — the fastest way to bypass root checks, SSL pinning and custom crypto.

## What it is
Frida is a dynamic instrumentation toolkit. On Android, `frida-server` runs as root on the device and exposes a control channel; on the host, `frida` / `frida-trace` / a Python client attaches to a target process, loads a JS agent, and uses the `Java` and `Interceptor` APIs to intercept methods. For unrooted devices, `frida-gadget` is repackaged into the APK as a shared library that the app itself loads.

## Preconditions / where it applies
- Rooted device with `frida-server` of matching arch + version, or repackaged APK embedding `frida-gadget` (see [[apk-reverse-tools]])
- USB or network reachability between host and device
- Target not employing aggressive [[apk-anti-debug]] / Frida detection — otherwise spawn paused and hook the detector first

## Technique
Setup and discovery:

```bash
# Push the right frida-server to the device
adb push frida-server-16.x-android-arm64 /data/local/tmp/fs
adb shell "chmod 755 /data/local/tmp/fs && /data/local/tmp/fs &"

frida-ps -U                                  # list running processes
frida -U -f com.victim --no-pause -l hook.js # spawn target with agent
```

Java hook — overriding a method:

```javascript
Java.perform(function () {
  var Auth = Java.use('com.victim.security.Auth');
  Auth.verifyToken.implementation = function (tok) {
    console.log('[+] verifyToken called with: ' + tok);
    return true; // bypass
  };

  // Print every overload of a noisy method
  var Crypto = Java.use('com.victim.Crypto');
  Crypto.encrypt.overloads.forEach(function (ov) {
    ov.implementation = function () {
      var out = ov.apply(this, arguments);
      console.log('encrypt(' + JSON.stringify(arguments) + ') = ' + out);
      return out;
    };
  });
});
```

Native hook — intercepting a JNI export or libc call:

```javascript
var addr = Module.findExportByName('libnative.so', 'Java_com_victim_Native_check');
Interceptor.attach(addr, {
  onEnter: function (args) { this.in = args[2].readCString(); },
  onLeave: function (retval) {
    console.log('check(' + this.in + ') = ' + retval);
    retval.replace(ptr(1));
  }
});
```

Common one-shots: dump every Java class (`Java.enumerateLoadedClasses`), trace constructors (`$init`), watch `okhttp3.CertificatePinner.check` for [[ssl-pinning-bypass]], hook `dalvik.system.DexClassLoader` to capture decrypted DEX for [[apk-unpacking]].

Useful companions:
- `frida-trace -U -j 'com.victim.*!*'` — generate stub handlers for every method in a class
- `objection` — Frida wrapper with one-line root/pinning bypass and memory dumping
- `r2frida` — radare2 connected to a Frida session for live native debugging

## Detection and defence
- Scan `/proc/self/maps` for `frida-agent`/`gum-js-loop`, check ports 27042/27043
- Detect `gadget` library by name; rename + early-load to evade
- TLS pin server certs and verify with native code that hooks itself for integrity
- Layer with [[apk-anti-debug]]; assume any single check is defeated and combine many
- Server-side: short-lived tokens + Play Integrity binding so a hooked client cannot replay

## References
- [Frida docs](https://frida.re/docs/android/) — Android setup
- [Frida JavaScript API](https://frida.re/docs/javascript-api/) — `Java`, `Interceptor`, `Memory`
- [Objection](https://github.com/sensepost/objection) — runtime mobile toolkit
