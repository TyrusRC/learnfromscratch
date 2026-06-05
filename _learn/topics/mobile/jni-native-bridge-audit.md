---
title: JNI native bridge — source audit
slug: jni-native-bridge-audit
aliases: [jni-audit, native-bridge-audit]
---

{% raw %}

> **TL;DR:** JNI is the boundary between Java/Kotlin and C/C++. Bugs cluster around (1) `GetString*` / `Get*ArrayElements` without matching `Release*` (leaks → DoS or info-disc), (2) raw pointer arithmetic on attacker-influenced sizes (BOF, UAF), (3) `RegisterNatives` of methods that don't validate arguments, (4) JNI calls under a wrong env / thread, (5) opaque `long` handles holding C pointers that Java code can forge. Companion to [[android-source-review-methodology]] and [[native-rce-from-source-review]].

## Map the bridge

```bash
grep -rn 'native ' src/main/java src/main/kotlin
grep -rn 'JNIEXPORT\|RegisterNatives\|Java_' src/main/cpp src/main/jni
```

For each `native` method in Java:
- Find the matching `Java_<pkg>_<cls>_<method>` in C/C++, or the `RegisterNatives` table.
- Read the C side as untrusted: arguments come from attacker-controlled Java callers.

## Pattern 1 — string handling

```c
JNIEXPORT jstring JNICALL Java_com_example_App_hello(JNIEnv *env, jobject thiz, jstring s) {
    const char *cs = (*env)->GetStringUTFChars(env, s, NULL);
    // ...use cs...
    return (*env)->NewStringUTF(env, cs);    // BUG: forgot to Release
}
```

`GetStringUTFChars` may copy or pin — either way, you must `ReleaseStringUTFChars` or the reference leaks. Leaks accumulate; the app eventually OOMs. In severe cases (pinned region) the GC stalls.

`GetStringChars` (UTF-16) and `GetByteArrayElements` have the same rule. Always paired with `Release*`.

## Pattern 2 — array element pointers

```c
jbyte *buf = (*env)->GetByteArrayElements(env, arr, NULL);
jsize  len = (*env)->GetArrayLength(env, arr);
memcpy(dest, buf, len);                         // BUG: dest may be smaller
(*env)->ReleaseByteArrayElements(env, arr, buf, JNI_ABORT);
```

Two classic mistakes:
1. The destination size assumption is wrong → BOF.
2. `JNI_ABORT` vs `0` — `JNI_ABORT` doesn't write changes back; if you mutated `buf` intending it visible to Java, you lost the change.

Prefer `GetByteArrayRegion` / `SetByteArrayRegion` for bounded copy — they're clearer and don't pin.

## Pattern 3 — opaque long handles

```java
private long mNativeHandle;     // pointer-as-long
public void free() { nativeFree(mNativeHandle); mNativeHandle = 0; }
```

```c
JNIEXPORT void JNICALL Java_com_example_App_nativeFree(JNIEnv *env, jobject thiz, jlong h) {
    Ctx *c = (Ctx *)(uintptr_t)h;
    free(c);                                    // BUG: any Java caller can pass any long
}
```

Java code holding the handle can be reflection-poked; attacker can call `nativeFree(0xdeadbeef)` and crash, or worse, free legitimate memory leading to UAF.

Mitigations:
- Validate the handle against a known set (an array, weak refs).
- Add a magic number at the start of the C struct and check it.
- Guard with `synchronized` on the Java side so handle and "alive" flag move together.

## Pattern 4 — `RegisterNatives` and the trust map

```c
static JNINativeMethod methods[] = {
  {"hello",   "(Ljava/lang/String;)Ljava/lang/String;", (void*)Java_..._hello},
  {"hash",    "([B)[B",                                  (void*)Java_..._hash},
};
```

Audit:
- Method signatures match Java signatures exactly. A mismatch can let an attacker passing a `String` reach code expecting a `byte[]` → memory corruption.
- The function pointers actually validate arg types (don't trust the JVM's signature check alone for safety-critical code).

## Pattern 5 — local vs global refs

```c
jobject g = (*env)->NewGlobalRef(env, local);
// ...use g indefinitely...
// BUG: forgot DeleteGlobalRef
```

Or the opposite:
```c
static jclass cls;
// initialised once, used across threads, never NewGlobalRef'd
// → garbage collector can move/free the underlying object
```

Audit:
- Every `NewGlobalRef` paired with `DeleteGlobalRef`.
- Any `static` `jclass`/`jobject` is a global ref.
- `NewLocalRef` not leaked across many JNI calls (local-ref table is bounded; overflow crashes).

## Pattern 6 — `AttachCurrentThread` / `DetachCurrentThread`

Native threads calling Java must attach; failure or omission causes UB.

```c
JavaVM *jvm;                       // saved at OnLoad
void worker(void *_) {
    JNIEnv *env;
    (*jvm)->AttachCurrentThread(jvm, &env, NULL);
    // do work
    (*jvm)->DetachCurrentThread(jvm);   // must run on the same thread
}
```

Common bug: `AttachCurrentThread` without `DetachCurrentThread` → thread keeps env, blocks GC, eventually crashes on thread exit.

## Pattern 7 — `dlopen`-loaded libs and attacker-controlled paths

```c
void *h = dlopen(path_from_java, RTLD_NOW);
```

If `path_from_java` is attacker-controlled (file picker, deep-link parameter), they can load a different `.so` — a private library bundled in their malicious app's installed directory, for example. Pin to a known directory or canonicalise + bound.

## Pattern 8 — third-party native code

`build.gradle` `externalNativeBuild` may pull in NDK modules:

```bash
grep -rn 'externalNativeBuild\|ndkVersion\|stl\|cppFlags' build.gradle build.gradle.kts
ls src/main/cpp/CMakeLists.txt 2>/dev/null
```

For each native dep:
- Version — outdated `libpng`, `libjpeg`, `openssl` carry known CVEs.
- Compiler flags — `-fstack-protector-strong`, `-D_FORTIFY_SOURCE=2`, `-Wl,-z,relro,-z,now`.
- Symbol stripping — `-fvisibility=hidden` to avoid exposing internals.

## Source-audit checklist

- [ ] Every `Get*Chars` / `Get*Elements` paired with `Release*`.
- [ ] Bounded copies via `Get*Region` where possible.
- [ ] Opaque long handles validated server-side / with magic numbers.
- [ ] `RegisterNatives` table matches Java signatures.
- [ ] Globals are tracked refs; no static raw `jclass`/`jobject`.
- [ ] `AttachCurrentThread` paired with `DetachCurrentThread`.
- [ ] `dlopen` paths bounded to known directories.
- [ ] Native libs built with stack protectors, RELRO, BIND_NOW.

## References
- [Oracle — JNI specification](https://docs.oracle.com/en/java/javase/17/docs/specs/jni/index.html)
- [Android — JNI tips](https://developer.android.com/training/articles/perf-jni)
- [OWASP MASTG — code quality and native code](https://mas.owasp.org/MASTG/0x04h-Testing-Code-Quality/)
- See also: [[android-source-review-methodology]], [[native-rce-from-source-review]], [[decompiler-driven-source-review]]

{% endraw %}
