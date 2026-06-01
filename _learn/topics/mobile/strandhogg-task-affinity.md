---
title: StrandHogg Android Task-Affinity Hijack
slug: strandhogg-task-affinity
---

> **TL;DR:** Promon's StrandHogg abuses Android `taskAffinity` plus `allowTaskReparenting` so a malicious activity slots itself in front of a legitimate app's task and presents a fake UI when the victim launches the real app.

## What it is
StrandHogg is a task-hijacking technique where a malicious app declares the same `taskAffinity` as a target package. When the target is launched from the home screen, Android's recents/back stack surfaces the attacker's activity instead, enabling phishing overlays, permission re-prompts, or credential capture. The original (2019) variant works without any special permissions; StrandHogg 2.0 (CVE-2020-0096) extends it to runtime activity injection.

## Preconditions / where it applies
- Android 5.0-9 for v1 (no patch), Android up to 9 for v2 before the May 2020 patch
- Target app must allow its launcher activity to be reparented (default) and not pin its task
- Attacker app installed by the victim (no extra runtime permission required for v1)
- Manifest control over `taskAffinity`, `allowTaskReparenting`, and `launchMode`

## Technique
Declare a hijacking activity in the malicious app's manifest.

```xml
<application android:label="Innocent Game">
  <!-- Same affinity as the target package -->
  <activity
      android:name=".PhishingActivity"
      android:taskAffinity="com.bank.victim"
      android:allowTaskReparenting="true"
      android:excludeFromRecents="true"
      android:launchMode="singleTask"
      android:theme="@style/Theme.Translucent">
    <intent-filter>
      <action android:name="android.intent.action.MAIN" />
    </intent-filter>
  </activity>
</application>
```

At runtime the attacker activity inflates a layout that mimics the target's login screen and forwards captured credentials before calling `finish()` to return control to the genuine activity, masking the intrusion.

## Detection and defence
- App-side: set `android:taskAffinity=""` and `android:launchMode="singleInstance"` on sensitive activities; add `FLAG_ACTIVITY_NEW_TASK` carefully
- App-side: call `ActivityManager.getRunningTasks()` (where still available) or compare `getTaskId()` on resume to detect reparenting
- Detection: Play Protect and MDM rules flag apps that declare another package's affinity; static review of `AndroidManifest.xml` catches the pattern pre-release

## References
- [Promon StrandHogg advisory](https://promon.io/security-news/strandhogg) — original disclosure with PoC video
- [Android Security Bulletin May 2020 (CVE-2020-0096)](https://source.android.com/docs/security/bulletin/2020-05-01) — StrandHogg 2.0 patch notes

See also: [[android-components]], [[android-manifest-analysis]].
