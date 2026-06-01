---
title: SSL pinning bypass
slug: ssl-pinning-bypass
---

> **TL;DR:** Apps pin server certs/keys so a Burp CA on the device is still rejected; hook the verification code (Frida, smali patch, or platform config) so traffic flows through your proxy.

## What it is
Certificate pinning binds an app to a specific server certificate, public key or CA. The TLS handshake still completes against any trusted CA, but the app then compares the peer chain against an embedded pin and aborts on mismatch. To MITM, you either prevent the pin check from running or rewrite it to accept your proxy CA. This is the universal first step in mobile app testing — almost everything else assumes you can read the network traffic.

## Preconditions / where it applies
- Android 7+ requires user-installed CAs to be opted in via `network_security_config.xml`; without that, even unpinned apps reject Burp on stock targets
- Rooted device (push CA to system store) or app-level Network Security Config override (debuggable build) or Magisk module like `MagiskTrustUserCerts`
- Frida-capable target (see [[frida-hook]]) or willingness to repack via [[apk-reverse-tools]]

## Technique
**1. Install your proxy CA as a system root.**

```bash
# Convert Burp CA to PEM, hash-name it, push to system store
openssl x509 -inform der -in cacert.der -out cacert.pem
HASH=$(openssl x509 -inform pem -subject_hash_old -in cacert.pem | head -1)
adb root && adb remount
adb push cacert.pem /system/etc/security/cacerts/$HASH.0
adb shell chmod 644 /system/etc/security/cacerts/$HASH.0
adb reboot
```

On Android 14+, system store is in `/apex/com.android.conscrypt/cacerts/`; use a Magisk module that bind-mounts it.

**2. Identify the pinning implementation.**

- OkHttp: `okhttp3.CertificatePinner.check`
- Custom `X509TrustManager.checkServerTrusted`
- `javax.net.ssl.HttpsURLConnection.setDefaultHostnameVerifier`
- Conscrypt / BoringSSL native pinning (TrustKit, Google Cronet)
- Flutter: pin lives in the Dart `libapp.so`, not the Java side — needs native hook
- React Native: in JS bundle (`react-native-pinch`, custom fetch wrappers)

**3. Frida bypass — universal hook.**

```javascript
Java.perform(function () {
  // OkHttp CertificatePinner
  try {
    var CP = Java.use('okhttp3.CertificatePinner');
    CP.check.overload('java.lang.String', 'java.util.List').implementation = function(){};
  } catch (e) {}

  // X509TrustManager
  var TM = Java.use('javax.net.ssl.X509TrustManager');
  var SSLContext = Java.use('javax.net.ssl.SSLContext');
  var TrustManagers = Java.registerClass({
    name: 'p.TM', implements: [TM],
    methods: {
      checkClientTrusted: function () {},
      checkServerTrusted: function () {},
      getAcceptedIssuers: function () { return []; }
    }
  });
  SSLContext.init.overload(
    '[Ljavax.net.ssl.KeyManager;', '[Ljavax.net.ssl.TrustManager;', 'java.security.SecureRandom'
  ).implementation = function (k, t, r) {
    return this.init(k, [TrustManagers.$new()], r);
  };
});
```

`objection --gadget com.victim explore` then `android sslpinning disable` runs an equivalent built-in script.

**4. Static repack fallback.** When Frida is blocked, use [[apk-reverse-tools]] to add `network_security_config.xml` trusting `user` certs, set `debuggable=true`, neuter the pin method in smali, then rebuild + sign. For iOS, see [[ios-reverse-overview]] (SSL Kill Switch 2 / Frida hook on `SecTrustEvaluateWithError`).

**5. Native pinning (Flutter, Cronet).** Hook `SSL_CTX_set_verify` / `SSL_set_verify` or `ssl_crypto_x509_session_verify_cert_chain` in `libssl.so` / `libapp.so`, force the verify mode to `SSL_VERIFY_NONE` and return success.

## Detection and defence
- Pin in native code (Flutter, BoringSSL) and integrity-check the `.so` to catch Frida patches
- Combine pinning with channel binding (token bound to TLS exporter) so a MITM cannot replay sessions
- Detect Frida (see [[apk-anti-debug]]) and refuse to start if user CA is in the trust store
- Use App Transport Security on iOS + certificate transparency check server-side
- Treat bypass as inevitable — assume traffic is observable and avoid client-side secrets

## References
- [Frida codeshare – Universal Android SSL pinning bypass](https://codeshare.frida.re/@akabe1/frida-multiple-unpinning/) — community script
- [HackTricks – Android pentesting](https://book.hacktricks.wiki/en/mobile-pentesting/android-app-pentesting/index.html) — pinning bypass notes
- [OWASP MASTG – Network communication](https://mas.owasp.org/MASTG/0x05g-Testing-Network-Communication/) — pinning test cases
