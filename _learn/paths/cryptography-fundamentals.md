---
title: Applied cryptography for attackers
slug: cryptography-fundamentals
aliases: [crypto, applied-crypto]
---

> Crypto as it actually shows up — in real apps, in audit work, in bug
> bounty, in CTF. The goal is to recognise broken constructions on
> sight and run the canonical attacks without looking up the syntax.

## Prereqs

- One scripting language (Python by default; SageMath unlocks the
  RSA / lattice tier).
- Comfort with modular arithmetic; basic linear algebra helps.

## Stage 1 — encoding and classical

Goal: never confuse encoding with encryption again, and finish any
classical-cipher artefact in minutes.

- [[encoding-base-family]] · [[encoding-other]]
- [[classical-ciphers-overview]]
- [[shift-ciphers]] · [[fixed-substitution-ciphers]]
- [[linear-mapping-ciphers]] · [[vigenere-cipher]]
- Practice: [CryptoHack](https://cryptohack.org/) introductory tier.

## Stage 2 — symmetric (the real-world bug surface)

Goal: spot mode misuse and weak-keystream patterns in real apps; run
the canonical attacks against a target without looking it up.

- [[block-cipher-modes]] — recognising mode from ciphertext shape.
- [[ecb-attacks]] — ECB byte-at-a-time prefix recovery against a real
  cookie or token format.
- [[cbc-bit-flipping]] — tampering with serialised auth blobs.
- [[cbc-padding-oracle]] — the bug class that keeps appearing in
  enterprise software.
- [[feistel-and-des]] · [[aes]] — read the construction once.
- [[stream-ciphers-overview]] · [[many-time-pad]] — keystream-reuse
  shows up in homebrewed token schemes.
- [[linear-congruential-generator]] · [[lfsr]] · [[rc4]] — broken
  PRNGs in licensing, captcha, password reset.

## Stage 3 — asymmetric

Goal: recognise the standard RSA breakages by parameter shape; tell
when DH is broken without writing a solver.

- [[public-key-basics]] · [[rsa]]
- [[rsa-low-exponent]] · [[rsa-common-modulus]]
- [[rsa-wiener]] · [[rsa-coppersmith]]
- [[discrete-logarithms]] · [[diffie-hellman]]
- Real-world JWT pivot: [[jwt-key-confusion]],
  [[jwt-jku-jwk-injection]].
- Tool: [RsaCtfTool](https://github.com/RsaCtfTool/RsaCtfTool) as a
  first-pass triage utility.

## Stage 4 — applied / protocol-level

Where crypto-shaped bugs actually live in modern systems.

- [[hash-length-extension]] — query-string signing schemes.
- [[shamir-threshold]] — distributed secret recovery.
- Elliptic curves — point arithmetic; ECDLP-hard vs anomalous curves.
- TLS misconfig, cookie signing schemes, S3 pre-signed URL parsing.

## Why this matters outside CTF

- Bug-bounty programs pay for token-format bugs (IDOR-via-JWT,
  predictable session tokens, signed-URL forgery).
- Audit work routinely flags ECB cookies, hardcoded IVs, predictable
  password-reset tokens.
- Production incidents land on weak randomness, mode misuse, and
  signature-scheme confusion more often than on broken primitives.

## References

- [CryptoHack](https://cryptohack.org/) — best free hands-on.
- [CryptoPals](https://cryptopals.com/) — the canonical exercises.
- *Cryptography Engineering* (Ferguson, Schneier, Kohno) for grounding.
- *Serious Cryptography* (Aumasson) for modern depth.
- *Handbook for CTFers* (Nu1L Team, Springer) — structural source for
  the symmetric and RSA topic coverage.
