---
title: Cosmos / IBC attacks
slug: cosmos-ibc-attacks
aliases: [ibc-attacks, cosmos-attacks, cosmos-sdk-attacks]
---

> **TL;DR:** Cosmos chains are application-specific blockchains built on Cosmos SDK (Go) using Tendermint consensus. Inter-Blockchain Communication (IBC) is the cross-chain protocol connecting them. Attack classes: Cosmos SDK module bugs (Go-language unsafe-cast, missing input validation, malformed Protobuf), IBC light-client state inconsistencies, packet replay, and chain-specific governance attacks. Companion to [[bridge-attacks-modern]] and [[solana-program-attacks]].

## Why Cosmos differs

- **App-specific chains** — each chain runs custom Go code on top of Cosmos SDK; bug class is "Go code with consensus", not VM-interpreted.
- **Tendermint BFT consensus** — different liveness / safety properties from PoW or PoS.
- **IBC for interop** — light-client-based cross-chain; no centralised bridge operator.
- **Governance on-chain** — chain parameters changed by token-weighted vote.
- **Validators** — typically ~50–150 active validators per chain.

The diversity of chains means each is its own audit target.

## Class 1 — Cosmos SDK module bugs

A custom module is Go code. Common bugs:
- **Missing input validation** in `MsgServer` handlers — message processed before validation.
- **Integer overflow** in fee / reward calculations (Cosmos SDK uses `sdk.Int` / `sdk.Dec` with explicit overflow checks; using raw int64 is the bug).
- **Improper error handling** — a sub-call fails silently; state corrupted.
- **Iteration over maps** — Go map iteration is non-deterministic; in a consensus-critical path this **breaks consensus**. Major class of bug.
- **Misuse of `Begin/EndBlock`** — code in block lifecycle hooks must be deterministic.

The Terra LUNA collapse, while economic in nature, exposed how custom-module bugs can cascade.

## Class 2 — IBC light-client bugs

IBC requires each side to run a light client of the other chain. Consensus / state-root verification.

Bug classes:
- **State-root verification wrong** — accept invalid roots → accept invalid packets → mint without burn.
- **Misbehaviour evidence handling** — when light client detects fork; bug here can disable cross-chain transfers or wrongly freeze.
- **Trusting period overflow** — long-running clients with parameter mismatch.

A famous 2023 disclosure: a critical issue in IBC's packet-receive verification (the "Dragonberry" issue) could have allowed counterfeit token minting cross-chain. Caught and fixed before exploitation; full patch coordinated by core devs and major chain teams.

## Class 3 — Packet replay / out-of-order

Each IBC packet has a sequence number; missing replay protection or incorrect sequence handling allows:
- Replay — same packet processed twice → double mint.
- Out-of-order — packet 5 processed before packet 4 in violation of channel ordering.

## Class 4 — Validator-set update bugs

When the validator set changes, both chains' light clients of each other must update. Bugs in this transition allow:
- **Stale validator set** accepting signatures from old validators.
- **Hostile takeover** — if attacker controls 2/3 of new validators on chain A and chain B's light client is slow to update, attacker signs fake state.

## Class 5 — Governance attacks

Cosmos chains use on-chain governance. Attacks:
- **Low-quorum exploitation** — propose changes during low-participation periods.
- **Validator concentration** — if a few validators control >2/3 stake, they control governance.
- **Time-locked execution** — proposals execute after passing; flash-attack within delay window.
- **Parameter manipulation** — propose dangerous fee / slashing changes; pass.

## Class 6 — CosmWasm module bugs

CosmWasm is a smart-contract module supporting WebAssembly contracts in Cosmos. Bug classes parallel EVM:
- Reentrancy (via cross-contract calls).
- Integer overflow.
- Access control.
- Storage corruption.

Plus WASM-specific:
- Floating-point determinism (banned in some WASM-VM configurations).
- Memory growth.

## Class 7 — Slashing avoidance / liveness manipulation

Validators that double-sign get slashed. Attacks:
- Coordinated downtime to grief liveness without slashing.
- Selective censorship in transaction inclusion.

## Recent / public incidents

- **Dragonberry IBC bug (2023)** — coordinated patch, no exploitation.
- **Several Cosmos chain DoS bugs** — module input validation gaps that crashed nodes.
- **Specific chain governance incidents** — controversial proposals with low participation.

## Audit shape for a Cosmos chain

- **Cosmos SDK version pinning** — use audited recent versions.
- **Custom-module code review** — Go-language audit focus.
- **`Begin/EndBlock` determinism** — no map iteration without sorted keys.
- **IBC client / channel parameters** — trust-period, timeout, ordering.
- **CosmWasm contracts** — Rust-audit; WASM-VM compatibility.
- **Governance parameter sanity** — voting period, deposit, quorum, threshold.
- **Validator set distribution** — Nakamoto coefficient.

## Workflow to study

1. Install `gaiad` (Cosmos Hub) or another Cosmos chain.
2. Run a local single-node devnet.
3. Write a tiny custom module with a known-vulnerable handler (no input validation).
4. Exploit it with a crafted `MsgServer` message.
5. Patch with proper validation.
6. Read public audit reports (Informal Systems, Zellic, Trail of Bits) for shape of real findings.

## Related

- [[bridge-attacks-modern]] — IBC sits adjacent to bridge classes.
- [[solana-program-attacks]] — alternate non-EVM model.
- [[move-language-audit]] — alternate non-EVM model.
- [[oracle-manipulation]] — applies to Cosmos DeFi.

## References
- [Cosmos SDK docs](https://docs.cosmos.network/)
- [IBC protocol specification](https://github.com/cosmos/ibc)
- [Informal Systems — Cosmos research blog](https://informal.systems/blog)
- [Zellic — Cosmos audits](https://www.zellic.io/blog/)
- [Trail of Bits — Cosmos audits](https://blog.trailofbits.com/)
- See also: [[bridge-attacks-modern]], [[solana-program-attacks]], [[move-language-audit]], [[oracle-manipulation]]
