---
title: Smart contracts — overview
slug: smart-contracts-overview
---

> **TL;DR:** Deterministic programs that custody assets and run on every full node; bugs are exploited in public, in seconds, and patched only by social coordination or upgrade. The audit mindset is "every external call is hostile, every input adversarial, every revert path matters."

## What it is
A smart contract is a deployed EVM (or alt-VM: SVM, MoveVM, CosmWasm) program identified by an address. Its code is immutable post-deploy unless the design embeds an upgrade pattern (proxy + implementation). Its state is on-chain and publicly readable. It can hold native currency and tokens, and it executes when a tx calls one of its external functions — possibly via a chain of other contracts.

Three families of vulnerability dominate:
1. **Code bugs.** Reentrancy, integer issues, access control, missing input validation, signature replay, storage-layout collisions in proxies.
2. **Economic / oracle bugs.** Price manipulation via spot AMMs, donation attacks on share-based vaults, flash-loan amplified accounting errors.
3. **MEV / ordering bugs.** Sandwiches, frontruns, JIT liquidity, and assumptions about who sees a tx first.

## Preconditions / where it applies
- Any deployed EVM contract is in scope from the moment it holds value
- Cross-chain bridges and L1↔L2 messaging widen the attack surface beyond a single contract
- DeFi compositions: a bug in one protocol becomes a bug in everything that integrates it (read-only reentrancy, oracle reads)
- Off-chain components: signer keys, sequencer, relayer, multisig owners — often the easier target

## Technique
The audit workflow:

1. **Scope.** Pull the source from Etherscan or the repo. List every external/public function and rank by "what does it move?" (mint, withdraw, upgrade, set-owner, set-fee).
2. **Diff against known patterns.** Is it a fork of Uniswap V2 / Compound / OpenZeppelin? Diff the deployed code against the upstream to surface modifications — that's where the bugs are.
3. **Storage layout.** For upgradeable contracts, compare slots between implementations to catch [[access-control-bugs]] storage collisions.
4. **Trust assumptions.** Who is `owner`, who is the multisig, what does each role do, what's timelocked vs instant.
5. **External interactions.** Every `call`, `transfer`, `transferFrom`, `delegatecall` is a re-entry point. Every oracle read is a manipulation point.
6. **Write PoCs.** Use [[foundry-toolkit]] to fork mainnet at a recent block and reproduce the suspected bug end-to-end.
7. **Property-fuzz invariants.** Examples: `sum(balanceOf) == totalSupply`, `totalAssets >= totalLiabilities`, `price within [min,max]`. Echidna / Foundry invariants surface accounting drift.

Recon helpers:
```bash
cast etherscan-source 0xCONTRACT --etherscan-api-key $KEY
slither 0xCONTRACT --etherscan-apikey $KEY
forge inspect MyContract storageLayout
```

## Detection and defence
- Pre-deploy: multiple audits, formal verification of critical invariants (Certora, Halmos), fuzzing in CI, testnet shadow-deploy with bug bounty.
- Post-deploy: on-chain monitoring (Forta, OpenZeppelin Defender, Tenderly alerts) on owner changes, large transfers, abnormal gas, paused/upgrade events.
- Upgrade + pause path with a timelock-protected admin behind a multisig.
- Insurance / circuit breakers: per-block withdrawal caps, oracle deviation circuit breakers.

Related: [[reentrancy]], [[access-control-bugs]], [[integer-overflow-solidity]], [[solidity-basics]], [[ethereum-blockchain]], [[foundry-toolkit]].

## References
- [Smart Contract Weakness Classification](https://swcregistry.io/) — SWC registry
- [Trail of Bits — Building Secure Contracts](https://github.com/crytic/building-secure-contracts) — audit checklist + workshops
- [Damn Vulnerable DeFi](https://www.damnvulnerabledefi.xyz/) — practice CTF for DeFi bugs
- [Rekt News](https://rekt.news/) — post-mortems of major incidents
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) — reference safe primitives
