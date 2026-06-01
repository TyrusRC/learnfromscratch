---
title: Steganography — overview
slug: steganography-overview
---

> **TL;DR:** Hide data inside an innocuous carrier — images, audio, text, network protocols. CTF misc staple; the workflow is "identify carrier → try common tools → fall back to manual bit-level inspection".

## What it is
Steganography conceals the **existence** of a message; cryptography conceals only the content. A carrier (cover) is modified by an embedding function with a key and a payload to produce a stego object that looks like the original. Defining axes are: domain (spatial vs frequency), carrier format (image / audio / video / text / protocol), and detectability (perceptual vs statistical).

## Preconditions / where it applies
- CTF misc / forensics challenges.
- Real-world malware C2 hidden in image tweets, GitHub avatars, DNS TXT records.
- DLP evasion — exfil payloads ride in image attachments through whitelisted email channels.

## Technique
A standard triage order on any suspicious file:

1. **Metadata sweep** — `exiftool target` and `strings -n 8 target`. Catches lazy payloads embedded in comments or trailing data. See [[exif-metadata]].
2. **Magic / size sanity** — `file target`, `binwalk target`, compare actual size to expected for the visible content. Catches concatenated files. See [[file-concentration]].
3. **Format-specific scanner**:
   - PNG / BMP / GIF: `zsteg -a target`. See [[lsb-steganography]].
   - JPEG: `steghide extract -sf target -p ''`, then `stegseek target rockyou.txt`.
   - WAV / FLAC: spectrogram in Sonic Visualiser, `multimon-ng` for tone protocols. See [[audio-steganography]].
   - PDF / Office: `pdf-parser.py`, unzip and inspect.
4. **Bit-plane viewer** — `stegsolve` cycles through R/G/B bit planes; payloads embedded as flat-colour pixels jump out.
5. **Manual extraction** — script the bit read in the suspected channel and scan order; look for length prefixes, ZIP / PNG magic, or printable ASCII.

Encrypted payloads are common: the recovered bytes are pseudo-random until xor'd with a key. Try the filename, the challenge title, or single-byte xor before assuming the extraction is wrong.

Beyond files, **network stego** hides data in protocol fields — TCP initial sequence numbers, IP `Identification`, DNS query timing, ICMP payloads. `cloakify` and `dnscat2` are reference implementations; detection lives in [[traffic-analysis]].

## Detection and defence
- Re-encoding lossy formats (JPEG round-trip, MP3 transcode) destroys most spatial-domain stego.
- Statistical detectors (chi-square, RS analysis, `aletheia`) flag LSB anomalies even when payloads are encrypted.
- For DLP, normalise outbound media: strip metadata, re-encode, drop trailing data. Flag size outliers vs format baselines.

## References
- [stego-toolkit](https://github.com/DominicBreuker/stego-toolkit) — Docker image with most common stego tools
- [CTF Field Guide — Forensics](https://trailofbits.github.io/ctf/forensics/) — Trail of Bits' primer
- [Aletheia](https://github.com/daniellerch/aletheia) — statistical steganalysis suite
- See also: [[lsb-steganography]], [[audio-steganography]], [[blind-watermarks]], [[file-concentration]], [[exif-metadata]]
