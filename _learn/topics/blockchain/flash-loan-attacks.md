---
title: Flash Loan Attacks
slug: flash-loan-attacks
---

> **TL;DR:** Borrow millions of tokens with zero collateral inside a single transaction, distort a price oracle or liquidity pool, and exit with profit before the loan must be repaid.

## What it is
Flash loans (Aave, dYdX, Balancer) let any address atomically borrow uncollateralised liquidity provided everything is repaid by the end of the same transaction. Attackers weaponise this capital to shift AMM reserves, manipulate oracles, or trigger logic that assumes "no one can hold this much". The bZx incidents (Feb 2020) were the canonical first instance; Harvest Finance, PancakeBunny, and Beanstalk followed with eight- and nine-figure losses.

## Preconditions / where it applies
- Target protocol reads price from a manipulable single-block source (DEX spot, internal reserve)
- Reward / collateral / liquidation logic that scales with attacker-controlled balances
- A flash loan venue with enough TVL to swing the target pool meaningfully
- No per-block TWAP, circuit breaker, or oracle deviation cap

## Technique
```solidity
function executeOperation(address asset, uint256 amount, ...) external returns (bool) {
    // 1. Dump borrowed asset to skew AMM price
    IERC20(asset).approve(router, amount);
    router.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp);

    // 2. Call victim that reads the now-distorted spot price
    victim.deposit(collateral);      // mints inflated share value
    victim.borrow(maxAgainstShares); // or liquidate, or claim rewards

    // 3. Reverse the swap, repay flash loan + 0.09% fee
    router.swapExactTokensForTokens(out, 0, reversePath, address(this), block.timestamp);
    IERC20(asset).approve(pool, amount + premium);
    return true;
}
```
Net result: profit drawn from victim, loan repaid, all in one atomic tx so a revert undoes nothing for the attacker.

## Detection and defence
- Auditor red flags: `getReserves()` or `balanceOf(pair)` used directly as price, single-block share accounting, reward math that trusts `totalSupply` mid-tx
- Use Chainlink aggregators or Uniswap V3 TWAP windows of at least 30 minutes
- Cap per-block deposits/withdrawals; require multi-block delays for large positions
- Reentrancy guards (see [[reentrancy]]) do not stop flash loans — they are not reentrant calls
- Monitoring: Forta bots for abnormal pool deltas, Tenderly alerts on oracle deviation

## References
- [Aave flash loan docs](https://docs.aave.com/developers/guides/flash-loans) — official mechanics
- [Rekt: bZx post-mortem](https://rekt.news/bzx-rekt/) — early flash-loan-as-weapon write-up
- [Euler Labs: oracle manipulation](https://blog.euler.finance/the-poetry-of-the-defi-attacks-d8d8a36c3f1f) — defence patterns

See also: [[oracle-manipulation]], [[reentrancy]], [[smart-contracts-overview]].
