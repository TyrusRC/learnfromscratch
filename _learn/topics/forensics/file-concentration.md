---
title: File concentration (file-in-file)
slug: file-concentration
---

> **TL;DR:** Multiple files concatenated or appended into one carrier (polyglot or trailing blob). `binwalk` / `foremost` carve them out by magic signatures.

## What it is
File concentration glues several files into one container in a way that each tool still parses "its" file. Two flavours dominate: **appended payloads** (a ZIP after the end of a JPEG — both render correctly because JPEG decoders stop at `FFD9` and ZIP parsers scan backwards from EOF for the central directory) and **polyglot files** that are valid under two unrelated formats at the same byte offsets (PDF + HTML, ZIP + image).

## Preconditions / where it applies
- A carrier file that is suspiciously larger than expected, or whose hex tail does not match its declared format.
- A format whose parsers tolerate trailing junk (JPEG, PNG, GIF, PDF, ZIP) or whose offsets are explicit (ZIP central directory at EOF).
- CTF misc / stego challenges, malware droppers, polyglot exploits.

## Technique
Always start with a signature sweep:

```bash
binwalk -e carrier.png             # scan + extract by magic
binwalk --dd='.*' carrier.png      # extract everything matched
foremost -i carrier.png -o out/    # signature-based carving
strings -n 12 carrier.png | less   # peek for embedded URLs / keys
```

For known suffixes, slice manually. Find the JPEG terminator (`FFD9`) and dump everything after it:

```bash
# Last FFD9 offset, then carve the trailing blob
grep -aboP '\xff\xd9' carrier.jpg | tail -1
dd if=carrier.jpg of=trailing.bin bs=1 skip=$OFFSET
file trailing.bin
```

ZIP-after-image is the textbook case (`cat image.png payload.zip > out.png`); `unzip out.png` works because ZIP parses from EOF. PNGs allow arbitrary `tEXt` / private chunks — inspect with `pngcheck -v` and dump unknown chunk types. PDFs allow content after `%%EOF` — `pdfdetach -saveall` and `pdf-parser.py` enumerate embedded files and javascript.

Polyglot construction is documented in PoC || GTFO; `mitra` (Ange Albertini) generates valid two-format polyglots and is a good study reference.

## Detection and defence
- DLP / mail gateways should re-encode images and PDFs (which drops trailing payloads) and reject files whose size exceeds the declared format's parsed length.
- Sandbox the file with multiple parsers — if `file`, `exiftool`, and `binwalk` disagree on the type, escalate.
- For PNG / JPEG specifically, scrub unknown ancillary chunks and trim everything after the format terminator.

## References
- [binwalk](https://github.com/ReFirmLabs/binwalk) — firmware / file signature scanner
- [foremost](https://github.com/korczis/foremost) — header / footer carving
- [mitra](https://github.com/corkami/mitra) — polyglot file builder
- [PoC || GTFO archive](https://www.alchemistowl.org/pocorgtfo/) — polyglot research papers
- See also: [[exif-metadata]], [[steganography-overview]]
