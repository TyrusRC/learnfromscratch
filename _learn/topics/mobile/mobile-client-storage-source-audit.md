---
title: Mobile client storage — source audit
slug: mobile-client-storage-source-audit
aliases: [mobile-storage-audit, client-storage-audit-mobile]
---

{% raw %}

> **TL;DR:** Sensitive data on mobile devices belongs in Keystore (Android) or Keychain (iOS), encrypted at rest, accessible only when the device is unlocked, optionally biometric-gated. Source-audit risks: secrets in SharedPreferences / UserDefaults, world-readable file modes, external storage usage for sensitive data, no encryption-at-rest, and iCloud / Google Drive backup pulling secrets out of the device. Companion to [[android-keystore-and-crypto-audit]] and [[ios-keychain-and-secure-enclave-audit]].

## The trust ladder (most to least secure)

### Android
| Tier | Storage |
|---|---|
| Best | Keystore (key in TEE/StrongBox) + EncryptedSharedPreferences / EncryptedFile |
| OK | SharedPreferences encrypted with Keystore-managed key |
| Risky | SharedPreferences with PBKDF2-derived key (key bytes in memory) |
| Bad | SharedPreferences plain |
| Worst | External storage (`getExternalFilesDir`) plain |

### iOS
| Tier | Storage |
|---|---|
| Best | Keychain with SE-bound keys + biometric ACL |
| OK | Keychain with `WhenUnlockedThisDeviceOnly` |
| Risky | NSData written to NSFileProtectionComplete file in Documents |
| Bad | UserDefaults |
| Worst | Documents/tmp with default protection + iCloud backup on |

## Android greps

```bash
# Plain shared prefs
grep -rn 'getSharedPreferences\|getPreferences' src/

# Encrypted prefs (good signal)
grep -rn 'EncryptedSharedPreferences\|MasterKey\.' src/

# World-mode (deprecated but still seen)
grep -rn 'MODE_WORLD_READABLE\|MODE_WORLD_WRITEABLE' src/

# External storage
grep -rn 'getExternalFilesDir\|getExternalStorageDirectory\|getExternalCacheDir\|Environment\.getExternalStorage' src/

# Room / SQLite
grep -rn 'Room\.databaseBuilder\|SQLiteOpenHelper\|openOrCreateDatabase' src/

# File operations
grep -rn 'openFileOutput\|FileOutputStream\|Files\.write' src/
```

### Findings to flag

- Any `SharedPreferences` write of a "token", "password", "secret", "apikey".
- External storage holding anything that isn't user-generated content.
- `Room` databases unencrypted (look for absence of `SupportFactory(SQLCipher key)`).
- `openFileOutput(..., MODE_PRIVATE)` is *OK* for non-sensitive files; for secrets prefer Keystore-encrypted Files.

## iOS greps

```bash
# UserDefaults
grep -rn 'UserDefaults\.standard\|UserDefaults(suiteName' .

# Documents/tmp/cache directories
grep -rn 'documentDirectory\|cachesDirectory\|temporaryDirectory\|libraryDirectory' .

# Plain file writes
grep -rn 'FileManager\.default\.createFile\|Data\.write\|String\.write' .

# Core Data
grep -rn 'NSPersistentContainer\|NSPersistentStoreDescription\|NSPersistentStoreFileProtectionKey' .

# Realm
grep -rn 'Realm\.Configuration\|Realm(configuration:' .

# Keychain (good signal)
grep -rn 'SecItemAdd\|kSecAttrAccessible' .
```

### Findings to flag

- Any `UserDefaults` write of a credential / token / personal data.
- File writes to Documents/Cache/tmp without `NSFileProtectionComplete` or `CompleteUnlessOpen`.
- Core Data persistent stores without `NSPersistentStoreFileProtectionKey = .complete`.
- Realm databases without `encryptionKey` (Realm supports 64-byte AES key directly).

## NSFileProtection classes

| Class | When readable |
|---|---|
| `.complete` | Only while device is unlocked |
| `.completeUnlessOpen` | Unlocked, or already open at lock time |
| `.completeUntilFirstUserAuthentication` | After first unlock after boot (default) |
| `.none` | Always |

Default is `.completeUntilFirstUserAuthentication`. For high-sensitivity data, override to `.complete`:

```swift
try data.write(to: url, options: [.atomic, .completeFileProtection])
```

## Backup exclusion (iOS)

iOS backs up Documents and Library/Application Support to iCloud/iTunes by default. Exclude per-file:

```swift
var url = ...
var values = URLResourceValues()
values.isExcludedFromBackup = true
try url.setResourceValues(values)
```

Audit secrets directories for explicit exclusion.

## Backup exclusion (Android)

`AndroidManifest.xml`:
```xml
<application
    android:allowBackup="true"           ← default in many templates
    android:fullBackupContent="@xml/backup_rules">
```

```bash
grep -nE 'allowBackup|fullBackupContent|dataExtractionRules' AndroidManifest.xml
```

If `allowBackup="true"` and no rules excluding sensitive directories, the app's private storage is in user's Google Drive backup — including the SharedPreferences XML with that token you stored.

Audit:
- `allowBackup="false"` for highly sensitive apps; or
- `<full-backup-content>` rules that exclude `databases/`, `shared_prefs/`, and Keystore-backed files.
- API 31+ uses `dataExtractionRules` for separate handling of cloud vs device-to-device transfers.

## Memory residency

Secrets in memory linger:
- `String` in JVM/Swift is immutable; you can't reliably zero it.
- Use `CharArray` (Android) / `UnsafeMutableBufferPointer` (iOS) and overwrite after use.
- After authentication, wipe transient buffers.

This is finicky and rarely worth chasing on app-level review — but **flag** for high-assurance contexts (banking, password managers).

## Clipboard

Both platforms ship system-wide pasteboard / clipboard. Anything an app copies is visible to other apps (with system warnings in modern versions). Search for "copy to clipboard" patterns for sensitive data:

```bash
# Android
grep -rn 'ClipboardManager\|setPrimaryClip' src/
# iOS
grep -rn 'UIPasteboard\.general' .
```

## Sample finding template

> `LoginViewModel.kt:48` writes the JWT access token to `SharedPreferences("auth", MODE_PRIVATE)`. With `allowBackup="true"` (Manifest:7) and no `<full-backup-content>` exclusion of `shared_prefs/`, the token is included in Google Drive backups and restorable to a different device. Migrate to `EncryptedSharedPreferences` and exclude `auth.xml` from backup.

## Source-audit checklist
- [ ] No secrets in SharedPreferences / UserDefaults.
- [ ] No secrets in external storage.
- [ ] Encrypted databases (SQLCipher, Realm encryption key, or Keystore-backed).
- [ ] iOS file writes use `.completeFileProtection` for sensitive data.
- [ ] `allowBackup` / backup rules exclude secret directories.
- [ ] Backup exclusion (iOS) for secret directories.
- [ ] Clipboard not used for secrets.

## References
- [Android — Jetpack Security](https://developer.android.com/topic/security/data)
- [Android — Backup of app data](https://developer.android.com/guide/topics/data/autobackup)
- [Apple — Data Protection](https://support.apple.com/guide/security/data-protection-overview-secf6276da8a/web)
- [OWASP MASTG — Data Storage](https://mas.owasp.org/MASTG/0x04d-Testing-Data-Storage/)
- See also: [[android-keystore-and-crypto-audit]], [[ios-keychain-and-secure-enclave-audit]], [[android-source-review-methodology]], [[ios-source-review-methodology]]

{% endraw %}
