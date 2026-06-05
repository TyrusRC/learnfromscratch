---
title: Bitcoin Script and Taproot attack surfaces
slug: bitcoin-script-and-taproot-attacks
aliases: [bitcoin-script-attacks, taproot-attacks, btc-attacks]
---

> **TL;DR:** Bitcoin's scripting language is deliberately minimal — no loops, no state, no general computation. Most "Bitcoin attacks" target either: protocol-level concerns (51%, eclipse, selfish mining), Lightning Network channel attacks (HTLC race, justice-transaction failures), Taproot script-path concerns (revealed cohort, MAST construction bugs), or wallet / RPC misconfig. With Taproot and the BitVM / ordinals / inscriptions ecosystem, the surface has grown. Companion to [[bridge-attacks-modern]] and [[51-percent-attacks]] (if present, else see this note).

## Why Bitcoin is studied separately

- **No EVM-style smart contracts** — attack surface is fundamentally different.
- **Minimalist Script** — limited bug class but exotic constructions emerge.
- **Layer 2 (Lightning)** — most "Bitcoin DeFi" lives off-chain; channel logic is where bugs live.
- **Inscription / ordinals ecosystem** (2023+) — new attack surface via crafted inscriptions.
- **Highest economic value** — exploits pay more on average than on alt-chains.

## Class 1 — Network / consensus

- **51% attack** — double-spend by re-orging the longest chain. Mostly theoretical for Bitcoin at scale; relevant for smaller chains. Has occurred on BCH, BSV, ETC.
- **Selfish mining** — withhold blocks to gain disproportionate reward share. Theoretical for Bitcoin; has been modelled.
- **Eclipse attack** — isolate a node from the legitimate network so it accepts attacker's view. Bitcoin Core has defences (limited outbound peers, peer-banning).

## Class 2 — Transaction-level

### Pin / RBF attacks

Mempool-replacement bugs:
- **RBF (Replace-By-Fee) pinning** — attacker constructs a transaction that prevents replacement, holding the mempool slot.
- **Package relay** edge cases.
- **CPFP (Child-Pays-For-Parent)** game-theoretic edge cases.

Particularly important for Lightning Network commitments and HTLC sweeps; loss of pinning protection can mean stolen funds.

### Malleability (historical)

Pre-SegWit, transaction IDs could change post-signing. Mostly fixed by SegWit but Lightning early versions had to design around it.

## Class 3 — Script / Taproot specifics

### P2WSH / P2TR script-path concerns

Taproot supports both key-path (signature) and script-path (Merkle tree of scripts). Bugs:
- **Script-path leakage** — revealing one script reveals the tree depth and partial structure; reveals what other scripts the holder uses.
- **MAST construction errors** — bug in building the Merkle-Abstract Syntax Tree for control-block verification.
- **Annex misuse** — Taproot allows annex data; protocols using annex must agree on format.

### Time-locked scripts

`CHECKLOCKTIMEVERIFY` / `CHECKSEQUENCEVERIFY` combined with multi-sig and HTLCs. Bugs:
- Time-lock parameter off-by-one.
- Locktime / sequence semantics confused.

### OP_RETURN / inscription crafting

Inscriptions embed data in witness fields. Some indexer / relay implementations parse this data:
- Indexers parse JSON; malformed JSON causes desync.
- Inscription content acts as input to off-chain parsers; bugs there.
- BRC-20 token standard has implementation differences across indexers.

## Class 4 — Lightning Network channel attacks

LN is the largest non-on-chain Bitcoin surface.

### HTLC race / justice transactions

Channel close races: if cooperative close fails, parties broadcast commitment transactions. The dispute window allows the counterparty to broadcast a "justice transaction" if the wrong commitment is posted.

Attacks:
- **Justice failure** — wallet doesn't broadcast in time; attacker wins the race.
- **Watchtower failure** — if running, watchtowers should broadcast for you when offline.
- **Time-dilation** — attacker delays the victim's block view to push them past the dispute window.

### Channel jamming / flow attacks

Send near-zero-fee HTLCs through public channels; lock liquidity; griefing without cost (since failed HTLCs cost the sender nothing).

### Probing

Send 1-sat HTLCs to discover channel balances; map the network.

## Class 5 — Wallet / RPC misconfig

- Exposed `bitcoind` RPC on internet with weak / default credentials.
- Wallet seed-phrase storage with infostealers.
- Watch-only wallet imported on attacker-controlled device.
- Multi-sig setup with offline keys broken in implementation (`nKeyTweak` issues).

Recent (2024+) supply-chain incidents have affected hardware-wallet companion software.

## Class 6 — BitVM and rollup-on-Bitcoin

BitVM is a method for off-chain computation provable on Bitcoin via interactive challenge. Rollup designs build on it. New, evolving attack surface:
- Challenge-response protocol edge cases.
- Garbled-circuit construction.
- On-chain settlement disputes.

Audits scarce; surface evolving rapidly.

## Class 7 — DNS / SOCKS / Tor proxy

Bitcoin Core uses DNS seeds and supports Tor for anonymity. Misconfig:
- Run with `proxy=` but DNS leaks.
- Run with `onlynet=onion` but DNS seeds reach over clearnet.
- Forking attack via DNS-poisoned seed.

## Workflow to study

1. Run `bitcoind` regtest locally.
2. Send a transaction; observe mempool / block confirmation.
3. Build a multi-sig wallet; test recovery.
4. Set up two LN nodes (LND or Core Lightning) with a channel.
5. Force-close the channel; observe justice transaction logic.
6. Test RBF / CPFP scenarios.
7. Read public audit reports (Anchor, Trail of Bits, NCC) on LN implementations.

## Defensive baseline

- Use audited wallet software (Bitcoin Core, Electrum, Sparrow).
- Hardware wallet with verified vendor.
- Multi-sig for large holdings (Casa, Unchained, self-managed).
- Run own node, don't rely on third-party block explorers for security-critical info.
- For LN: watchtowers, frequent backups, time-bounded liquidity exposure.

## Related

- [[ethereum-blockchain]] — alt-VM reference.
- [[solana-program-attacks]] — alt-VM reference.
- [[bridge-attacks-modern]] — for BTC-EVM bridges.
- [[51-percent-attacks]] (if present).

## References
- [Bitcoin Core docs](https://github.com/bitcoin/bitcoin/tree/master/doc)
- [BOLT specifications (Lightning)](https://github.com/lightning/bolts)
- [Optech Bitcoin newsletter](https://bitcoinops.org/)
- [BitMEX Research](https://blog.bitmex.com/category/research/)
- [Antoine Riard — LN attacks research](https://gist.github.com/ariard)
- See also: [[bridge-attacks-modern]], [[ethereum-blockchain]], [[reentrancy]]
