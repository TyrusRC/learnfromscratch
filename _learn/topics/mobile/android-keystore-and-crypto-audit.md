---
title: Android Keystore and crypto — source audit
slug: android-keystore-and-crypto-audit
aliases: [android-keystore-audit, android-crypto-audit]
---

{% raw %}

> **TL;DR:** Android Keystore stores keys in hardware where supported (TEE / StrongBox). Source-audit risks: keys stored outside Keystore (raw bytes in SharedPreferences), AES-GCM with IV reuse, ECB mode anywhere, hash-based password checks with MD5/SHA1, key purposes too broad, and missing biometric ACLs on sensitive operations. Companion to [[android-source-review-methodology]] and [[mobile-client-storage-source-audit]].

## Where to start

```bash
grep -rnE 'KeyStore\.getInstance|KeyGenParameterSpec|KeyPairGenerator\.getInstance' src/
grep -rnE 'Cipher\.getInstance' src/
grep -rnE 'SecretKeySpec|IvParameterSpec|GCMParameterSpec' src/
grep -rnE 'MessageDigest\.getInstance' src/
grep -rnE 'BiometricPrompt|FingerprintManager' src/
grep -rnE '"AndroidKeyStore"' src/
```

## Pattern 1 — key material *not* in Keystore

Bad — raw bytes derived from PBKDF2, then stored:
```kotlin
val sp = ctx.getSharedPreferences("vault", MODE_PRIVATE)
sp.edit().putString("aesKey", Base64.encodeToString(rawKey, NO_WRAP)).apply()
```

Or worse — hardcoded:
```kotlin
private val KEY = "ThisIsMySecretKey".toByteArray()
```

Good — generated inside Keystore, never exits hardware:
```kotlin
val spec = KeyGenParameterSpec.Builder("vault.aes",
    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
    .setUserAuthenticationRequired(true)
    .setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
    .setIsStrongBoxBacked(true)        // require StrongBox where available
    .build()
val kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
kg.init(spec); kg.generateKey()
```

Audit grep: any `SecretKeySpec(rawBytes, "AES")` is a red flag — the key didn't come from Keystore.

## Pattern 2 — AES-GCM IV reuse

GCM's 96-bit IV must never repeat for the same key. Two patterns that get you:
```kotlin
val iv = ByteArray(12)              // BAD: all-zero IV
val iv = "0123456789ab".toByteArray()   // BAD: constant
```

For Keystore-managed AES-GCM the *recommended* pattern is to *let Cipher generate the IV* and read it back:

```kotlin
val cipher = Cipher.getInstance("AES/GCM/NoPadding")
cipher.init(Cipher.ENCRYPT_MODE, key)
val iv = cipher.iv                  // unique per init
```

For AES-CBC, a `SecureRandom`-derived IV is mandatory; static IV = catastrophic.

## Pattern 3 — ECB

Anything `AES/ECB/...` is wrong outside of single-block primitives. Easy grep:
```bash
grep -rn 'AES/ECB\|DES/ECB' src/
```

If you find ECB used to encrypt anything longer than 16 bytes, escalate.

## Pattern 4 — broken hashes

```bash
grep -rn 'MessageDigest\.getInstance("MD5"\|MessageDigest\.getInstance("SHA-1"\|MessageDigest\.getInstance("SHA1"' src/
```

Both should never appear in password handling, signature checks, or HMAC keys. SHA-1 in TLS pinning or git-style content addressing is acceptable for non-security uses; flag for context.

For password hashing, expect `BCrypt`, `Argon2`, or `PBKDF2WithHmacSHA256` with ≥100k iterations.

## Pattern 5 — key purposes too broad

`KeyGenParameterSpec.Builder` takes a purpose bitmask. Common bad: `PURPOSE_ENCRYPT or PURPOSE_DECRYPT or PURPOSE_SIGN or PURPOSE_VERIFY` — overlap surface. Audit:

```bash
grep -rn 'PURPOSE_' src/
```

Each key should have one purpose. Sign keys signed should never decrypt.

## Pattern 6 — `setUserAuthenticationRequired(false)` on sensitive keys

If a key encrypts the user's vault, it should require biometric/credential auth at decrypt time.

```kotlin
.setUserAuthenticationRequired(true)
.setUserAuthenticationParameters(0, AUTH_BIOMETRIC_STRONG)
```

Setting it false (or setting a long auth-validity duration) means a malicious process with the user's lock state recently active gets free decrypts.

Audit:
```bash
grep -rn 'setUserAuthenticationRequired\|setUserAuthenticationValidityDuration' src/
```

## Pattern 7 — biometric prompt without crypto binding

Bad:
```kotlin
BiometricPrompt(activity, executor, callback).authenticate(promptInfo)
if (success) decryptWithoutBinding(blob)
```

Good — bind the cipher to the prompt:
```kotlin
val cipher = ... ; cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))
prompt.authenticate(promptInfo, CryptoObject(cipher))
// onAuthenticationSucceeded → result.cryptoObject.cipher.doFinal(blob)
```

The bound variant requires successful biometric per use of the cipher; the unbound variant just shows a dialog.

## Pattern 8 — `KeyInfo.isInsideSecureHardware()` not checked

Apps that *require* hardware-backed keys should check:
```kotlin
val factory = SecretKeyFactory.getInstance(key.algorithm, "AndroidKeyStore")
val info = factory.getKeySpec(key, KeyInfo::class.java) as KeyInfo
require(info.isInsideSecureHardware) { "software fallback unacceptable" }
```

Without this check, a device without TEE silently downgrades to software keystore — same API, much weaker storage.

## Pattern 9 — key attestation

For high-assurance flows (banking, government IDs) you can require remote-attestable keys: `setAttestationChallenge(challenge)` on the spec, then send the attestation certificate chain to your server for verification against Google's root.

```bash
grep -rn 'setAttestationChallenge\|getCertificateChain' src/
```

Absence isn't bad; presence with no server-side verification is.

## EncryptedSharedPreferences and Jetpack Security

Jetpack Security (`androidx.security:security-crypto`) provides `EncryptedSharedPreferences` and `EncryptedFile`. Keys are managed inside Keystore via a master key.

```bash
grep -rn 'EncryptedSharedPreferences\|EncryptedFile\|MasterKeys\|MasterKey\.' src/
```

Audit:
- `MasterKey.Builder(...).setUserAuthenticationRequired(true)` for sensitive vaults.
- Library version current (older versions had vulnerabilities — track CVEs).

## Source-audit checklist
- [ ] All long-lived keys are `AndroidKeyStore`-backed.
- [ ] No raw `SecretKeySpec(bytes, "AES")` for app secrets.
- [ ] No `AES/ECB/...`.
- [ ] No constant IVs.
- [ ] No MD5 / SHA-1 used for password or signature.
- [ ] `setUserAuthenticationRequired(true)` on keys gating sensitive data.
- [ ] BiometricPrompt uses CryptoObject binding for decrypt.
- [ ] `isInsideSecureHardware` enforced where the threat model requires it.

## References
- [Android Keystore system](https://developer.android.com/training/articles/keystore)
- [Jetpack Security](https://developer.android.com/topic/security/data)
- [OWASP MASTG — cryptography](https://mas.owasp.org/MASTG/0x04g-Testing-Cryptography/)
- See also: [[android-source-review-methodology]], [[mobile-client-storage-source-audit]], [[mobile-auth-token-handling-audit]]

{% endraw %}
