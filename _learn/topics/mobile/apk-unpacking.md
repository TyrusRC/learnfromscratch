---
title: APK unpacking (packers)
slug: apk-unpacking
---

> **TL;DR:** Chinese commercial packers (Bangcle, Ijiami, 360 Jiagu, Tencent Legu) ship a stub APK that decrypts the real DEX in memory at runtime — dump it after the loader runs and you have plain bytecode again.

## What it is
A packer wraps the original DEX in encryption, replaces `classes.dex` with a small loader, and installs a custom `Application` class that decrypts and loads the real bytecode at runtime via `DexClassLoader` / `InMemoryDexClassLoader` or by patching the runtime's class linker. Reversing the loader is rarely worth it; instead, let the app self-unpack and dump from memory.

## Preconditions / where it applies
- Rooted Android device or emulator matching the app's target ABI
- Loader that decrypts to readable DEX (some advanced packers keep methods encrypted and decrypt per-call — those need finer hooks)
- Ability to attach Frida or run a custom dumper before [[apk-anti-debug]] kills the process

## Technique
Identify the packer by `assets/` filenames and `META-INF` entries:

| Packer | Telltale |
|---|---|
| Bangcle | `assets/bangcle_classes.jar`, `libsecexe.so` |
| Ijiami | `assets/ijiami.dat`, `libexec.so` |
| 360 Jiagu | `libjiagu.so`, `libjiagu_a64.so` in `lib/` |
| Tencent Legu | `libshell-super.2019.so`, `assets/0OO00l111l1l` |
| NQShield | `libnqshield.so` |

General unpacking flow:

1. Boot a rooted device; install Frida server matching arch.
2. Spawn the app paused: `frida -U -f com.victim --no-pause`.
3. Hook `DexFile.openDexFile*`, `BaseDexClassLoader.<init>`, `InMemoryDexClassLoader.<init>`, or for ART-level dumps hook `art::DexFile::DexFile`/`art::OpenAndReadMagic` in `libart.so`.
4. When the hook fires, read `[base, base+size]` and write to disk.

```javascript
// Frida — dump in-memory DEX as it is loaded
Java.perform(function () {
  var DexFile = Java.use('dalvik.system.InMemoryDexClassLoader');
  DexFile.$init.overload('java.nio.ByteBuffer', 'java.lang.ClassLoader')
    .implementation = function (buf, cl) {
      var bytes = Java.array('byte', new Array(buf.remaining()).fill(0));
      buf.duplicate().get(bytes);
      var f = new File('/data/local/tmp/dump.dex', 'w');
      f.write(bytes); f.close();
      return this.$init(buf, cl);
    };
});
```

Native-level dumpers (FRIDA-DEXDump, FART, youpk) walk the ART DexCache after `Application.onCreate()` runs and write every loaded `DexFile` magic-prefixed blob. Repair the magic (`dex\n035\0` / `037\0` / `038\0`) and load into jadx.

For per-method encryption (newer Legu, Jiagu Vmp), hook `art_quick_invoke_stub` / `ArtMethod::Invoke` to capture decrypted CodeItems and stitch them back with FART-style reconstruction. See [[apk-reverse-tools]] for follow-on static analysis and [[ollvm-obfuscation]] for the native loader itself.

## Detection and defence
- Packers themselves are the defence — but stack [[apk-anti-debug]] (Frida detection, ptrace self-attach) to make dumping noisier
- VMP per-method encryption forces dynamic dumping per code path, raising effort
- Detect rooted/emulator environments via hardware attestation rather than file checks
- Server-side: rate-limit + bind sessions to Play Integrity verdicts so a dumped-and-repackaged client cannot transact

## References
- [FRIDA-DEXDump](https://github.com/hluwa/FRIDA-DEXDump) — generic Frida-based dumper
- [youpk](https://github.com/youlor/youpk) — ART-level unpacker for hardened packers
- [HackTricks – Reversing Native libraries](https://book.hacktricks.wiki/en/mobile-pentesting/android-app-pentesting/reversing-native-libraries.html) — packer identification notes
