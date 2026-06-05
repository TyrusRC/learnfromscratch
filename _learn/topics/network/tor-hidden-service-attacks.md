---
title: Tor / hidden service (onion) attacks
slug: tor-hidden-service-attacks
aliases: [tor-attacks, onion-service-attacks, deanonymisation-attacks]
---

> **TL;DR:** Tor provides anonymity by routing traffic through three hops with layered encryption. Hidden (onion) services are servers reachable only via Tor, addressed by a hash of their public key. Attacks on Tor users / services: traffic correlation across entry-and-exit nodes, fingerprinting via timing or website fingerprinting, exit-node tampering with cleartext, hidden-service deanonymisation via descriptor leaks / OPSEC mistakes, and clock-skew side channels. Companion to [[bgp-hijack-attacks]] and [[dnssec-misconfig-attacks]].

## Why Tor matters

- The **dominant** anonymity system for at-risk users (journalists, dissidents, researchers).
- **Dual use** — also used for crime; many attack discussions focus on de-anonymising criminals.
- **Limits**: not infinite anonymity; specific attack classes work.
- Understanding Tor is needed for both offensive (incident attribution) and defensive (protecting at-risk users) work.

## Tor recap

- User's client builds a 3-hop circuit: **entry guard** → **middle** → **exit**.
- Layered encryption peels off at each hop.
- Each hop sees only its neighbours.
- For clearnet destinations, exit node sees plaintext (if not HTTPS).
- For onion services, both ends inside Tor; no exit node.

Hidden services:
- Identified by `.onion` address derived from public key.
- Service publishes descriptors to **Hidden Service Directories (HSDirs)**.
- Client looks up descriptor, contacts via rendezvous-point.

## Class 1 — Traffic correlation

If attacker controls (or observes) both:
- The entry guard for a user.
- The destination (exit or hidden-service location).

Timing correlation links the two — same packet sizes, same intervals.

Mitigations:
- **Guard rotation** (single guard per long-period) makes correlation more reliable, not less — but the trade-off favours integrity.
- **Padding** (NetCorr, WTF-PAD, others) inserts decoy traffic. Partial mitigation.
- For at-risk users: avoid predictable traffic patterns.

Nation-state attackers passively observing major IXPs effectively run correlation at scale.

## Class 2 — Website fingerprinting

The attacker observes the user's encrypted Tor traffic and fingerprints by:
- Packet sizes.
- Timing patterns.
- Burst distribution.

Trained classifiers identify which website was visited within Tor with high accuracy on a constrained set.

Mitigations: padding, Tor browser HTTP/3 / domain padding, randomisation.

Research-grade defence; not perfect in production.

## Class 3 — Exit-node tampering / surveillance

Exit nodes see plaintext for HTTP. Malicious exit nodes have been observed:
- Injecting JavaScript into HTML pages.
- Stripping HTTPS upgrade (SSL stripping).
- Replacing Bitcoin addresses on the fly.

Mitigations: HTTPS-only, HSTS, certificate pinning, end-to-end E2E via onion.

User-side: Tor Browser enforces HTTPS-Only by default.

## Class 4 — Hidden service deanonymisation

When a `.onion` is associated with a real-world entity (administrator), pressure points:

### Server location via descriptor

HSDir caches descriptors temporarily. If attacker runs HSDir nodes:
- Observe the descriptor.
- Some timing leakage about service publishing.

Not deanonymising on its own.

### OPSEC

Most hidden-service take-downs trace to operator OPSEC failure:
- Login from clearnet IP to admin panel.
- Bitcoin wallet linked to clearnet identity.
- Posting on clearnet with same handle.
- Apache mod_status leaks internal IPs.
- PHP errors revealing local paths.

The technical Tor protocol works; the human-operations layer leaks.

### Server fingerprinting

If the service serves clearnet content too, fingerprint (HTML headers, robot.txt, server-version) matches a clearnet service.

### Exploit chain

If the service has an exploitable vulnerability (RCE, SSRF), attacker exploits and reads `/etc/hostname` or the server's outbound IP.

Multiple major dark-web markets have been deanonymised through one of these.

## Class 5 — Confirmation attacks via tagging

Attacker injects unique cookies / sessions / packet patterns at one end; observes at the other. With enough tagged sessions, deanonymisation.

Mitigations: Tor's circuit design prevents straightforward tagging; not perfect.

## Class 6 — Sybil HSDir attack

Run many HSDir nodes near a target service's hash; capture descriptors. Combined with operational metadata, gradual deanonymisation.

Tor's relay-rotation and selection algorithms mitigate; nation-states with resources can still attempt.

## Class 7 — Clock skew

Different physical machines have minute clock drift. Tor pads, but timing-side-channels of NTP, jitter, or process-resource use can fingerprint the host.

Research-grade.

## Class 8 — Bridge-node enumeration

For users in censored countries who use Bridges (unlisted entry nodes), censors enumerate by:
- Pulling bridges from email distribution.
- Probing IPs for Tor handshake.

Mitigations: obfsproxy / meek / Snowflake transports disguise.

## Operational attacks (for IR / attribution)

When investigating malware that uses Tor C2:
- Identify hidden-service descriptors collected by HSDir.
- Look at malware-side OPSEC (clearnet code-signing certs, hardcoded URLs).
- Decoy connections to honeypot hidden services.
- Coordinate with academic / law-enforcement signal data.

## Defensive baseline (users at risk)

- **Use Tor Browser** as-is; don't add plugins.
- **No bittorrent over Tor** (BitTorrent reveals real IP).
- **No personal accounts** logged in over Tor with same handle as clearnet.
- **Bridges + obfsproxy** in censorship environments.
- **Tails OS** for high-risk operations.
- **Don't open documents in Tor Browser** that might phone home (PDFs, Office).

## Defensive baseline (hidden-service operators)

- **Strict isolation** — separate user / VM / network for admin.
- **No clearnet bleed** — firewall blocks outbound except Tor.
- **No login from outside the operational identity**.
- **Audit web stack** — no error-leaking, no mod_status, no server-version.
- **Vanity-onion key gen on offline machine**, then transferred.
- **Defence-in-depth** — assume operational compromise.

## Workflow to study

1. Install Tor and Tor Browser.
2. Read the Tor design paper.
3. Stand up a small onion service (`SetupHiddenService` in torrc).
4. Probe what your own service exposes to an HSDir.
5. Read past darknet-market takedown writeups for OPSEC failures.

## Related

- [[bgp-hijack-attacks]] — adjacent class.
- [[dnssec-misconfig-attacks]] — adjacent class.
- [[domain-fronting-and-cdn-abuse]] — alternative anonymisation.
- [[opsec-fundamentals]] — adjacent.
- [[network-pentesting]].

## References
- [Tor Project — design paper](https://gitlab.torproject.org/tpo/core/torspec)
- [Tails OS](https://tails.boum.org/)
- [Tor metrics](https://metrics.torproject.org/)
- [Tor Project blog](https://blog.torproject.org/)
- [Roger Dingledine talks — DEF CON archive](https://www.defcon.org/)
- See also: [[bgp-hijack-attacks]], [[dnssec-misconfig-attacks]], [[domain-fronting-and-cdn-abuse]], [[opsec-fundamentals]]
