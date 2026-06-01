---
title: MEV Sandwich Attacks
slug: mev-sandwich-attacks
---

> **TL;DR:** A searcher spots a pending swap in the mempool, front-runs it with a buy, lets the victim's swap push the price, then back-runs with a sell — pocketing the slippage as MEV.

## What it is
Maximal Extractable Value (MEV) is profit a block builder or searcher captures by reordering, inserting, or censoring transactions. The "sandwich" is the textbook pattern: place tx A before the victim and tx B immediately after, both on the same AMM pool. Until private orderflow became common, public mempools on Ethereum, BSC, and Polygon leaked enough information that bots extracted billions cumulatively, most of it from retail Uniswap swaps with loose slippage.

## Preconditions / where it applies
- Victim broadcasts a swap to a public mempool with high slippage tolerance (e.g. 5%)
- Target pool's price moves materially for the victim's trade size
- Attacker can win ordering: via priority gas auction (PGA), via Flashbots / MEV-Boost bundle, or via being the block proposer
- Post-merge: searchers submit ordered bundles to relays that builders include atomically

## Technique
```solidity
// Victim's pending tx (mempool):
router.swapExactETHForTokens{value: 10 ether}(minOut, [WETH, TKN], victim, deadline);

// Searcher bundle (one block, ordered):
// tx1 — front-run: buy TKN, pushing price up
router.swapExactETHForTokens{value: 8 ether}(0, [WETH, TKN], searcher, deadline);
// tx2 — victim swap executes at worse price, near their minOut
// tx3 — back-run: dump the TKN bought in tx1 at the new higher price
router.swapExactTokensForETH(tknBalance, 0, [TKN, WETH], searcher, deadline);
```
Profit ~= victim slippage minus gas and the bundle bid paid to the builder.

## Detection and defence
- Auditor / UX red flags: default 5%+ slippage in a wallet, no deadline, swaps routed via public RPC
- Users: tighten slippage, route through private RPCs (Flashbots Protect, MEV Blocker, BloxRoute)
- Protocols: use commit-reveal, batch auctions (CoW Swap), or RFQ models that hide order details until matched
- Cap per-block trade impact; integrate Uniswap V3 oracle (see [[oracle-manipulation]]) for fair-value checks
- Monitoring: EigenPhi, libMEV dashboards; Forta bots can flag known sandwich addresses

## References
- [Flashbots docs](https://docs.flashbots.net/) — MEV-Boost, bundles, relays
- [Daian et al., Flash Boys 2.0](https://arxiv.org/abs/1904.05234) — foundational MEV paper
- [EigenPhi MEV explorer](https://eigenphi.io/) — live sandwich telemetry

See also: [[flash-loan-attacks]], [[oracle-manipulation]], [[ethereum-blockchain]].
