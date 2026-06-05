---
title: Android source review methodology
slug: android-source-review-methodology
aliases: [android-source-audit, android-whitebox]
---

{% raw %}

> **TL;DR:** An Android source audit is a methodology, not a checklist: manifest-first → exported-surface triage → trust boundaries → sinks. Five things drive 80% of findings — exported components, deep links/scheme handlers, WebViews, content providers, and IPC. This note is the order in which to walk a project; deeper sinks live in the linked notes.

## Inputs
- `AndroidManifest.xml` (the trust map).
- `build.gradle(.kts)` + `gradle.properties` — minSdk, targetSdk, dependencies, signing.
- `src/main/java/` and `src/main/kotlin/` — application code.
- `src/main/jni/` or `cpp/` — native code (see [[jni-native-bridge-audit]]).
- `res/xml/` — network security config, deep links.
- `proguard-rules.pro` / `rules.pro`.

## Step 1 — manifest triage

Build a one-page table:

| Component | Exported? | Permission gate? | Intent filters? |
|---|---|---|---|
| Activity X | yes | none | VIEW + custom scheme |
| Service Y | yes | signature | — |
| Provider Z | yes | none | `grantUriPermissions=true` |
| Receiver R | yes | none | BOOT_COMPLETED |

Greps:
```bash
xmllint --xpath '//*[@android:exported="true" or starts-with(local-name(),"intent-filter")]' \
  --shell AndroidManifest.xml
grep -E 'android:exported|android:permission|android:grantUriPermissions|android:pathPattern' AndroidManifest.xml
```

The map *is* the attack surface. Anything `exported=true` with no permission gate is an entry point.

## Step 2 — `targetSdk`, `minSdk`, network config
- `targetSdk` ≥ 31 → `android:exported` must be explicit on receivers/services with intent-filters.
- `minSdk` < 24 → cleartext HTTP allowed by default; check `network_security_config.xml`.
- `usesCleartextTraffic="true"` — flag.
- Network security config — does it pin? Does it allow user-installed CAs? See [[mobile-cert-pinning-source-audit]].

```bash
find . -name 'network_security_config.xml'
```

## Step 3 — exported components, in priority order

1. **Content providers** — see [[android-content-provider-audit]]. `grantUriPermissions=true` is the loudest tell.
2. **Activities with deep-link intent filters** — see [[android-deeplink-source-audit]].
3. **Services** — exported services are RPC endpoints; audit `onBind` / `onStartCommand` / messengers.
4. **Receivers** — exported broadcast receivers receive untrusted intents.

Source-side grep:
```bash
grep -rn 'getIntent()\.getData\|getStringExtra\|getParcelableExtra' src/
grep -rn 'startActivity(\|startService(\|sendBroadcast(' src/
```

## Step 4 — WebViews
See [[android-webview-audit]]. Grep:
```bash
grep -rn 'setJavaScriptEnabled\|addJavascriptInterface\|setAllowFileAccess\|setAllowFileAccessFromFileURLs\|setAllowUniversalAccessFromFileURLs' src/
```

## Step 5 — JNI bridge
Even if you only review Java/Kotlin, mark every `native` method and follow into `cpp/`. See [[jni-native-bridge-audit]]. Grep:
```bash
grep -rn 'native ' src/main/java src/main/kotlin
ls src/main/cpp/ src/main/jni/ 2>/dev/null
```

## Step 6 — secrets and crypto
```bash
grep -rnE 'AES/|DES/|RC4/|MD5\.|SHA-1\.|Cipher\.getInstance|SecretKeySpec|IvParameterSpec' src/
grep -rnE 'BuildConfig\.\w*KEY|"AKIA|"sk_live_|"-----BEGIN' src/ res/
```

See [[android-keystore-and-crypto-audit]] for what good looks like.

## Step 7 — IPC and intent handling
See [[android-ipc-and-intent-source-audit]]. Specifically:
- `PendingIntent.FLAG_MUTABLE` without explicit `setPackage()`.
- `Intent#setComponent(null)` followed by `startActivity` (intent redirection).
- Implicit intents for sensitive actions.

## Step 8 — local storage and providers
```bash
grep -rn 'MODE_WORLD_READABLE\|MODE_WORLD_WRITEABLE\|openFileOutput\|getExternalFilesDir\|getExternalStorageDirectory' src/
grep -rn 'SharedPreferences\|EncryptedSharedPreferences\|Room\.databaseBuilder\|SQLiteOpenHelper' src/
```

See [[mobile-client-storage-source-audit]].

## Step 9 — auth and tokens
```bash
grep -rn 'OkHttpClient\|Retrofit\|HttpsURLConnection' src/
grep -rn 'addInterceptor\|Authorization\|Bearer ' src/
```

See [[mobile-auth-token-handling-audit]].

## Step 10 — ProGuard / R8

ProGuard rules are leak signals: if `keep` includes a class name that looks like an SDK or a credential helper, that's a hint of importance and an audit target.

```bash
grep -E 'keep|dontobfuscate' proguard-rules.pro
```

## Output

For each finding:
- **Where** — `MainActivity.kt:142`.
- **What** — exported activity reads user-controlled URI, passes to WebView without origin check.
- **Why bad** — file:// scheme bypass leads to local file read.
- **Repro** — adb `am start -W -a android.intent.action.VIEW -d 'file:///data/data/<pkg>/files/...' <pkg>/.MainActivity`.

## What this complements
- Attacker-side reversing tools live under existing mobile/ notes (apk-unpacking, frida-hook, jeb-decompiler).
- This methodology is for the **whitebox** angle — when you have the source repo.

## References
- [Android — secure your app docs](https://developer.android.com/topic/security/best-practices)
- [Mobile Application Security Testing Guide (MASTG)](https://mas.owasp.org/MASTG/)
- [Android Application Secure Design / Secure Coding Guidebook](https://www.jssec.org/dl/android_securecoding_en.pdf)
- See also: [[android-ipc-and-intent-source-audit]], [[android-webview-audit]], [[android-content-provider-audit]], [[android-deeplink-source-audit]], [[jni-native-bridge-audit]], [[android-keystore-and-crypto-audit]], [[mobile-cert-pinning-source-audit]]

{% endraw %}
