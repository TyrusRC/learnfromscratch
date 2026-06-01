---
title: Mach-O Binary Analysis
slug: mach-o-analysis
---

> **TL;DR:** Mach-O is Apple's executable format; parse its header and load commands to map segments, symbols, and dynamic linker info before diving into disassembly.

## What it is
Mach-O (Mach Object) is the native binary format for macOS and iOS executables, dylibs, and bundles. Each file starts with a magic header followed by an array of load commands that describe segments, symbol tables, and dynamic linker metadata. Fat (universal) binaries wrap multiple Mach-O slices for different CPU architectures behind a `fat_header`.

## Preconditions / where it applies
- macOS or Linux host with `otool`, `nm`, `jtool2`, or `MachOView`
- Target Mach-O slice (thin) or universal binary (fat)
- Apple Silicon (arm64) or Intel (x86_64) artifact
- Optionally a code-signing entitlement blob for context

## Technique
Inspect the architecture slices and load commands of a sample binary.

```bash
# List slices in a fat binary
file ./target.bin
lipo -info ./target.bin
lipo -thin arm64 ./target.bin -output ./target.arm64

# Dump header and load commands
otool -h ./target.arm64
otool -l ./target.arm64 | less

# Key load commands to look for:
#   LC_SEGMENT_64   __TEXT / __DATA / __LINKEDIT segments
#   LC_SYMTAB       symbol + string table offsets
#   LC_DYLD_INFO    rebase/bind/lazy-bind/export tries
#   LC_LOAD_DYLIB   linked dynamic libraries
#   LC_CODE_SIGNATURE  embedded CMS blob

# Symbols and imported dylibs
nm -arch arm64 -m ./target.arm64 | head
otool -L ./target.arm64

# jtool2 gives richer output and entitlement dumps
jtool2 --ent ./target.arm64
jtool2 -d ./target.arm64 | grep -i _main
```

## Detection and defence
- App-side: enable hardened runtime, library validation, and notarization to block injected dylibs
- RE-side: respect code-signing; re-sign tampered binaries with `codesign --force --sign -` for testing
- Detection: monitor `DYLD_INSERT_LIBRARIES` env abuse and unexpected `LC_LOAD_DYLIB` entries pointing outside `/usr/lib` or the app bundle

## References
- [Apple: Mach-O Programming Topics](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/MachOTopics/0-Introduction/introduction.html) — official format guide
- [jtool2 home page](https://www.newosxbook.com/tools/jtool.html) — Levin's swiss-army Mach-O tool

See also: [[executable-files-pe-elf]], [[ghidra-decompiler]], [[ida-hexrays]].
