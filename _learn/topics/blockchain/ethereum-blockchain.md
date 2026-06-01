---
title: Ethereum blockchain
slug: ethereum-blockchain
---

> **TL;DR:** A replicated state machine: accounts hold balance + code + storage, the EVM mutates them deterministically per transaction, miners/proposers order blocks and you pay in gas. This is the mental model you need to read traces and reason about smart-contract bugs.

## What it is
Ethereum is a quasi-Turing-complete distributed virtual machine. State is a Merkle-Patricia trie keyed by 20-byte addresses; each account is either an EOA (externally owned, controlled by a secp256k1 keypair) or a contract (code + per-account storage trie). A transaction is a signed message that triggers EVM execution, charging gas for every opcode. Since The Merge (Sep 2022) consensus is proof-of-stake; the post-Dencun (Mar 2024) data layer adds blob-carrying transactions (EIP-4844) used by rollups.

## Preconditions / where it applies
- Reading on-chain state, decoding tx traces, or writing PoCs that interact with mainnet/forknet
- Understanding why a transaction reverted, who can call a function, what storage slot holds what
- Building or auditing anything that runs on an EVM chain (Ethereum, Arbitrum, Optimism, Base, Polygon, BSC, Avalanche C-chain)

## Technique
Key primitives to internalise:

1. **Accounts.** EOA = address derived from `keccak256(pubkey)[12:]`. Contract = address derived from `keccak256(rlp(sender, nonce))[12:]` for `CREATE` or `keccak256(0xff || sender || salt || keccak256(initcode))[12:]` for `CREATE2`.
2. **Gas.** Every opcode has a cost; tx specifies `maxFeePerGas` / `maxPriorityFeePerGas` (EIP-1559). The `base fee` is burned, priority fee paid to the proposer. Out-of-gas = revert.
3. **Storage.** Per-contract slot map. `mapping(k => v)` lives at `keccak256(abi.encode(k, slot))`. Use `cast storage <addr> <slot>` to read.
4. **Calls.** `CALL` runs target code in target context. `DELEGATECALL` runs target code in caller's context (used by proxies — and the source of many ownership bugs). `STATICCALL` forbids state writes.
5. **Logs / events.** Indexed topics + data, written to bloom filters in the block. The canonical attribution source.
6. **Reading state:**
   ```bash
   cast call 0xCONTRACT "balanceOf(address)(uint256)" 0xVICTIM --rpc-url $RPC
   cast storage 0xCONTRACT 0
   cast 4byte-decode 0xa9059cbb000...
   ```
7. **Forking for PoC.** `anvil --fork-url $RPC --fork-block-number N` gives you a local mainnet clone where you can `vm.prank` any address.

## Detection and defence
- Defenders use trace-level monitoring (Tenderly, Phalcon, OpenZeppelin Defender) to flag suspicious `selfdestruct`, `delegatecall`, large `transfer`s.
- For RPC providers: rate-limit `eth_call` with high gas, watch for `debug_traceCall` abuse.
- For users: hardware wallets, EIP-712 typed-data signing prompts, and address book / simulation in the wallet UI.

Related: [[smart-contracts-overview]], [[solidity-basics]], [[foundry-toolkit]].

## References
- [Ethereum.org developer docs](https://ethereum.org/en/developers/docs/) — accounts, txs, EVM, gas, consensus
- [Yellow Paper](https://ethereum.github.io/yellowpaper/paper.pdf) — formal EVM spec
- [EVM Codes](https://www.evm.codes/) — opcode reference with gas costs
- [EIP-1559](https://eips.ethereum.org/EIPS/eip-1559) — fee market
- [EIP-4844](https://eips.ethereum.org/EIPS/eip-4844) — blob transactions
