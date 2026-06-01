---
title: APK reverse tools (jadx / JEB / apktool)
slug: apk-reverse-tools
---

> **TL;DR:** jadx for fast free decompilation, JEB for stubborn obfuscation and native, apktool to round-trip smali edits and rebuild a working APK.

## What it is
A working APK reversing setup combines a Java decompiler (DEX → readable Java), a smali assembler/disassembler (for byte-accurate edits and rebuilds), and a native disassembler for the `.so` files. Each tool has different strengths against [[ollvm-obfuscation]] and [[apk-unpacking]].

## Preconditions / where it applies
- Unpacked APK on disk (if packed, see [[apk-unpacking]] first)
- JDK 11+ for jadx and apktool, paid licence for JEB Pro
- Ghidra / IDA / radare2 for native binaries; not strictly APK tools but always pulled in

## Technique
**jadx** — best first look.

```bash
jadx -d out/ app.apk            # batch decompile
jadx-gui app.apk                # interactive, with cross-refs and rename
jadx --deobf -d out/ app.apk    # rename obfuscated a/b/c symbols
```

Strengths: free, fast, decent Kotlin support, good string/xref search. Weaknesses: occasional decompile failures on R8-shrunk code → fall back to smali via the GUI's "Show smali" toggle.

**apktool** — manifest decoding, resources, smali round-trip.

```bash
apktool d app.apk -o out/                # decode (binary XML → text, DEX → smali)
# edit smali under out/smali*/...
apktool b out/ -o patched.apk            # rebuild
zipalign -p 4 patched.apk aligned.apk
apksigner sign --ks debug.keystore aligned.apk
```

Use for: removing certificate pinning ([[ssl-pinning-bypass]]) statically, enabling `debuggable`, neutralising [[apk-anti-debug]] checks, injecting `frida-gadget` `System.loadLibrary` calls.

**JEB Pro** — DEX + native + obfuscated code.

- Better Dalvik decompiler than jadx for heavily R8-shrunk apps
- Native decompiler (ARM/AArch64) handy for JNI bridges
- Scripting in Python/Java for custom deobfuscators (string decryption hooks)

**Adjuncts:**
- `baksmali` / `smali` — direct DEX assembler; what apktool wraps. Useful for surgical multi-DEX edits without rebuilding resources.
- `dex2jar` + `jd-gui` / `procyon` — legacy fallback when jadx fails.
- `Ghidra` with the Ghidroid extension and `apk-files` loader — full DEX + native in one project.
- `frida-apk` — patches an APK to embed `frida-gadget` so unrooted devices can be instrumented; pairs with [[frida-hook]].

Typical workflow: jadx for reading and string/xref hunting → apktool/smali for static patches → JEB or Ghidra for native + obfuscated paths → Frida for dynamic confirmation.

## Detection and defence
- R8 with aggressive shrinking + resource obfuscation reduces jadx readability
- String encryption + reflection forces analysts into JEB/native or dynamic tracing
- Detect apktool rebuilds via signature mismatch and v2-scheme break
- Use [[apk-anti-debug]] integrity checks to flag in-memory smali patches at runtime
- Server-side: bind sessions to attestation tokens, not client identity

## References
- [jadx](https://github.com/skylot/jadx) — DEX/APK decompiler
- [apktool](https://apktool.org/) — resource + smali round-trip
- [JEB Decompiler](https://www.pnfsoftware.com/jeb/) — commercial DEX/native
- [Ghidra](https://ghidra-sre.org/) — native RE with Android loader support
