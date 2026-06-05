---
title: Bridge attacks — modern patterns
slug: bridge-attacks-modern
aliases: [cross-chain-bridge-attacks, bridge-hacks]
---

> **TL;DR:** Cross-chain bridges are the single largest source of cumulative DeFi losses. Most major bridge hacks (Ronin, Wormhole, Nomad, Multichain, Harmony, Poly Network) fall into one of four classes: (1) trusted-signer key compromise / quorum bypass, (2) proof-verification logic error, (3) replay / cross-chain message uniqueness failure, (4) liquidity-side oracle manipulation. Companion to [[oracle-manipulation]] and [[reentrancy]].

## Why bridges are the highest-impact target

A bridge holds **pooled liquidity** of an asset on the source chain. When a user moves the asset, the bridge mints / releases on the destination chain. If the bridge's verification logic is wrong, the attacker can mint without depositing, or withdraw without burning. The pool drains.

The economics are uniquely bad: bridges concentrate value, and the verification logic is novel code (not standard ERC-20 patterns), so it accumulates bugs faster than the rest of DeFi.

## Class 1 — Trusted signer key compromise / quorum

Many bridges use a **multi-sig of validators**. Withdrawals on chain B require N-of-M validator signatures attesting that a deposit on chain A occurred.

Failure modes:
- N too low (Ronin: 5-of-9; attacker compromised 5 keys).
- Validator set static and undocumented.
- Validator private keys stored at one provider / one cloud.
- Validator software runs unhardened; phishing one developer compromises the validator key.

Ronin (2022, ~$625M): attacker compromised 4 Sky Mavis validator keys via spear-phishing, then used a delegated permission to obtain the 5th from Axie DAO. Threshold met.

Defensive baseline: 2/3 honest threshold (Byzantine fault), key diversity (different operators, geographies, custody), hardware-bound keys, rotation, monitoring.

## Class 2 — Proof verification logic error

Some bridges use **light-client proofs** or **zk-proofs** instead of trusted validators. The verifier contract on chain B checks proof of state on chain A.

Bugs:
- Verifier accepts proofs with invalid leaves (Wormhole 2022: signature verification skipped because the `signature_set` account was attacker-controlled).
- Verifier doesn't enforce chain-id binding (Nomad 2022: zero-hash root accepted, "trusted message" check bypassed).
- Merkle proof check off-by-one allows a non-membership proof to be accepted.
- ZK verifier incorrect circuit constraint.

Wormhole (Feb 2022, ~$326M): the Solana side allowed a forged "guardian signature set" because the program didn't verify the sysvar account was the legitimate one. A single fake signature was accepted; bridge minted 120k wETH without deposit.

Nomad (Aug 2022, ~$190M): an upgrade set the trusted-root for the messaging protocol to `0x00...0`. Every message had a "proven" status because the zero-root matched any proof. Anyone could withdraw any message. The exploit was so simple it became a public free-for-all.

## Class 3 — Replay / message-uniqueness failure

Cross-chain messages must be unique. If a chain B verifier doesn't track which messages it has already processed, an attacker can replay a single legitimate withdrawal multiple times.

Variants:
- Missing nonce / replay-protection.
- Nonce stored in storage that's writable by attacker.
- Cross-version replay — message valid on chain B v1 also valid on chain B v2.

Poly Network (Aug 2021, $610M): attacker manipulated the cross-chain "keeper" by forging messages that updated the keeper public key, then signed legitimate-looking withdrawals.

## Class 4 — Liquidity-side oracle manipulation

Bridges that use a **price oracle** for asset conversion (e.g., wrapped vs native) can be manipulated by:
- Single-block flash-loan that distorts the pool the oracle reads.
- Time-weighted oracle with too-short window.
- Bridge converts at a rate that allows extraction.

See [[oracle-manipulation]] and [[flash-loan-attacks]] for the underlying class.

## Class 5 — Approval / call-back / delegatecall

Some bridges expose a generic "execute arbitrary call on the destination" feature for composability. If the bridge holds funds and the call target can be specified by the message, an attacker who can forge a message can call arbitrary code while the bridge is the caller — effectively `delegatecall` style abuse.

See [[delegatecall-storage-collision]] for adjacent.

## How to audit a bridge

Read the docs of the messaging protocol first. Then for the implementation:

1. **Identify the trust assumption.** Multi-sig? Light client? ZK?
2. **Map the verifier.** Walk every check in the verifying function.
3. **Look for `if (… == 0)`** style edge cases (Nomad's failure).
4. **Find the replay store.** Where is "processed messages" tracked? Is the storage layout immune to upgrade?
5. **Check upgrade paths.** Trusted-root resets, validator set changes — who authorises, what verification.
6. **Trace user-supplied callbacks** all the way through.
7. **Test cross-chain race conditions** — message arriving while validator set is changing.

Tools: Foundry forks, Tenderly traces, Echidna for invariant-fuzzing.

## Workflow to study in a lab

1. Fork the Wormhole or Nomad pre-exploit state with Foundry.
2. Replay the exact attacker transaction; observe the path through the verifier.
3. Patch the bug; replay the attack; observe revert.
4. Author additional invariants ("no withdrawal without verified deposit") and fuzz.

## Detection

- Sudden withdrawal volume from a single address.
- Withdrawal without corresponding deposit event on source chain (the asymmetry of mint-vs-burn).
- Validator quorum changes without governance vote.

## References
- [Rekt — bridge hack archives](https://rekt.news/)
- [Wormhole post-mortem](https://wormholecrypto.medium.com/wormhole-incident-report-02-02-22-ad9b8f21eec6)
- [Nomad post-mortem](https://medium.com/nomad-xyz-blog/nomad-bridge-hack-root-cause-analysis-875ad2e5aacd)
- [Ronin Bridge incident](https://roninblockchain.substack.com/p/community-alert-ronin-validators)
- [Trail of Bits — bridge security](https://blog.trailofbits.com/)
- See also: [[oracle-manipulation]], [[flash-loan-attacks]], [[delegatecall-storage-collision]], [[reentrancy]]
