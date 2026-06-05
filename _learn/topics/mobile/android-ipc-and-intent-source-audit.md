---
title: Android IPC and Intent — source audit
slug: android-ipc-and-intent-source-audit
aliases: [android-ipc-audit, android-intent-source-audit]
---

{% raw %}

> **TL;DR:** Android IPC happens through Intents, Messengers, AIDL services, PendingIntents, and bound services. The high-value bugs from source: exported components without permission gates, intent-redirection patterns (`setComponent(null)`), PendingIntent mutability, and trust of `getIntent().getData()` without an origin check. Companion to [[android-source-review-methodology]] and the attacker-side [[android-intent-redirection]].

## Where IPC enters the source

```bash
# Entry points: untrusted Intent in
grep -rn 'getIntent()\.getData\|getIntent()\.getStringExtra\|getIntent()\.getParcelableExtra\|getIntent()\.getExtras' src/
grep -rn 'onCreate\(.*Intent\|onReceive\(.*Intent\|onStartCommand\(.*Intent\|onBind\(.*Intent' src/
grep -rn 'Messenger\|AIDL' src/
```

For *every* hit, ask: is the component exported? Is there a permission check before the data is used?

## Exported components without permission gates

A `Manifest.permission` declaration on an exported component is the only enforced gate. Without it, *any* installed app can deliver an intent to that component.

```xml
<!-- bad -->
<activity android:name=".ImportActivity" android:exported="true">
  <intent-filter><action android:name="android.intent.action.VIEW"/></intent-filter>
</activity>

<!-- good -->
<activity android:name=".ImportActivity" android:exported="true"
          android:permission="com.example.permission.IMPORT">
  <intent-filter><action android:name="android.intent.action.VIEW"/></intent-filter>
</activity>
```

`signature`-level permissions are the strongest non-system option (only apps signed by the same key can call).

## The intent-redirection pattern

A "redirector" reads a payload Intent from `getIntent().getParcelableExtra("forward")` and calls `startActivity(forwardIntent)` without sanity-checking the target. An attacker delivers a payload Intent targeting an *unexported* component — and from inside your trusted process, it now runs:

```kotlin
val target = intent.getParcelableExtra<Intent>("next")
startActivity(target)            // BAD — attacker controls target
```

Greps:
```bash
grep -rnE 'getParcelableExtra\([^)]*\).*startActivity\(' src/
grep -rn 'setComponent\(null\)\|component = null' src/
```

Fix: refuse intents whose component points outside your own package, or compare to an allowlist of permitted targets.

## PendingIntent traps

Default mutability rules changed across API levels:
- API 31+ requires explicit `FLAG_IMMUTABLE` or `FLAG_MUTABLE`.
- `FLAG_MUTABLE` PendingIntents with an unset target (`setComponent(null)`, empty action) can be hijacked by another process that fills the gap.

```bash
grep -rn 'PendingIntent\.getActivity\|PendingIntent\.getBroadcast\|PendingIntent\.getService' src/ -B1 -A3
```

Look for:
- `FLAG_MUTABLE` *with* `Intent()` having no `setPackage` or `setComponent`.
- Notifications that hand the PendingIntent to a system service with `FLAG_MUTABLE`.

## Implicit broadcasts for sensitive data

Sending a broadcast without `setPackage()` makes it implicit — every receiver registered for that action gets the data.

```kotlin
val i = Intent("com.example.GOT_TOKEN")
i.putExtra("token", token)
context.sendBroadcast(i)       // BAD — any app with the receiver can see
```

Fix: `setPackage(context.packageName)` to keep it in-process, or use `LocalBroadcastManager`, or a direct method call.

## AIDL services and bound services

Bound services are RPC over an interface. The threats:
- `onBind` not enforcing `checkCallingPermission`.
- Returning a binder that exposes more methods than intended.
- `Binder#getCallingUid()` checks done *after* sensitive state is read.

```bash
find . -name '*.aidl'
grep -rn 'onBind\|asInterface\|checkCallingPermission\|getCallingUid' src/
```

Pattern to flag:
```java
public IBinder onBind(Intent intent) {
    return mBinder;     // no permission check
}
```

## Messengers
Messengers wrap a Handler. The Handler receives `Message` from any caller; data is in `Message.obj` or `getData()`.

```bash
grep -rn 'new Messenger\(\|handleMessage\(Message' src/
```

Audit `handleMessage` — treat `msg.obj` and `msg.getData()` as fully untrusted.

## Slice and AppWidget providers

Slice providers (`androidx.slice.SliceProvider`) and AppWidget providers handle untrusted URIs and intents respectively; same trust rules.

## Source-audit checklist
- [ ] Every `exported=true` has either `permission=` or comes from an `intent-filter` you intended.
- [ ] No `getParcelableExtra(...) → startActivity` without target validation.
- [ ] No `FLAG_MUTABLE` PendingIntent with under-specified target.
- [ ] No implicit broadcast carrying sensitive payload.
- [ ] Every bound service `onBind` checks `checkCallingPermission` or compares `getCallingUid` against an allowlist.
- [ ] Every `handleMessage` treats `msg.obj`/`getData()` as attacker-controlled.

## References
- [Android — permissions](https://developer.android.com/guide/topics/permissions/overview)
- [Android — PendingIntent mutability](https://developer.android.com/guide/components/intents-filters#pending-intents)
- [Google — Strandhogg / task-affinity issues (history)](https://android-developers.googleblog.com/)
- See also: [[android-source-review-methodology]], [[android-intent-redirection]], [[android-content-provider-audit]], [[android-deeplink-source-audit]], [[strandhogg-task-affinity]]

{% endraw %}
