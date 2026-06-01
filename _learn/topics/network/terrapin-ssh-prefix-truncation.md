---
title: Terrapin (SSH prefix-truncation downgrade)
slug: terrapin-ssh-prefix-truncation
---

> **TL;DR:** CVE-2023-48795 — a network-position attacker silently deletes the first few SSH transport messages after the handshake by manipulating sequence numbers. The result is downgraded auth security and stripped extensions, including the keystroke-timing countermeasure and `ping@openssh.com`.

## What it is
Terrapin is a prefix-truncation attack against the SSH binary packet protocol disclosed in late 2023 by researchers at Ruhr University Bochum. The flaw is in how SSH handles sequence numbers across the transition from unencrypted handshake to encrypted transport: an in-path attacker can inject extra unauthenticated packets before `NEWKEYS` (incrementing the receiver's sequence counter), then drop an equivalent number of encrypted packets after `NEWKEYS`. The integrity check still passes because both endpoints' counters remain aligned, but the receiver never sees the dropped messages. The attack works against `chacha20-poly1305@openssh.com` and any `*-etm@openssh.com` MAC unless both peers negotiate the `strict-kex` extension (`kex-strict-{c,s}-v00@openssh.com`) introduced in OpenSSH 9.6.

## Preconditions / where it applies
- Attacker holds an active man-in-the-middle position on the SSH TCP stream.
- Both endpoints negotiate `chacha20-poly1305@openssh.com` or an `*-etm@openssh.com` MAC.
- At least one endpoint does not advertise `kex-strict-*-v00@openssh.com` (pre-9.6 OpenSSH, older libssh, dropbear before 2024.85, Bitvise/Tectia and many IoT/embedded stacks).
- Related: [[ssh-enum]], [[known-cve-triage]].

## Technique
Detection from the attacker side is identical to client-side — point the public scanner at the target:

```bash
# Researchers' scanner — checks server algorithms and strict-kex support
./Terrapin-Scanner --connect TARGET:22
```

Output flags whether the algorithm list contains a vulnerable cipher and whether `kex-strict-s-v00@openssh.com` is advertised. A fully-patched server pinned to AES-GCM is not exploitable; a vulnerable server pinned to ChaCha20-Poly1305 without strict-kex is.

Exploitation primitive — there is no public weaponised tool that yields RCE. What Terrapin actually buys an in-path attacker:

1. Silent drop of the first encrypted packet, which is usually `SSH_MSG_EXT_INFO`. That message advertises extensions such as `server-sig-algs` (negotiates signature algorithms beyond defaults) and `ping@openssh.com`. Dropping it can force fallback to weaker signature algorithms (e.g. SHA-1 RSA on legacy servers) or disable side-channel countermeasures.
2. On AsyncSSH and a handful of other libraries, additional implementation bugs chained with Terrapin produced auth-bypass and signature-forgery primitives (CVE-2023-46445/46446). Those are library-specific, not in OpenSSH.
3. Disabling the keystroke-timing obfuscation that was introduced as a Spectre/timing-mitigation extension — re-enabling timing-based password-length inference attacks.

The scanner workflow during an engagement: enumerate all SSH endpoints, run Terrapin-Scanner across the list, report any host that advertises a vulnerable cipher without strict-kex. Treat as an attack-surface finding rather than a one-shot exploit.

## Detection and defence
- Server-side, upgrade OpenSSH to ≥ 9.6, libssh ≥ 0.10.6 / 0.9.8, PuTTY ≥ 0.80, AsyncSSH ≥ 2.14.2, Dropbear ≥ 2024.85. These advertise `kex-strict-*-v00@openssh.com` and abort the connection if a sequence-number mismatch is detected during the handshake.
- Mitigation without an upgrade: configure both peers to negotiate only `aes*-gcm@openssh.com` ciphers and `hmac-sha2-256` / `hmac-sha2-512` MACs (not the `-etm` variants). GCM uses an implicit nonce that is not vulnerable.
- Network-side detection is hard — the attack is in-path and the packet counts are tiny. Pinning known host-key fingerprints and using SSHFP DNSSEC reduces the MITM window but does not stop the underlying flaw on a vulnerable algorithm pair.
- Inventory check: `nmap --script ssh2-enum-algos`, `ssh-audit`, and Terrapin-Scanner across the estate.

## References
- [terrapin-attack.com](https://terrapin-attack.com/) — official disclosure site with the technical paper and scanner.
- [USENIX Security 2024 — Terrapin paper](https://www.usenix.org/conference/usenixsecurity24/presentation/bsemann) — full academic write-up of the prefix-truncation primitive.
- [OpenSSH 9.6 release notes](https://www.openssh.com/txt/release-9.6) — `strict-kex` extension and Terrapin mitigation details.
