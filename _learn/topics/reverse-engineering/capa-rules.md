---
title: capa Rules and Capability Extraction
slug: capa-rules
---

> **TL;DR:** Mandiant's capa scans binaries with YAML rules to emit capability labels mapped to MITRE ATT&CK, turning raw disassembly into intent-level summaries.

## What it is
capa is an open-source tool that identifies capabilities in executable files by matching features (API calls, strings, mnemonics, basic-block patterns) against community-maintained YAML rules. It runs on top of a backend disassembler (vivisect by default, with IDA, Ghidra, Binary Ninja, and dynamic CAPE sandbox traces also supported). Each rule carries metadata that maps hits to MITRE ATT&CK techniques and MAEC behaviours.

## Preconditions / where it applies
- capa 7.x+ installed via `pipx install flare-capa`
- Target PE, ELF, Mach-O, or .NET binary (or a CAPE sandbox report for dynamic mode)
- Optional: IDA Pro 8+ or Ghidra 11+ for an alternate backend
- Rule pack from `mandiant/capa-rules` cloned alongside the tool

## Technique
Run capa and author a minimal rule.

```bash
# Static scan against the default rule set
capa ./sample.exe

# Verbose, including matching addresses and feature counts
capa -vv ./sample.exe

# Use Ghidra as the backend
capa --backend ghidra ./sample.exe

# Dynamic mode against a CAPE report
capa --format=cape report.json
```

A minimal rule lives in a single YAML file:

```yaml
rule:
  meta:
    name: encode data using XOR with single byte key
    namespace: data-manipulation/encoding/xor
    authors:
      - student@example.org
    scopes:
      static: function
      dynamic: process
    att&ck:
      - Defense Evasion::Obfuscated Files or Information [T1027]
    mbc:
      - Data::Encode Data::XOR [C0026.002]
  features:
    - and:
        - characteristic: loop
        - mnemonic: xor
        - number: 0xFF
```

## Detection and defence
- App-side: avoid hand-rolled crypto and well-known constants that trigger capa rules
- RE-side: vet third-party rule contributions before importing; pinning the ruleset hash is a good practice
- Detection: pipe capa JSON output into CI so unexpected capability hits (network, persistence, injection) fail a build

## References
- [capa on GitHub](https://github.com/mandiant/capa) — tool and documentation
- [capa rules repository](https://github.com/mandiant/capa-rules) — community rule pack with ATT&CK mappings

See also: [[ghidra-decompiler]], [[ida-hexrays]], [[executable-files-pe-elf]].
