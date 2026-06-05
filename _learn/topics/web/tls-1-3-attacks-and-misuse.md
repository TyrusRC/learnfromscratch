---
title: TLS 1.3 attacks and misuse
slug: tls-1-3-attacks-and-misuse
aliases: [tls-13-attacks, tls13-misuse]
---

{% raw %}

> **TL;DR:** TLS 1.3 closed most legacy attack vectors (no static RSA, no RC4, no CBC-MAC-then-encrypt, AEAD-only). The remaining surface: (1) 0-RTT replay against non-idempotent endpoints, (2) downgrade through middleboxes that don't speak 1.3, (3) certificate validation gaps in clients, (4) raw-public-key misuse, (5) ECH (Encrypted Client Hello) misconfigurations, (6) bugs in specific libraries. Companion to [[http3-quic-attack-surface]] and [[terrapin-ssh-prefix-truncation]].

## What 1.3 fixed (so you know what's gone)

- Removed: RSA key exchange, CBC ciphers, RC4, 3DES, MD5, SHA-1 in signatures, compression (CRIME), renegotiation, NULL ciphers.
- Mandatory: AEAD (AES-GCM, ChaCha20-Poly1305), Perfect Forward Secrecy via (EC)DHE.
- Faster: 1-RTT handshake; 0-RTT (with caveats).
- Encrypted: ServerHello extensions (e.g., cert chain) — passive observers see less.

## Attack class 1 — 0-RTT replay

In 1-RTT mode, the client's first application data goes over a freshly-established handshake. In 0-RTT, the client sends application data on the *first* packet using a PSK from a previous session. By spec, that data isn't replay-protected; the application must handle it.

Defence: replay protection at the application layer (idempotency tokens, anti-replay log on the server). TLS 1.3 spec explicitly warns; many apps still don't bother.

Audit:
- Find endpoints that mutate state and accept 0-RTT.
- Send the same encrypted Early Data twice; check whether the server processes both.

## Attack class 2 — downgrade

A middlebox that doesn't speak 1.3 can force 1.2. TLS 1.3 includes a downgrade-protection mechanism: the server signs a "downgrade sentinel" into the random; a 1.3 client that lands at 1.2 verifies the sentinel and aborts.

Bugs:
- Older clients without downgrade-sentinel check.
- Custom TLS stacks (mobile apps using low-level libs) skipping the check.
- Servers that *generate* the sentinel incorrectly, breaking real clients.

Test by forcing 1.2 with a server-side flag; observe whether the client's TLS library aborts.

## Attack class 3 — certificate validation gaps

TLS 1.3 doesn't change the cert validation step. Bugs still common:
- Hostname not verified against cert SAN.
- `subjectAltName` matching only on `*.example.com` matches `*.example.com.attacker.tld`.
- Expired cert accepted.
- Custom-CA store includes attacker CA (TLS interception mostly).
- Client cert auth bypassed via post-handshake auth confusion.

Audit code:
```bash
grep -rn 'InsecureSkipVerify\|ServerCertificateValidationCallback\|HostnameVerifier\|verify=False' .
```

## Attack class 4 — Encrypted Client Hello (ECH) misconfigurations

ECH hides the SNI by encrypting Client Hello fields under a public key the server publishes via HTTPS DNS records.

Misconfigurations:
- Stale ECH key in DNS — clients connect successfully but reveal SNI on fallback.
- Public key rotation not synced with origin → outages.
- Servers that fall back to plaintext SNI when ECH negotiation fails.
- Test environments leaking real domain via DNS HTTPS record.

For attackers: even with ECH on, the SNI appears in DNS lookups unless DoH/DoT is also used.

## Attack class 5 — library-specific bugs

| Library | Recent issue |
|---|---|
| OpenSSL 3.x | Various CVE-2022/2023 in CMS / X.509 parsing |
| BoringSSL | EarlyData replay handling edge cases |
| s2n (AWS) | TLS 1.3 PSK binding |
| GnuTLS | Cert parsing / chain validation |
| Java SSLEngine | post-handshake auth |

For client-side fingerprinting: JA3/JA4 (TLS handshake fingerprint) identifies the library and configuration. Use to detect non-browser clients impersonating browsers (mismatched JA4 + UA).

## Attack class 6 — session ticket abuse

TLS 1.3 introduces NewSessionTicket. Tickets are server-encrypted state. Bugs:
- Server uses static ticket-encryption key for years → past sessions decryptable if key leaks.
- Tickets carry user identity without re-validation on resume → session-fixation-like.
- Anti-replay window too long for 0-RTT.

## CAA / Certificate Transparency angle

Not direct TLS attacks but pre-attack:
- CAA records on a domain restrict which CAs may issue. Misconfigured CAA → attacker uses a different CA.
- CT logs (crt.sh) reveal every cert issued for a domain — recon for subdomains, dev environments.

## Bug-bounty patterns

- Apps that allow customers to upload custom TLS certs without validating they belong to the customer's domain → token theft via signed-by-attacker cert.
- API endpoints that accept any cert that chains to a trusted CA (server should check specific issuer).
- Pinning bypass via cert revocation handling — some clients fall back to "accept" when revocation status unavailable.

## Tools

- **openssl s_client -tls1_3** — manual probes.
- **testssl.sh** — broad TLS audit.
- **ja4-plus** — fingerprinting.
- **mitmproxy** — observe and break TLS.
- **wireshark + SSLKEYLOGFILE** — decryption.

## OSCP/OSEP relevance

Limited — testing for HTTPS endpoints + WAF behaviour comes up.

## References
- [RFC 8446 — TLS 1.3](https://datatracker.ietf.org/doc/html/rfc8446)
- [draft-ietf-tls-esni — Encrypted ClientHello](https://datatracker.ietf.org/doc/draft-ietf-tls-esni/)
- [Cloudflare — TLS 1.3 series](https://blog.cloudflare.com/rfc-8446-aka-tls-1-3/)
- [testssl.sh](https://github.com/drwetter/testssl.sh)
- See also: [[http3-quic-attack-surface]], [[terrapin-ssh-prefix-truncation]], [[oauth-modern-attacks]]

{% endraw %}
