---
title: DEX file format
slug: dex-file-format
---

> **TL;DR:** Dalvik EXecutable — a single bytecode container with shared string/type/method/field pools, register-based instructions, and a header checksum. baksmali/smali read and assemble it.

## What it is
DEX is the bytecode format the Android runtime (ART, formerly Dalvik) executes. Unlike JVM `.class`, a single DEX bundles every class in a multidex slice and shares constants in deduplicated pools, which makes APKs smaller and class loading faster. Modern apps ship multiple DEX files (`classes.dex`, `classes2.dex`, …) when method/index counts exceed the 65 536 cap.

## Preconditions / where it applies
- Any `.dex` extracted from an APK or dumped from memory (see [[apk-unpacking]])
- Native ART runtime later compiles DEX → OAT/VDEX; both formats matter when ripping methods from `/data/dalvik-cache/`
- Repackaging requires rewriting the header checksum and SHA-1 signature, plus the APK signing block

## Technique
Header layout (truncated, all little-endian):

```
0x00  magic        "dex\n035\0"   // 035, 037, 038, 039 across API levels
0x08  checksum     adler32 of rest of file
0x0C  signature    SHA-1 of rest of file
0x20  file_size, header_size, endian_tag
0x38  string_ids_size + off
0x40  type_ids_size + off
0x48  proto_ids_size + off
0x50  field_ids_size + off
0x58  method_ids_size + off
0x60  class_defs_size + off
0x68  data_size + off
```

After the header, sections store IDs that reference offsets into `data` where the actual bytes live: `string_data_item`, `class_data_item`, `code_item` (registers, ins/outs, instructions, tries, handlers, debug info). Instructions are 16-bit "code units" using register operands (`v0`–`vN`), e.g. `const-string v0, "secret"`, `invoke-virtual {v1, v2}, Lcom/x/Y;->m(I)V`.

Hands-on:

```bash
# Disassemble to smali (human-readable)
baksmali d classes.dex -o smali/
# Reassemble after edits
smali a smali/ -o classes.dex
# Inspect header + tables
dexdump -h classes.dex | head
dexdump -d classes.dex | less    # full disassembly with bytecode
```

Smali edit pattern (force a method to return false):

```smali
.method public isRooted()Z
    .registers 2
    const/4 v0, 0x0
    return v0
.end method
```

Repair after editing a dumped DEX (the magic, file_size, checksum and signature must match):

```python
import struct, zlib, hashlib
data = bytearray(open('dump.dex','rb').read())
data[0:8] = b'dex\n035\0'
struct.pack_into('<I', data, 0x20, len(data))          # file_size
data[0x0C:0x20] = hashlib.sha1(data[0x20:]).digest()   # signature
struct.pack_into('<I', data, 0x08, zlib.adler32(data[0x0C:]))  # checksum
open('fixed.dex','wb').write(data)
```

DEX is the input to every static-analysis pass; see [[apk-reverse-tools]] for jadx/JEB which lift it back to Java, and [[ollvm-obfuscation]] for the native side that often holds the keys to encrypted strings.

## Detection and defence
- R8 / Proguard rename + inline to break grep-friendly class names
- String encryption in `<clinit>` so DEX strings show ciphertext; defeated by hooking the decryptor
- Multi-DEX with dynamic `DexClassLoader` from `assets/` to delay analysis
- Magic version 039 is API 28+; mismatched magic in dumps signals tampering
- Server-side integrity (Play Integrity) is the only check that survives client edits

## References
- [Dalvik bytecode reference](https://source.android.com/docs/core/runtime/dalvik-bytecode) — instruction set
- [DEX format spec](https://source.android.com/docs/core/runtime/dex-format) — header + sections
- [smali/baksmali](https://github.com/google/smali) — assembler/disassembler
