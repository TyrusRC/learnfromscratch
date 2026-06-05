---
title: L2 rollup / sequencer attacks
slug: l2-rollup-sequencer-attacks
aliases: [optimism-arbitrum-attacks, rollup-fraud-proof, sequencer-censorship]
---

> **TL;DR:** Layer-2 rollups (Arbitrum, Optimism, Base, ZK rollups) inherit Ethereum's security model only when the fraud-proof / validity-proof machinery is live and the escape hatch is reachable. The interesting attack surfaces are: (1) sequencer censorship + delayed forced inclusion, (2) fraud-proof window manipulation in optimistic rollups, (3) bridge withdrawal verification bugs, (4) ZK circuit constraint bugs, (5) MEV exploitation of sequencer ordering. Companion to [[bridge-attacks-modern]] and [[mev-sandwich-attacks]].

## Rollup classes recap

- **Optimistic rollups** (Optimism, Arbitrum, Base) — execution is presumed correct; a 7-day fraud-proof window lets anyone challenge. Withdrawals must wait 7 days.
- **ZK rollups** (zkSync, Starknet, Polygon zkEVM, Scroll) — every batch ships with a validity proof. Withdrawals can be fast once the proof is verified on L1.

Each class has different attack surfaces.

## Attack 1 — Centralised sequencer + censorship

Most production rollups run a **single sequencer** operator. The sequencer:
- Orders transactions.
- Submits batches to L1.
- Earns gas fees and MEV.

Risks:
- **Censorship** — sequencer can deny transaction inclusion for a target user.
- **Front-running** — sequencer sees pending transactions before users do; can extract MEV.
- **Liveness loss** — if sequencer goes down, users can't transact unless escape hatch is used.

Mitigation: **forced inclusion** — submit transaction directly to L1's rollup contract; after a delay (usually hours to a day), it must be included by the sequencer.

Forced inclusion is the **escape hatch**. Audit:
- Does the rollup contract on L1 actually expose a forced-inclusion function?
- What's the delay before the sequencer must include?
- Has any user actually tested forced inclusion recently? (Some rollups have buggy forced-inclusion paths discovered only when tested.)

## Attack 2 — Fraud-proof window manipulation

Optimistic rollups assume someone will challenge. The fraud-proof game has its own attack surface:

- **Bond requirement** — to challenge, you must bond ETH. Bond may be too high for some users.
- **Challenge complexity** — interactive fraud proofs are gas-intensive; griefing possible.
- **Censorship of challenges** — if challenger needs to send tx through the sequencer, sequencer can delay.
- **Window-skip via consensus split** — if the fraud-proof window expires due to L1 reorg or delay, fraudulent state finalises.

Optimism's bedrock and Arbitrum's BoLD (Bounded Liquidity Delay) are recent mitigations; pre-bedrock systems had wider attack surface.

## Attack 3 — Withdrawal bridge bugs

Rollups withdraw to L1 via a **withdrawal Merkle tree** posted by the sequencer. The L1 contract verifies a Merkle proof of inclusion.

Bug classes:
- **Bad Merkle proof verification** (similar to [[bridge-attacks-modern]] class 2).
- **Replay** — same Merkle leaf processed twice.
- **State-root acceptance without finalised window** — accepting roots that haven't passed the fraud window.
- **Forced batch-skipping** — coordinator that skips batches to finalise faster.

## Attack 4 — ZK circuit constraint bugs

ZK rollups use SNARKs/STARKs. The verifier contract on L1 checks the proof.

Bug classes:
- **Under-constrained circuit** — the SNARK proves a property weaker than intended. Attacker constructs valid proof of fraudulent state.
- **Soundness error in proving system** — implementation bug in the proving system.
- **Public input mismatch** — verifier accepts proofs with different public input than the executor used.

Specific past incidents:
- Polygon zkEVM had a soundness issue in pre-launch testing.
- Starkware and zkSync have had auditor-disclosed circuit issues fixed pre-deployment.

These bugs are exotic; auditing them requires deep math + Solidity skills (Trail of Bits, Spearbit, Veridise specialise).

## Attack 5 — Sequencer MEV

The sequencer holds full ordering control inside L2. MEV opportunities:
- **Sandwich** swaps similar to L1 ([[mev-sandwich-attacks]]).
- **JIT (just-in-time) liquidity** in DEX pools.
- **Bridge front-running** — see large bridge deposit, front-run with own deposit, withdraw first.
- **Liquidation racing** — be the first to liquidate underwater positions.

In single-sequencer rollups, the MEV accrues to the sequencer operator. Decentralised sequencer designs (Espresso, Astria) are emerging.

## Attack 6 — Cross-rollup messaging

Bridges between L2s (often via L1) inherit all bridge risks ([[bridge-attacks-modern]]) and add sequencer-trust issues.

## Audit shape for rollup-deployed protocols

If you're auditing a protocol that deploys to a rollup:
- Identify whether your contract logic **assumes L1 finality semantics** — L2 has different reorg and finality model.
- Identify whether the protocol uses **L1 block timestamps** that L2 may approximate poorly.
- Check whether the protocol uses **block.number** vs **block.timestamp** for time-sensitive checks; L2 block numbers don't map to L1 wall-clock the same way.
- Audit **bridge interactions**: deposit / withdraw flows.

## Workflow to study

1. Read the **Arbitrum security model** doc (cover-to-cover; it's the most thorough).
2. Read the **Optimism Bedrock spec**.
3. Read the **zkSync prover docs**.
4. Look at past audit reports for each rollup (Trail of Bits, OpenZeppelin, Spearbit).
5. Try forced inclusion on a testnet — see whether the rollup honours it.

## References
- [Vitalik — "What is an L2"](https://vitalik.eth.limo/general/2021/05/23/scaling.html)
- [Arbitrum docs — security model](https://docs.arbitrum.io/inside-arbitrum-nitro/)
- [Optimism — Bedrock spec](https://specs.optimism.io/)
- [L2BEAT — risk analysis per rollup](https://l2beat.com/)
- [Trail of Bits — rollup audits](https://blog.trailofbits.com/)
- See also: [[bridge-attacks-modern]], [[mev-sandwich-attacks]], [[oracle-manipulation]], [[ethereum-blockchain]]
