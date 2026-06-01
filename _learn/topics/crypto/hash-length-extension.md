---
title: Hash length-extension
slug: hash-length-extension
---

> **TL;DR:** Merkle-Damgard hashes (MD5, SHA-1, SHA-2 family) leak their internal state as the output, so given `H(secret || msg)` and `len(secret)` an attacker computes `H(secret || msg || pad || suffix)` without knowing the secret.

## What it is
Merkle-Damgard construction iterates a compression function over fixed-size blocks, finalising with a length-padded last block, and outputs the final chaining variable. That variable is also a valid starting state. An attacker who knows the output hash can resume the construction from that state, append their own data plus its own length padding, and produce a valid hash for the extended message — without ever learning the secret prefix. This breaks naive MAC schemes of the form `MAC = H(secret || message)`.

## Preconditions / where it applies
- Hash uses Merkle-Damgard: MD5, SHA-1, SHA-224, SHA-256, SHA-384, SHA-512 (and length-extension also works against SHA-512/256 if the truncation isn't applied). SHA-3 (Keccak) and Blake2/3 are immune (sponge / different construction).
- Authentication is `H(secret || msg)`, with `msg` and `H` known to the attacker.
- The attacker can guess or brute-force `len(secret)` (often a small range, e.g. 8..64).
- The verifier accepts arbitrary trailing padding bytes — almost all do, since the padding is binary noise in URL/query contexts.

## Technique
1. Capture a legitimate `(msg, sig)` pair where `sig = H(secret || msg)`.
2. For each candidate secret length L:
   - Compute MD-padding for `(secret || msg)` of total length L + len(msg).
   - Initialise the hash with internal state set to `sig`.
   - Feed `attacker_suffix`; finalise.
   - Result is `H(secret || msg || glue_pad || suffix)` for forged message `msg || glue_pad || suffix`.
3. Submit forged message + new signature to the verifier; if accepted, L was correct.

```bash
# hash_extender does the maths
hash_extender \
  --data 'user=alice&role=user' \
  --secret 16 \
  --append '&role=admin' \
  --signature 6c2f... \
  --format sha256
```

```python
# Conceptual SHA-256 resume (use a library like hashpumpy in practice)
import hashpumpy
new_sig, new_msg = hashpumpy.hashpump(orig_sig, orig_msg, b'&admin=1', secret_len)
```

Common targets: legacy Flickr-style API signing (`md5(secret + params)`), home-grown session tokens, Stripe-pre-2014 webhook signatures, CTF challenges asking to add `&admin=1` to a signed query string.

## Detection and defence
- Use HMAC (`HMAC(K, m) = H(K_o || H(K_i || m))`) — provably resistant to length extension. Every language stdlib ships one.
- For new designs use SHA-3, KMAC, Blake2/3 keyed mode, or HMAC-SHA-256.
- Reject queries with unexpected trailing parameters or non-printable bytes in canonicalised input.
- Pin secret length to a single fixed value and document it — kills the "try each L" loop, though not the attack itself.

## References
- [hash_extender (iagox86)](https://github.com/iagox86/hash_extender) — multi-algorithm CLI extender.
- [RFC 2104 — HMAC](https://datatracker.ietf.org/doc/html/rfc2104) — the correct construction.
- [Skullsecurity — Everything you need to know about hash length extension](https://www.skullsecurity.org/2012/everything-you-need-to-know-about-hash-length-extension-attacks) — readable walkthrough.
