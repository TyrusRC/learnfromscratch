---
title: EIP-2612 permit / Permit2 phishing
slug: permit-eip2612-phishing
aliases: [permit-phishing, permit2-phishing, signature-phishing]
---

> **TL;DR:** EIP-2612 `permit` and Uniswap's `Permit2` let users authorise ERC-20 spends via a signed message instead of an on-chain `approve` transaction. Attackers phish the signature off-chain (any dApp can prompt a wallet to sign), then submit the signed permit on-chain to drain. No transaction appears in the victim's wallet history until the drain itself; the malicious site looks like "just connecting your wallet". One of the dominant wallet-drainer techniques in 2023–2025. Companion to [[erc20-approval-phishing]] and [[oauth-token-theft]].

## Why permit-phishing is effective

- The signature is **off-chain**. The user signs a typed-data message, not a transaction. No gas. No on-chain footprint.
- Wallets historically rendered the signature payload **opaquely** (raw EIP-712 JSON). Users see "permit," not "approve attacker for unlimited USDC."
- Once signed, the attacker can submit any time within the deadline — sometimes weeks later, after the victim forgot the site.
- One signed message can authorise multiple tokens via Permit2.

## EIP-2612 vs Permit2

### EIP-2612 (per-token)

Each ERC-20 implements its own `permit()` function. The user signs a single token's allowance. Token contract verifies signature and calls `approve()` internally.

Only tokens that implement EIP-2612 are vulnerable to this exact flow (not all ERC-20s do).

### Permit2 (Uniswap, multi-token)

A single Permit2 contract intermediates allowances for any ERC-20. User signs a Permit2-formatted message; Permit2 contract spends from the user's balance.

Two flavours:
- **PermitSingle / PermitBatch** — short-lived, transferred immediately.
- **PermitWitnessTransferFrom** — single-use, no on-chain allowance state.

Permit2 is much wider attack surface because *every* ERC-20 is reachable.

## The phishing chain

1. User visits attacker site (looks like a NFT mint, airdrop checker, "wallet validator").
2. Site uses standard wallet-connect; user approves connection.
3. Site invokes `eth_signTypedData_v4` for a permit / Permit2 message.
4. Wallet displays the message. The message is JSON; non-technical users sign.
5. Attacker server receives the signed message.
6. Attacker submits `permit(...)` then `transferFrom(...)` (or Permit2 equivalents) in a single transaction or batched.
7. Victim's assets transfer to attacker.

Many production wallet drainers use this flow. Spending power up to the user's full balance for whatever token the signature covers.

## Specific drainer kit characteristics

- **Inferno Drainer**, **Pink Drainer**, **Angel Drainer** (kits sold to attackers) all implement permit-phishing.
- Some kits chain Permit2 with **Seaport signature phishing** (OpenSea exchange) to take NFTs.
- High-value addresses targeted via reverse-resolution of ENS names → DM phishing.

## Wallet UX defences that emerged

- **Blockaid / Wallet Guard / Pocket Universe**: third-party transaction simulation; flags permit signatures as high-risk.
- **MetaMask's "see what would happen"** simulation built-in.
- **Frame / Rabby**: show decoded permit details in human-readable form.
- **Hardware wallets** (Ledger) require physical confirmation; users see decoded fields.

These reduce but don't eliminate the risk; users still click through warnings.

## Audit / defensive shape for protocols

For wallets:
- Render permit / Permit2 messages with **token name**, **spender**, **amount**, **deadline** in human-readable form.
- **Warn on infinite approvals** (max-uint256 amount).
- **Warn on long deadlines** (more than a few minutes).
- Display **spender reputation** — known protocol vs unknown contract.

For dApps:
- Only request permits with **exact-amount** and **short deadline**.
- Don't request Permit2 if you don't actually need it.

## How to detect a victim's permit-phish post-hoc

- On-chain: search the victim address for `Permit2 -> transferFrom` events with the attacker as recipient.
- The original signature isn't on chain; only the consuming transaction is.
- ERC-20 `approval` event for non-zero allowance from token `permit()` execution.
- Some indexers (Dune, Etherscan) flag permit-phishing transactions.

## What victims should do

If a user has signed an unknown permit:
1. **Move remaining funds** to a fresh wallet immediately.
2. **Revoke any unconsumed Permit2 allowances** (revoke.cash, Permit2 UI).
3. **Replace nonce** by signing a new permit (or doing a same-nonce transaction) to invalidate prior signatures.
4. Note: a *signed* permit cannot be revoked off-chain; only consumed or expired. Moving funds is the only certain protection.

## Workflow to study in a lab

1. Deploy a vulnerable user wallet on Anvil.
2. Sign a Permit2 message off-chain.
3. Submit `permit(...) → transferFrom(...)` from a different account.
4. Observe drain.
5. Test detection tools (Blockaid simulation) on the same flow.

## References
- [EIP-2612 specification](https://eips.ethereum.org/EIPS/eip-2612)
- [Uniswap Permit2](https://github.com/Uniswap/permit2)
- [revoke.cash — allowance/permit hygiene](https://revoke.cash/learn/)
- [Blockaid research](https://www.blockaid.io/blog)
- [Web3 anti-scam — drainer kit analyses](https://www.scamsniffer.io/)
- See also: [[erc20-approval-phishing]], [[oauth-token-theft]], [[account-takeover-modern-chains]], [[nft-signature-replay]]
