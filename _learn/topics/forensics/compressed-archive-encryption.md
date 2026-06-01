---
title: Encrypted archive attacks
slug: compressed-archive-encryption
---

> **TL;DR:** Crack legacy ZipCrypto archives with known-plaintext (`bkcrack`); brute weak passwords with `john` / `hashcat` after extracting a hash with `zip2john` / `rar2john` / `7z2john`.

## What it is
Encrypted archives use one of three classes of crypto: legacy ZipCrypto (a flawed stream cipher trivially broken by known-plaintext), AES-128/256 in WinZip/7z/RAR (sound, but vulnerable to weak passwords), or password-derived KDFs with low iteration counts. Offence picks the cheapest path: known-plaintext if any plaintext leaks, otherwise dictionary + mask + rule attacks against the KDF.

## Preconditions / where it applies
- An encrypted ZIP / RAR / 7z archive recovered from disk, email, or CTF challenge.
- Either: a sample file the archive is known to contain (known-plaintext), OR a weak / templated password, OR a leaked password hint.
- For ZipCrypto: at least 12 bytes of known plaintext at a known offset.

## Technique
**Known-plaintext on ZipCrypto** is the strongest attack. If the archive contains, say, `LICENSE` or a stock asset you also have unencrypted, `bkcrack` recovers the internal keys in seconds and decrypts everything:

```bash
bkcrack -C target.zip -c LICENSE -P known.zip -p LICENSE
bkcrack -C target.zip -k <k0> <k1> <k2> -d secret.bin secret.bin
```

**Password brute force** for AES-encrypted archives goes through John or hashcat. Extract the hash first:

```bash
zip2john target.zip > zip.hash
john --wordlist=rockyou.txt zip.hash
hashcat -m 13600 zip.hash rockyou.txt -r best64.rule   # WinZip AES
hashcat -m 11600 7z.hash rockyou.txt                   # 7-Zip
hashcat -m 12500 rar3.hash rockyou.txt                 # RAR3
hashcat -m 13000 rar5.hash rockyou.txt                 # RAR5
```

Mask attacks fit known patterns — `?u?l?l?l?l?d?d?d?d` for a corporate password policy. RAR5 and 7z are slow (high iteration count); prioritise wordlists tuned to the target's language and dump.

## Detection and defence
- Prefer AES-256 archives with passwords ≥16 chars of high entropy; reject ZipCrypto in DLP scanners.
- Log archive-extraction child processes from mail clients — encrypted attachments are a common malware vector.
- Egress monitoring: encrypted archives leaving the network are an exfil indicator when correlated with prior file-staging.

## References
- [bkcrack](https://github.com/kimci86/bkcrack) — known-plaintext attack on ZipCrypto
- [hashcat modes](https://hashcat.net/wiki/doku.php?id=example_hashes) — mode numbers per archive type
- [John the Ripper jumbo](https://github.com/openwall/john) — ships `*2john` extractors
- See also: [[disk-image-forensics]]
