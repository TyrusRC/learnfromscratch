---
title: iOS Keychain and Secure Enclave — source audit
slug: ios-keychain-and-secure-enclave-audit
aliases: [ios-keychain-audit, secure-enclave-audit]
---

{% raw %}

> **TL;DR:** iOS Keychain stores credentials in encrypted form, with policy controlled by the `kSecAttrAccessible` constant and (optionally) `kSecAccessControl` flags. Source-audit risks: too-permissive accessible classes (background-readable secrets), no biometric ACL, sharing keychain across an app group with unverified apps, and `SecKeyCreateRandomKey` keys that *aren't* Secure-Enclave-bound. Companion to [[ios-source-review-methodology]] and [[android-keystore-and-crypto-audit]].

## The map

Every keychain item carries:
- `kSecAttrService` — your namespace key.
- `kSecAttrAccount` — usually the user identifier.
- `kSecValueData` — the encrypted blob.
- `kSecAttrAccessible` — when can it be read.
- `kSecAccessControl` — biometric / device-passcode gates.
- `kSecAttrSynchronizable` — iCloud sync flag.
- `kSecAttrAccessGroup` — for sharing.

```bash
grep -rn 'SecItemAdd\|SecItemCopyMatching\|SecItemUpdate\|SecItemDelete' .
grep -rn 'kSecAttrAccessible\|kSecAccessControl\|kSecAttrSynchronizable\|kSecAttrAccessGroup' .
```

## The `kSecAttrAccessible` ladder (most to least secure)

| Constant | When readable |
|---|---|
| `WhenPasscodeSetThisDeviceOnly` | Device unlocked; device has a passcode; not on backups |
| `WhenUnlockedThisDeviceOnly` | Device unlocked; not on backups |
| `WhenUnlocked` | Device unlocked; restorable to a new device |
| `AfterFirstUnlockThisDeviceOnly` | After first unlock after boot (background tasks need this); not on backups |
| `AfterFirstUnlock` | Same; restorable |
| `Always` *(deprecated)* | Always — even before first unlock |
| `AlwaysThisDeviceOnly` *(deprecated)* | Same; not restorable |

The bug pattern:
```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "vault",
    kSecAttrAccount as String: user,
    kSecValueData as String: data,
    kSecAttrAccessible as String: kSecAttrAccessibleAlways    // BAD
]
SecItemAdd(query as CFDictionary, nil)
```

`kSecAttrAccessibleAlways` survives reboot before passcode entry → anything reading at that window gets the secret. Use `WhenUnlocked` or stricter.

## `kSecAttrAccessControl` for biometrics

```swift
let acl = SecAccessControlCreateWithFlags(nil,
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    [.biometryCurrentSet],          // requires biometry; rotates if user enrols new fingerprint
    nil)!

let query: [String: Any] = [
    ...,
    kSecAttrAccessControl as String: acl
]
```

Flags worth knowing:
- `.biometryAny` — Face ID or Touch ID, including future enrollments.
- `.biometryCurrentSet` — invalidates if user adds/removes a finger or face.
- `.devicePasscode` — passcode fallback.
- `.userPresence` — biometric or passcode.

For sensitive vaults prefer `.biometryCurrentSet` so a coerced enrolment doesn't quietly unlock the vault.

## Secure Enclave keys

```swift
let access = SecAccessControlCreateWithFlags(nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    .privateKeyUsage, nil)!

let attrs: [String: Any] = [
    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
    kSecAttrKeySizeInBits as String: 256,
    kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,    // SE-bound
    kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: "com.example.signing",
        kSecAttrAccessControl as String: access
    ]
]

var error: Unmanaged<CFError>?
let key = SecKeyCreateRandomKey(attrs as CFDictionary, &error)!
```

Audit:
- `kSecAttrTokenID = kSecAttrTokenIDSecureEnclave` — without this the private key lives in software.
- `kSecAttrAccessControl` includes `.privateKeyUsage` — required for SE keys.
- Operations use `SecKeyCreateSignature` / `SecKeyCreateDecryptedData` (SE-supported); falling back to `SecKeyCreateEncryptedData` for RSA/AES outside SE leaks the path.

## Sharing keychain across an app group

```swift
kSecAttrAccessGroup as String: "ABCDE12345.com.example.shared"
```

Trust model: all apps signed by your team prefix can read. Bug class: an old, deprecated companion app from the same team still in the app group, with weaker code, leaks the keychain item to attackers.

Audit:
- `keychain-access-groups` entitlement lists only currently-supported bundle IDs.
- No `.shared` access group on items that don't need cross-app reach.

## `kSecAttrSynchronizable`

Setting this to `true` syncs the item via iCloud Keychain. Two concerns:
- Item is now accessible on the user's other devices — sometimes desired, sometimes not.
- Apple's iCloud Keychain has its own threat model; for high-assurance items prefer device-only storage.

## Common Keychain mistakes (greppable)

```bash
# Storing tokens in UserDefaults (the bug)
grep -rn 'UserDefaults\.standard\.set.*token\|UserDefaults\.standard\.set.*password' .

# Storing tokens in plain files
grep -rn 'documentDirectory.*token\|cachesDirectory.*password' .

# Always-on accessible
grep -rn 'kSecAttrAccessibleAlways\|kSecAttrAccessibleAlwaysThisDeviceOnly' .
```

## Wiping keychain on logout
A subtle bug: app deletes UserDefaults state on logout but leaves Keychain items intact. On reinstall, Keychain survives (across app removals on some iOS versions) and the next user inherits secrets.

Audit:
```bash
grep -rn 'logout\|signOut\|clearCredentials' .
```
Verify they `SecItemDelete` the relevant queries.

## Source-audit checklist
- [ ] No secret in UserDefaults or plain file storage.
- [ ] `kSecAttrAccessible` is `WhenUnlockedThisDeviceOnly` or stricter for user secrets.
- [ ] Biometric items use `.biometryCurrentSet`.
- [ ] Long-lived keys are Secure-Enclave-bound (`kSecAttrTokenIDSecureEnclave`).
- [ ] Access groups limited to currently-supported bundle IDs.
- [ ] Sync flag off unless cross-device is required.
- [ ] Logout flow wipes the relevant keychain entries.

## References
- [Apple — Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Apple — Secure Enclave](https://support.apple.com/guide/security/sec59b0b31ff/web)
- [OWASP MASTG — iOS data storage](https://mas.owasp.org/MASTG/0x06d-Testing-Data-Storage/)
- See also: [[ios-source-review-methodology]], [[ios-keychain-extraction]], [[mobile-client-storage-source-audit]]

{% endraw %}
