---
title: AndroidManifest analysis
slug: android-manifest-analysis
---

> **TL;DR:** The manifest is the app's declared attack surface — permissions, exported components, intent filters, deeplinks, backup and debug flags. Read it before touching the bytecode.

## What it is
`AndroidManifest.xml` is the metadata document Android reads at install/launch to wire up the app: required permissions, declared components, supported intents, network security config, backup behaviour and runtime flags. In the APK it is stored as Android Binary XML (AXML) and must be decoded with `apktool`, `aapt2 dump`, or `jadx` before reading.

## Preconditions / where it applies
- Any APK or AAB you have on disk
- Useful even without source — exported surface is fully described here
- Combined with smali / decompiled Java to confirm whether dangerous declarations are actually reachable

## Technique
Decode then grep the high-signal attributes.

```bash
apktool d target.apk -o out/ -s          # -s keeps classes.dex untouched
# or
aapt2 dump xmltree target.apk --file AndroidManifest.xml
```

Triage checklist:

```bash
# Debug + backup posture
grep -E 'android:debuggable|allowBackup|usesCleartextTraffic|networkSecurityConfig' \
  out/AndroidManifest.xml

# Exported attack surface (see [[android-components]])
grep -E 'exported="true"|<intent-filter|<data ' out/AndroidManifest.xml

# Dangerous permissions
grep '<uses-permission' out/AndroidManifest.xml | sort -u

# Provider grant flags
grep -E 'grantUriPermissions|pathPermission' out/AndroidManifest.xml
```

What to flag:
- `android:debuggable="true"` → attach `jdb` / Frida without root, dump memory, [[apk-anti-debug]] often missing
- `android:allowBackup="true"` (default pre-API 31) → `adb backup` exfiltrates private data on debuggable / older devices
- `android:usesCleartextTraffic="true"` or permissive `network_security_config.xml` → trivial MITM, related to [[ssl-pinning-bypass]]
- `android:exported="true"` on activities/services/receivers/providers → IPC reach, see [[android-deeplink-abuse]]
- `<intent-filter>` with `<data android:scheme=...>` → deeplink entry points
- Custom permissions defined at `normal` protection level when they gate sensitive components
- `targetSdkVersion` low enough to disable scoped storage / runtime permission prompts

For App Links also fetch `https://<host>/.well-known/assetlinks.json` and confirm package + SHA-256 cert match.

## Detection and defence
- Set `exported="false"` by default; explicit `exported` is mandatory from API 31
- `allowBackup="false"` and ship a `backup_rules.xml` excluding secrets
- `debuggable="false"` in release builds; CI gate on aapt dump
- Use Network Security Config to pin or restrict cleartext, do not toggle at runtime
- MobSF / Drozer / `apkleaks` for automated manifest scoring

## References
- [App Manifest Overview](https://developer.android.com/guide/topics/manifest/manifest-intro) — official reference
- [HackTricks – AndroidManifest.xml](https://book.hacktricks.wiki/en/mobile-pentesting/android-app-pentesting/index.html) — auditing tips
- [Network Security Config](https://developer.android.com/privacy-and-security/security-config) — cleartext + pinning policy
