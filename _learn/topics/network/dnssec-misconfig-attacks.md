---
title: DNSSEC misconfig attacks
slug: dnssec-misconfig-attacks
aliases: [dnssec-attacks, dnssec-misconfig]
---

> **TL;DR:** DNSSEC adds cryptographic signatures to DNS records, validated by resolvers via a chain rooted in the IANA root key. Properly deployed, it prevents cache poisoning and on-path DNS tampering. Misconfigurations are the modern issue: expired signatures, missing DS records at the registrar, key rollover failures, NSEC zone-walking, and KeyTrap (CVE-2023-50387) — a class of resource-exhaustion attacks on validating resolvers. Companion to [[bgp-hijack-attacks]] and [[dangling-dns-takeover]].

## Why DNSSEC matters

- **Authenticates** DNS responses against on-path tampering.
- **Required** for some TLD policies; voluntary elsewhere.
- **Underpins** newer protocols (DANE for email, others).
- Deployment ~20% of zones globally; uneven by sector.
- Misconfigurations cause **outages**, not just security issues — DNSSEC failure means resolvers refuse the response.

## DNSSEC mechanism recap

- Zone owner signs records with **ZSK (Zone Signing Key)**.
- ZSK signed by **KSK (Key Signing Key)**.
- KSK's DS (Delegation Signer) record published in parent zone.
- Chain validates from root → TLD → zone.

Records:
- **DNSKEY** — public keys.
- **RRSIG** — signature on RRset.
- **DS** — delegation signer at parent.
- **NSEC / NSEC3** — proof of non-existence.

## Class 1 — Expired RRSIG

RRSIG records have validity periods (typically days to weeks). If signatures aren't refreshed before expiry:
- Validating resolvers reject the records.
- Domain becomes unreachable to those resolvers.

Famous outages: Slack (multiple times), various .gov domains. The DNSSEC failure is harmless from an authenticity perspective but operationally catastrophic.

## Class 2 — Missing / stale DS at registrar

When KSK rotates, DS record at parent must update. Failure:
- Old DS doesn't validate new key.
- Validating resolvers reject.

KSK rollover protocol (RFC 7344, RFC 8901 ACL2) standardises automated DS update; many registrars don't support, requiring manual.

## Class 3 — Key rollover failures

ZSK rollover should be transparent if double-signing window respected. Common errors:
- Rotate keys too quickly; cached records have old RRSIG.
- Pre-publish without overlap; gaps when no signature matches.

Resolvers see signature-not-matching-key during the gap.

## Class 4 — NSEC zone walking

NSEC records prove non-existence of names by listing the next name in the zone. Attacker walks:
- Query A.example.com → NSEC says "next is C.example.com, so B doesn't exist".
- Repeat with C → next is D.
- Walk the entire zone.

Reveals every domain in the zone. Sensitive for internal-only zones or honeypots.

**NSEC3** with hashed names mitigates (but not perfectly; rainbow tables can crack short names).

**NSEC3 with opt-out** is even weaker — used for performance but limits authenticated denial.

## Class 5 — KeyTrap (CVE-2023-50387, 2024)

Disclosed by ATHENE / Tel Aviv researchers. A class of attacks where crafted DNS responses cause validating resolvers to perform CPU-intensive validation, including:
- Many DNSKEY records.
- Collisions in key tag (KeyTag is non-cryptographic; multiple keys can share).
- Lookups across all candidate keys → exponential blowup.

Resulted in CVEs for BIND, Unbound, PowerDNS, Knot, and others. Patches restrict key processing.

Still being explored; class likely has more variants.

## Class 6 — Algorithm downgrade

DNSSEC supports multiple algorithms (RSA-SHA1, RSA-SHA256, ECDSA, Ed25519). If a zone publishes records under multiple algorithms and the resolver chooses the weakest:
- Attacker can forge with weaker key.

Modern resolvers prefer strong; legacy interop concerns exist.

## Class 7 — Resolver behaviour on validation failure

Different resolvers handle failures differently:
- **Strict**: refuse the response → no DNS for the domain.
- **Permissive**: accept the response → no DNSSEC protection.
- **Mixed**: log + serve.

A zone with chronically failing DNSSEC effectively unprotected for users on permissive resolvers.

## Class 8 — DNS cookies + DNSSEC interaction

DNS cookies (RFC 7873) and DNSSEC interact in fragmentation handling. Some implementations have bugs where fragmented responses leak.

## Defence and operational baseline

### For zone operators

- **Automated key rollover** — Bind 9.16+, Knot DNS, PowerDNS have automation.
- **DNSSEC monitoring** — alert on RRSIG expiry < 7 days.
- **DS-record health** — automated registrar updates where supported (CDS / CDNSKEY).
- **Use NSEC3** with sufficient iterations or NSEC3-with-opt-out only for performance critical.
- **Strong algorithms** — ECDSA P-256 or Ed25519 preferred; phase out RSA-SHA1.

### For resolver operators

- **Validating resolvers**, patched for KeyTrap-class.
- **Aggressive NSEC caching** (RFC 8198) to reduce queries.
- **DoT / DoH** for last-mile encryption.

### For users

- **Use validating resolver** (Cloudflare 1.1.1.1, Google 8.8.8.8, Quad9 9.9.9.9 all validate).
- **DoT / DoH** to prevent on-path tampering between client and resolver.

## Testing your zone

- **dnssec-analyzer.verisignlabs.com** — Verisign Labs.
- **dnsviz.net** — comprehensive DNSSEC checker.
- **delegation-only.org**.
- **dig +dnssec** for manual.

## Workflow to study

1. Set up a local zone with BIND or Knot.
2. Sign it; publish DS at parent.
3. Validate from a resolver.
4. Let signatures expire; observe failure.
5. Practice rollover.
6. Read KeyTrap disclosure.

## Related

- [[bgp-hijack-attacks]] — adjacent.
- [[dangling-dns-takeover]] — adjacent.
- [[subdomain-takeover]] — adjacent.
- [[dns-rebinding]] — adjacent.
- [[tor-hidden-service-attacks]].

## References
- [DNSSEC RFCs](https://datatracker.ietf.org/wg/dnsop/documents/)
- [DNSViz](https://dnsviz.net/)
- [KeyTrap paper](https://www.athene-center.de/aktuelles/key-trap)
- [Cloudflare 1.1.1.1 DNSSEC docs](https://developers.cloudflare.com/1.1.1.1/encryption/dnssec/)
- See also: [[bgp-hijack-attacks]], [[dangling-dns-takeover]], [[dns-rebinding]], [[subdomain-takeover]]
