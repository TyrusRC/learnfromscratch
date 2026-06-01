---
title: RC4
slug: rc4
---

> **TL;DR:** RC4 is a deprecated stream cipher whose keystream is statistically biased from byte 1 — biased early bytes plus weak IV chaining killed WEP, and TLS-RC4 traffic is recoverable with enough samples.

## What it is
RC4 maintains a 256-byte permutation S and two indices i, j. Key Scheduling Algorithm (KSA) seeds S from the key; Pseudo-Random Generation Algorithm (PRGA) emits one keystream byte per step. The keystream is XORed with the plaintext. The construction is small, fast in software, and historically ubiquitous (WEP, early WPA-TKIP, SSL/TLS up to RFC 7465's ban). Its weaknesses span early-byte biases (Mantin-Shamir, Fluhrer-Mantin-Shamir), long-term biases (AlFardan et al.), and the absence of any authentication.

## Preconditions / where it applies
- Legacy targets: WEP, PPTP/MS-CHAPv2, old VPN appliances, embedded crypto, Kerberos `RC4_HMAC` (NT hash as key — see [[../ad/kerberoasting]] in AD section).
- IV is prepended/appended to a long-term key (WEP-style) so different IVs share key bits.
- Enough captured ciphertexts under either the same key (≥2^24 samples for TLS-RC4) or many IV-chained sessions (~40k packets for WEP).
- Plaintext partially known (HTTP headers, cookies) — TLS-RC4 attack recovers cookies from biased positions.

## Technique
- **FMS / KoreK / PTW (WEP)**: each IV reveals information about specific key bytes via the resolved-conditions probability. `aircrack-ng` cracks a 104-bit WEP key from ~40k-85k unique IVs in seconds.

```bash
airodump-ng -c 6 --bssid AA:BB:CC:DD:EE:FF -w cap wlan0mon
aireplay-ng --arpreplay -b AA:BB:CC:DD:EE:FF -h <client mac> wlan0mon
aircrack-ng cap-01.cap
```

- **Mantin-Shamir bias**: keystream byte 2 is `0x00` with probability ~2/256 instead of 1/256 — exploit when many sessions share a key prefix.
- **AlFardan biases (TLS-RC4)**: positions 1-256 show keystream byte distributions skewed from uniform; 2^28-2^32 samples of the same plaintext byte across sessions recovers it. Forced cookie reuse via JavaScript makes this practical in browsers.
- **Bar-Mitzvah (invariance weakness)**: ~1 in 2^16 RC4 keys reveal the first 100+ keystream bytes; useful when the attacker can also induce session keys (TLS RSA key-exchange before forward secrecy).
- **Kerberos RC4-HMAC**: the encryption key is `MD4(NT password)`. Service tickets are kerberoastable offline with `hashcat -m 13100`; the cipher itself isn't broken, the key derivation is too weak.

```bash
hashcat -m 13100 -a 0 tickets.txt rockyou.txt
```

## Detection and defence
- Disable RC4 everywhere: TLS (RFC 7465), Kerberos (`KrbtgtFullPacSignature`, set `msDS-SupportedEncryptionTypes` to AES-only), SSH (`Ciphers -arcfour*`), 802.11 (use WPA3 or at minimum WPA2-AES-CCMP).
- On Windows, set GPO `Network security: Configure encryption types allowed for Kerberos` → AES128/AES256 only; deny RC4 to surface the weakness in your environment.
- Monitor TLS handshakes for RC4 cipher-suite selection; alert in SIEM. Reject expired browsers that still negotiate it.

## References
- [RFC 7465 — Prohibiting RC4](https://datatracker.ietf.org/doc/html/rfc7465) — IETF deprecation.
- [AlFardan et al. — On the security of RC4 in TLS](https://www.isg.rhul.ac.uk/tls/RC4biases.pdf) — bias-based plaintext recovery.
- [aircrack-ng documentation](https://www.aircrack-ng.org/doku.php?id=aircrack-ng) — WEP-cracking workflow.
