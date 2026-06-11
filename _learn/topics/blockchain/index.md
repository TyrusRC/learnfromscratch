---
title: Blockchain / Smart Contracts — topics
slug: blockchain-index
aliases: [blockchain-topics, smart-contract-index]
---

EVM-flavoured smart-contract security. See [[blockchain-security]] for
ordering.

## Foundations
- [[smart-contracts-overview]]
- [[ethereum-blockchain]] · [[solidity-basics]]

## Consensus-layer attacks
- [[51-percent-attacks]]

## Bug classes
- [[reentrancy]]
- [[integer-overflow-solidity]]
- [[access-control-bugs]]
- [[airdrop-abuse]]
- [[delegatecall-storage-collision]]

## DeFi-specific attacks
- [[flash-loan-attacks]]
- [[oracle-manipulation]]
- [[mev-sandwich-attacks]]
- [[erc20-approval-phishing]]

## Modern DeFi attack patterns
- [[bridge-attacks-modern]] — cross-chain bridge classes
- [[erc4626-vault-attacks]] — vault inflation / donation
- [[permit-eip2612-phishing]] — Permit / Permit2 signature phishing
- [[nft-signature-replay]] — Seaport-style NFT phishing
- [[l2-rollup-sequencer-attacks]] — Arbitrum / Optimism / ZK surfaces
- [[stablecoin-depeg-attacks]] — peg-mechanism failure classes

## Non-EVM chains
- [[solana-program-attacks]] — Solana / Anchor program bugs
- [[move-language-audit]] — Sui / Aptos Move audit
- [[cosmos-ibc-attacks]] — Cosmos SDK + IBC
- [[bitcoin-script-and-taproot-attacks]] — Bitcoin / Lightning surface
- [[cross-chain-multi-vm-attacks]] — multi-VM seam patterns

## Tooling
- [[remix-tool]] · [[foundry-toolkit]]
