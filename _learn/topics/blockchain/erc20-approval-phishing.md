---
title: ERC-20 Approval Phishing
slug: erc20-approval-phishing
---

> **TL;DR:** Tricking a user into signing an unlimited `approve` or an EIP-2612 `permit` lets the attacker drain that token from the wallet at their leisure — no further user action required.

## What it is
ERC-20 separates allowance from transfer: `approve(spender, amount)` lets `spender` later call `transferFrom`. Wallets and dApps habitually request `type(uint256).max` to save on future gas, so a single malicious signature can grant forever-rights to every token in a wallet. EIP-2612 `permit` makes it worse — it is an off-chain signature, so even a wallet with zero ETH for gas can be drained, and the signing UI often shows opaque typed-data the user cannot evaluate. Inferno Drainer, Pink Drainer, and the Monkey Drainer kits industrialised this pattern.

## Preconditions / where it applies
- Victim holds tokens with non-zero balance and signs transactions on a malicious site
- Token contract supports either `approve` (all ERC-20s) or `permit` (USDC, DAI, UNI, many newer tokens)
- Phishing UI: fake mint, fake airdrop claim, fake "security check", cloned dApp
- Wallet displays signatures with poor decoding (raw hex, generic "Sign typed data")

## Technique
```solidity
// Classic: victim signs an on-chain approve to attacker
token.approve(attacker, type(uint256).max);
// Later, on attacker's schedule:
token.transferFrom(victim, attacker, token.balanceOf(victim));

// EIP-2612 variant: no prior on-chain tx, single off-chain signature
// Victim signs typed data { owner, spender=attacker, value=max, nonce, deadline }
token.permit(victim, attacker, type(uint256).max, deadline, v, r, s);
token.transferFrom(victim, attacker, token.balanceOf(victim));

// Permit2 (Uniswap) extends this across all tokens with one signed batch —
// a single phishing sig can authorise many tokens at once.
```
Because allowances are persistent state, victims who only revoke after an attempted drain often discover dozens of stale max-approvals from years-old dApps.

## Detection and defence
- Auditor / UX red flags: dApps that request `type(uint256).max` by default, `permit` prompts on sites that do not need them, look-alike domains
- Users: prefer wallets that decode typed data (Rabby, Frame), set exact-amount allowances, audit and revoke via Revoke.cash or Etherscan Token Approvals
- Protocols: integrate Permit2 with short deadlines, never request infinite approval where a single-use one suffices
- Hardware wallets: enable clear-signing firmware; reject blind-signing for EIP-712
- Monitoring: Forta wallet-drainer bots, Blockaid / Wallet Guard browser extensions flag known drainer contracts

## References
- [EIP-2612: permit](https://eips.ethereum.org/EIPS/eip-2612) — gasless approvals spec
- [Revoke.cash guide](https://revoke.cash/learn/approvals) — how allowances persist
- [Chainalysis: wallet drainers](https://www.chainalysis.com/blog/wallet-draining-2023/) — industry-scale stats

See also: [[access-control-bugs]], [[smart-contracts-overview]], [[solidity-basics]].
