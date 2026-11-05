---
title: YARA rule authoring
slug: yara-rule-authoring
aliases: [yara, yara-rules, yara-x]
---

> **TL;DR:** YARA is a pattern-matching language for identifying malware samples, suspicious files, and memory artifacts. Rules combine byte patterns, strings, conditions, and module metadata (PE headers, math entropy) to classify files. Modern tooling includes YARA-X (Rust rewrite with better error messages and performance). Rules live in detection pipelines alongside [[sigma-rules-detection-as-code]] and feed into [[detection-as-code-pipeline]] CI.

## Anatomy of a rule

```yara
rule Cobalt_Strike_Beacon_Config
{
    meta:
        author      = "detection-eng"
        description = "Matches default Cobalt Strike beacon config block"
        reference   = "https://attack.mitre.org/software/S0154/"
        date        = "2024-10-01"
        severity    = "critical"

    strings:
        $magic   = { 00 00 BE EF }
        $config  = { 00 01 00 01 00 02 ?? ?? 00 02 00 01 00 ?? ?? ?? }
        $str_ua  = "Mozilla/5.0" ascii wide
        $str_pipe = "\\\\.\\pipe\\" ascii nocase

    condition:
        uint16(0) == 0x5A4D and       // PE file
        filesize < 2MB and
        $magic and
        $config and
        any of ($str_*)
}
```

## Key syntax

| Element | Purpose |
|---|---|
| `hex string` `{ AA BB ?? CC }` | Byte pattern; `??` = wildcard byte, `[2-4]` = jump range |
| `text string` `"foo" ascii wide nocase` | Text with encoding/case modifiers |
| `regex` `/https?:\/\/[^\s]+/` | PCRE-compatible regex (expensive — use sparingly) |
| `condition` | Boolean expression combining `$strings`, `filesize`, `uint*()`, modules |
| `private rule` | Matches but does not trigger as standalone — used as building block |
| `global rule` | Condition appended to every other rule in the set |

## Modules worth knowing

**PE module** — parse headers without hex offsets:

```yara
import "pe"

rule Suspicious_PE_Section
{
    condition:
        pe.number_of_sections > 7 and
        for any section in pe.sections : (
            section.name == ".rsrc" and
            section.raw_data_size > 500KB
        )
}
```

**Math module** — entropy checks for packed/encrypted payloads:

```yara
import "math"

rule High_Entropy_Overlay
{
    condition:
        filesize > 50KB and
        math.entropy(0, filesize) > 7.2
}
```

**Other modules:** `elf` (Linux binaries), `dotnet` (.NET metadata), `hash` (section/file hashes), `console` (debug output during development).

## Writing rules for malware families

1. **Collect 5+ samples** — VirusTotal, MalwareBazaar, internal sandbox
2. **Diff with `ssdeep` or `imphash`** to find stable regions
3. **Anchor on config structures** — C2 configs, XOR keys, embedded RSA blobs are harder for authors to change than string artifacts
4. **Avoid version-specific strings** — "v4.3 beacon" will miss v4.4; target the parsing routine instead
5. **Layer private rules** — `private rule Is_PE` + `private rule Has_CS_Strings` + final rule combines both

## Performance optimization

```bash
# Compile rules to check syntax + measure atom extraction
yarac -w rules/malware/*.yar compiled.yarc

# Scan a directory
yara -r -w compiled.yarc /mnt/samples/ 2>errors.log
```

- **Atoms matter:** YARA extracts short fixed substrings ("atoms") from each string for fast pre-filtering. Hex strings with too many wildcards produce no usable atom and force full scans.
- **`filesize` first** in conditions — short-circuits before expensive string matching.
- **Avoid `for all ... of them`** on large string sets; use `3 of ($family_*)` with a threshold.
- **Regex is last resort** — each `/regex/` is orders of magnitude slower than a fixed string. Prefer hex with jumps (`[0-8]`) over `/.{0,8}/`.

## YARA-X (next generation)

```bash
# Install YARA-X (Rust rewrite by VirusTotal)
cargo install yara-x-cli
# or: pip install yara-x

# Scan with better errors and performance
yr scan rules/apt28.yar /mnt/samples/
yr check rules/  # lint rules for correctness
```

YARA-X adds: better error diagnostics, module sandboxing, stricter rule validation (catches ambiguous atoms), and a gRPC-ready library for integration into scanning pipelines.

## Integration patterns

| Context | How YARA fits |
|---|---|
| SIEM/EDR pipeline | Scan files on ingest; alert metadata feeds [[elastic-detection-rules]] or Splunk |
| Sandbox (Cuckoo/CAPE) | Post-detonation scan of dropped files + memory dumps |
| [[velociraptor-threat-hunting]] | `Artifact.Generic.Detection.Yara` hunts across fleet |
| CI/CD ([[detection-as-code-pipeline]]) | New rules tested against known-good + known-bad corpora before merge |
| Threat intel sharing | Attach rules to MISP events ([[misp-threat-intel-sharing]]) |

## Testing workflow

```bash
# Positive test — must match known samples
yara -r rules/emotet.yar tests/samples/emotet/
# Negative test — must NOT match benign corpus
yara -r rules/emotet.yar tests/benign/ && echo "FALSE POSITIVES" || echo "CLEAN"
# Performance benchmark
time yara -r rules/ /mnt/large_sample_set/ > /dev/null
```

Keep a `tests/` directory with hashes (not full binaries) in CI; pull samples from object storage at test time.

## References
- [YARA documentation](https://yara.readthedocs.io/)
- [YARA-X repo](https://github.com/VirusTotal/yara-x)
- [Awesome YARA — curated rule sets](https://github.com/InQuest/awesome-yara)
- [Florian Roth — How to Write Simple but Sound YARA Rules](https://www.nextron-systems.com/2015/02/16/write-simple-sound-yara-rules/)

See also: [[sigma-rules-detection-as-code]], [[detection-as-code-pipeline]], [[detection-engineering-pyramid-of-pain]], [[velociraptor-threat-hunting]], [[misp-threat-intel-sharing]], [[atomic-red-team-emulation-deep]]
