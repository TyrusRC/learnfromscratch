---
title: Price Oracle Manipulation
slug: oracle-manipulation
---

> **TL;DR:** When a DeFi protocol trusts a manipulable price feed, an attacker can move that feed for a single block and trick the protocol into mispricing collateral, loans, or rewards.

## What it is
Lending markets and derivatives need an external price to value collateral. If that price comes from a low-liquidity DEX pair (Uniswap V2 spot, SushiSwap reserves) or a single CEX endpoint, an attacker with enough capital — often borrowed via [[flash-loan-attacks]] — can shove the reported price up or down for one block, borrow against inflated collateral, then revert the swap. Cream Finance, Inverse Finance, and Mango Markets all lost eight figures this way.

## Preconditions / where it applies
- Protocol reads `getReserves()` or `token0Price` from a DEX pair as canonical price
- Targeted pair has shallow liquidity relative to attacker capital
- No medianiser, no TWAP, or a TWAP window short enough to manipulate over a few blocks
- Bonus: chain with low fees and fast finality so swapping costs nothing

## Technique
```solidity
// Bad: spot reserves as price feed
function getPrice(address pair) public view returns (uint256) {
    (uint112 r0, uint112 r1,) = IUniswapV2Pair(pair).getReserves();
    return (uint256(r1) * 1e18) / uint256(r0); // manipulable in one swap
}

// Attacker, same tx as a flash loan:
router.swapExactTokensForTokens(huge, 0, [WETH, COLLAT], attacker, deadline);
victim.depositCollateral(COLLAT, smallAmount);   // now valued at fake price
victim.borrow(USDC, victimLiquidity);            // drains the pool
router.swapExactTokensForTokens(out, 0, [COLLAT, WETH], attacker, deadline);
```
Chainlink-style feeds resist this because they aggregate off-chain medians from many venues and only update on heartbeat or deviation thresholds — the attacker cannot move the global market mid-block.

## Detection and defence
- Auditor red flags: any direct read of `getReserves`, `balanceOf(pair)`, or `slot0` as price; oracle with a single source
- Prefer Chainlink aggregators with deviation + heartbeat guarantees; for in-protocol pairs use Uniswap V3 TWAP over >=30 minutes
- Combine sources: require Chainlink and TWAP to agree within X bps, else pause
- Cap LTV well below liquidity depth; size markets so manipulation cost exceeds payoff
- Monitoring: Forta oracle-deviation bots, Tenderly alerts on `answer` jumps

## References
- [Chainlink: oracle manipulation defence](https://blog.chain.link/flash-loans/) — recommended patterns
- [Uniswap V3 TWAP guide](https://docs.uniswap.org/concepts/protocol/oracle) — tick cumulative math
- [Rekt: Mango Markets](https://rekt.news/mango-markets-rekt/) — $117M oracle pump

See also: [[flash-loan-attacks]], [[smart-contracts-overview]], [[access-control-bugs]].
