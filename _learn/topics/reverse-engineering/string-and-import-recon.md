---
title: Strings and imports recon
slug: string-and-import-recon
---

> **TL;DR:** First five minutes of any reverse — pull strings, list imports, check sections and entropy. The function you need is often one xref away from a giveaway string.

## What it is
Surface-level static recon: enumerate the human-readable artefacts in the binary and let them lead you to the interesting code. Cheapest, fastest step in [[static-analysis]].

## Preconditions / where it applies
- Any binary that is not fully encrypted/packed. Even packed binaries leak hints in the stub.
- `strings`, `rabin2`, `readpe`, `readelf`, `nm`, `objdump`, IDA/Ghidra/BN.

## Technique

### Strings
```bash
strings -a -n 8 sample.bin | less                # default ASCII
strings -a -e l -n 8 sample.bin                  # UTF-16LE (Windows)
strings -a -e b -n 8 sample.bin                  # UTF-16BE
rabin2 -zz sample.bin                            # all strings + addresses
```

What to scan for:
- **Format strings** — `%s`, `%d`, `printf`-style — anchor sprintf/log calls.
- **URLs, domains, IPs** — C2, telemetry, update endpoints.
- **Registry keys / file paths** — `Software\Microsoft\Windows\CurrentVersion\Run`, `/etc/passwd`, `C:\Users\<…>\AppData`.
- **Function/error messages** — give away algorithm names ("invalid AES key length", "RSA decrypt failed").
- **Build artefacts** — PDB paths (`d:\projects\...\Release\app.pdb`), Go module paths, Rust panic file/line, compiler banners.
- **Embedded keys/tokens** — anything that looks like a JWT, base64 blob, PEM header (`-----BEGIN`), AWS key (`AKIA…`).
- **Magic constants** — `0x67452301` (SHA-1 init), `0x5a827999` (SHA-1 K), `0xC0DEF00D` style markers.

Then take any interesting string and follow its xref in the disassembler — that often lands you in the function you wanted.

### Imports / Exports
PE:
```bash
rabin2 -i sample.exe                # imports
rabin2 -E sample.dll                # exports
pestudio sample.exe                 # GUI with risk-coloured imports
```

ELF / Mach-O:
```bash
readelf -d sample            # NEEDED libraries
nm -D sample                 # dynamic symbols
otool -L sample              # Mach-O dynamic deps
```

Map imports to capability:
- `CreateRemoteThread` / `WriteProcessMemory` / `NtMapViewOfSection` → injection.
- `WSAStartup` / `connect` / `socket` → network.
- `CryptAcquireContext` / `BCrypt*` / `EVP_*` → crypto.
- `OpenProcessToken` / `LookupPrivilegeValue` → privilege manipulation.
- `LoadLibrary` + `GetProcAddress` only, with everything else hashed away → API hashing in use ([[anti-static-analysis]]).

A near-empty IAT is a packed-binary tell — see [[packers]].

### Sections + entropy
```bash
rabin2 -S sample.bin          # section perms + size
binwalk -E sample.bin         # entropy plot — packed regions spike near 8.0
```

RWX sections, abnormally-named sections, and high-entropy sections all flag obfuscation or embedded payloads.

### Embedded blobs
Search for known headers: PE `MZ`, ELF `\x7fELF`, ZIP `PK\x03\x04`, PNG `\x89PNG`. Tools: `binwalk`, `foremost`, custom carve scripts.

## Detection and defence
- Defenders should expect attackers run this first — strip PDB paths, encrypt strings, hash APIs, minimise imports.
- Detection rules (YARA, Sigma) often key off the same surface signals; if you're reversing malware, your YARA writer will lift directly from your strings list.

## References
- [pestudio (winitor)](https://www.winitor.com/) — Windows PE triage GUI
- [HackTricks strings + imports](https://book.hacktricks.wiki/en/reversing/reversing-tools-basic-methods/index.html) — quick checklist
