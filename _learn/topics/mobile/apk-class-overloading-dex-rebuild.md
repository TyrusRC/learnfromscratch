---
title: Runtime DEX Loading and Rebuilding Dumped DEX
slug: apk-class-overloading-dex-rebuild
---

> **TL;DR:** Packers hide real classes behind `DexClassLoader` / `InMemoryDexClassLoader`; dump the loaded buffer from memory, then repair the DEX header (magic, checksum, signature, `map_off`) so dex2jar and jadx accept it.

## What it is
Android packers ship a tiny stub DEX in `classes.dex` and decrypt the real DEX into memory at startup, handing it to a class loader. Once dumped, the buffer often has zeroed or corrupted header fields because the loader only reads what it needs. Reconstructing a parseable DEX means fixing four things: the 8-byte magic, the Adler32 `checksum`, the SHA-1 `signature`, and the `map_off` pointing at the `map_list`.

## Preconditions / where it applies
- APKs using runtime class loading (DexClassLoader, PathClassLoader on extracted files, InMemoryDexClassLoader on Android 8+)
- Memory dumps captured via Frida `Process.findRangeByAddress` or `/proc/<pid>/maps` carving
- Targets where static unpackers (e.g. `dexdump`-friendly extractors) fail

## Technique
Hook the loader, snapshot the buffer, then rebuild the header.

```java
// Frida snippet — capture InMemoryDexClassLoader payloads
Java.perform(function () {
  var IMDCL = Java.use("dalvik.system.InMemoryDexClassLoader");
  IMDCL.$init.overload("java.nio.ByteBuffer", "java.lang.ClassLoader")
       .implementation = function (buf, parent) {
    var bytes = Java.array("byte", new Array(buf.remaining()).fill(0));
    buf.duplicate().get(bytes);
    send({tag: "dex", size: bytes.length}, bytes);
    return this.$init(buf, parent);
  };
});
```

```python
# rebuild_dex.py — repair header fields after dumping
import struct, zlib, hashlib, sys

raw = bytearray(open(sys.argv[1], "rb").read())
raw[0:8] = b"dex\n035\x00"                        # magic
# map_off lives at offset 0x34; recompute from map_list location if zeroed
size = struct.unpack_from("<I", raw, 0x20)[0]
sha1 = hashlib.sha1(raw[0x20:size]).digest()       # signature covers [0x20:]
raw[0x0C:0x20] = sha1
adler = zlib.adler32(raw[0x0C:size]) & 0xffffffff  # checksum covers [0x0C:]
struct.pack_into("<I", raw, 0x08, adler)
open("fixed.dex", "wb").write(raw)
# then: d2j-dex2jar fixed.dex && jadx fixed.dex
```

## Detection and defence
- Packers self-check by re-reading `classes.dex` from the APK and comparing to the loaded image — patch the integrity routine in-memory before dumping.
- Anti-Frida traps inspect `/proc/self/maps` for `frida-agent`; rename the gadget, or use a kernel-level tracer.
- Defenders should pin certificates, enable Play Integrity, and avoid leaving plaintext DEX in heap pages longer than necessary.

## References
- [Android DEX format spec](https://source.android.com/docs/core/runtime/dex-format) — header layout and map list
- [InMemoryDexClassLoader API](https://developer.android.com/reference/dalvik/system/InMemoryDexClassLoader) — official loader docs

See also: [[dex-file-format]], [[apk-file-structure]], [[apk-unpacking]], [[frida-hook]], [[xposed-hook]], [[jeb-decompiler]].
