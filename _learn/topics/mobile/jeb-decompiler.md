---
title: JEB for Android and Native Decompilation
slug: jeb-decompiler
---

> **TL;DR:** JEB ships a DEX decompiler plus native ARM/x86 decompilers and a Python/Java scripting API, making it the swiss-army knife when jadx stalls on obfuscation or you need to follow JNI into native code.

## What it is
JEB is a commercial reverse-engineering platform from PNF Software. Its DEX engine reconstructs Java from Dalvik bytecode while preserving cross-references across Smali, Java, and resources; the native modules decompile ARM (32/64) and x86 to pseudo-C in the same project, so a JNI call site can be followed straight into the `.so`. The scripting layer exposes the full API to Jython, EngineClient plugins, and Java extensions.

## Preconditions / where it applies
- APKs where jadx produces `// $FF: Couldn't be decompiled` markers
- Packed or string-encrypted apps that need Smali patching + redecompilation
- Hybrid Android/native targets where JNI calls cross into C/C++
- Headless batch analysis (`jeb -c --script=...`)

## Technique
Auto-decrypt strings in a loaded DEX, then re-run the decompiler.

```python
# decrypt_strings.py — run via JEB > File > Scripts
from com.pnfsoftware.jeb.core import RuntimeProjectUtil
from com.pnfsoftware.jeb.core.units.code.android import IDexUnit

ctx = RuntimeProjectUtil.getMainProject(engctx)
for dex in RuntimeProjectUtil.findUnitsByType(ctx, IDexUnit, False):
    for m in dex.getMethods():
        sig = m.getSignature(False)
        if sig.endswith("Lcom/app/Obf;->d(Ljava/lang/String;)Ljava/lang/String;"):
            target = m
            break

    for cls in dex.getClasses():
        for fld in cls.getFields():
            if fld.getGenericFlags() & 0x8:  # static
                val = fld.getInitialValue()
                if val and val.getType() == 0x17:  # string
                    enc = val.getStringValue()
                    dec = local_decrypt(enc)   # mirror the Java routine
                    fld.setInitialValue(makeString(dec))

    dex.process()   # re-decompile with cleartext strings
```

Pair JEB with Smali-level patches when you need to neutralise root/Frida checks before redecompiling.

## Detection and defence
- Anti-tamper apps verify DEX CRC at runtime — rebuild the CRC after Smali edits, or hook the check with [[frida-hook]] / [[xposed-hook]] instead.
- Commercial obfuscators (DexGuard, Bangcle) detect emulator and debugger; JEB's static analysis sidesteps these, but native unpacking still needs Pin/Frida.
- Comparison: jadx is free and fast for clean apps; IDA's APK loader integrates with native debugging; JEB wins on combined DEX+native projects with scripting.

## References
- [JEB Android decompiler docs](https://www.pnfsoftware.com/jeb/manual/) — vendor manual
- [JEB scripting API reference](https://www.pnfsoftware.com/jeb/apidoc/) — Java/Python entry points

See also: [[apk-file-structure]], [[dex-file-format]], [[apk-unpacking]], [[apk-class-overloading-dex-rebuild]].
