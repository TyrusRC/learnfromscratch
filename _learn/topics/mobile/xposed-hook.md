---
title: Xposed hooks
slug: xposed-hook
---

> **TL;DR:** Xposed (and the modern LSPosed fork) hooks Java methods at the Zygote/ART level so every newly forked app inherits your interceptions — persistent, system-wide, no Frida daemon.

## What it is
Xposed Framework patches the Android runtime so user-written modules can replace any Java method before/after execution. Unlike [[frida-hook]] (per-process, dynamic, JS), Xposed modules are APKs shipped with `XposedBridge.jar`, loaded by the framework into every process. The original Xposed died at Android 8; the actively maintained successors are EdXposed and LSPosed (Magisk-based, Android 8.1–14+).

## Preconditions / where it applies
- Rooted device with Magisk
- LSPosed module installed via Magisk Modules; Riru or Zygisk backend depending on target API
- Module APK declares `xposedminversion`, `xposedmodule=true` and an entry class implementing `IXposedHookLoadPackage`

## Technique
A minimal LSPosed module that bypasses a root check across every app:

```java
// AndroidManifest.xml meta-data
//   <meta-data android:name="xposedmodule" android:value="true"/>
//   <meta-data android:name="xposeddescription" android:value="Root cloak"/>
//   <meta-data android:name="xposedminversion" android:value="93"/>
// assets/xposed_init  contains: com.example.cloak.HookEntry

public class HookEntry implements IXposedHookLoadPackage {
  public void handleLoadPackage(final LoadPackageParam lp) {
    if (!lp.packageName.equals("com.victim")) return;
    XposedHelpers.findAndHookMethod(
      "com.victim.security.RootCheck", lp.classLoader, "isDeviceRooted",
      new XC_MethodReplacement() {
        protected Object replaceHookedMethod(MethodHookParam p) { return false; }
      });
  }
}
```

Install with `pm install module.apk`, enable in the LSPosed manager, scope to the target package, force-stop the app and relaunch. The hook is live in every fresh process fork from Zygote.

When to pick Xposed over Frida:
- You want persistence across reboots and the user just opens the app normally
- The app aggressively detects Frida (`gum-js-loop` thread, port 27042) but does not look for LSPosed
- You need system-wide hooks (e.g. PackageManager, Settings) without re-injecting

When Frida wins: rapid iteration, scriptable JS, native `Interceptor`, no APK build, easier code-share. The two coexist — many testers use LSPosed for stable platform hooks and Frida for per-session exploitation.

Anti-detection on the target side ([[apk-anti-debug]]):

- Scan loaded classes for `de.robv.android.xposed.XposedBridge`
- Check stack frames for `XposedBridge.invokeOriginalMethodNative`
- `PackageManager.getInstalledPackages` for `org.lsposed.manager`, `de.robv.android.xposed.installer`
- `/proc/self/maps` for `liblspd.so`, `libriru_*.so`

LSPosed counter-hides via Zygisk; combine with Magisk Denylist to keep the target from seeing Magisk too.

## Detection and defence
- Check for Xposed/LSPosed classes and native libs at startup, but assume the check itself can be hooked
- Verify app signature + DEX checksum from native code that is itself integrity-checked
- Use Play Integrity API and treat any client signal as advisory
- Server-side rate-limiting and anomaly detection catch the abuse even when client hooks succeed

## References
- [LSPosed](https://github.com/LSPosed/LSPosed) — modern Xposed implementation
- [Xposed API docs](https://api.xposed.info/reference/de/robv/android/xposed/XposedHelpers.html) — `findAndHookMethod` reference
- [HackTricks – Android pentesting](https://book.hacktricks.wiki/en/mobile-pentesting/android-app-pentesting/index.html) — hooking workflow
