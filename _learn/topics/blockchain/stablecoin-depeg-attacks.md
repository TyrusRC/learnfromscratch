---
title: Stablecoin de-peg attacks
slug: stablecoin-depeg-attacks
aliases: [stablecoin-attacks, ust-depeg, depeg-exploitation]
---

> **TL;DR:** Stablecoins maintain their peg through different mechanisms — fiat-backed reserves (USDC, USDT), crypto-overcollateralised (DAI), algorithmic (UST historical), or LST-backed (frxETH, stETH). Each mechanism has its own attack class: reserve audit failure, oracle manipulation, mint/burn arbitrage gaming, redemption-queue races, governance attacks. Studying Terra/UST 2022, USDC 2023 SVB de-peg, and several DAI / sUSD edge cases gives the full pattern set. Companion to [[oracle-manipulation]] and [[bridge-attacks-modern]].

## Classes of stablecoin

1. **Fiat-backed centralised** — USDC, USDT, BUSD. Issuer holds USD reserves; minting / redeeming through issuer.
2. **Crypto-overcollateralised** — DAI, LUSD. Users deposit ETH/wBTC, mint stablecoin. CDP-style.
3. **Algorithmic (pure)** — historical UST (Terra). No collateral; arbitrage with sister-token.
4. **Algorithmic (hybrid)** — Frax, ESD. Partial collateral + algorithmic mint/burn.
5. **LST-backed** — frxETH, ankrETH. Backed by liquid staking tokens.

Each interacts with the broader DeFi ecosystem through pools, oracles, and lending markets — so its de-peg propagates.

## Attack 1 — Reserve audit / proof-of-reserves failure

Fiat-backed: peg holds because the issuer can always redeem 1:1 with the USD reserves.

Failure modes:
- Issuer **doesn't actually have reserves** (Tether historical concerns).
- Reserves held in **risky instruments** — commercial paper, treasuries with maturity risk.
- Reserves held at a **single bank** — concentration risk (USDC + SVB 2023).
- Redemption channel **rate-limited or KYC-blocked** during stress.

USDC March 2023: Circle held ~$3.3B of reserves at Silicon Valley Bank, which failed. USDC de-pegged to ~$0.87 over a weekend until USG announced SVB depositor protection. Lesson: even fully-backed stablecoins can de-peg on counterparty risk.

## Attack 2 — Algorithmic death spiral

UST / Terra (May 2022): UST maintained peg via arbitrage with LUNA. 1 UST always burnable for $1 of LUNA. If UST > $1, mint UST by burning LUNA. If UST < $1, burn UST to mint LUNA.

Death spiral mechanic:
1. Coordinated UST sell pressure (Curve 4pool drain).
2. UST de-pegs to $0.99 then $0.95.
3. Arbitrageurs burn UST → mint LUNA → sell LUNA for USD.
4. LUNA supply expands, LUNA price drops.
5. UST holders panic, more sell pressure.
6. LUNA hyperinflates, arbitrage stops working, peg collapses entirely.

The system has no terminal stability without external collateral. Algorithmic stablecoins are now widely considered uninvestable.

## Attack 3 — Oracle manipulation of collateral

Crypto-overcollateralised stablecoins (DAI, LUSD) need to **liquidate underwater positions** to maintain solvency. Liquidation prices come from oracles.

Attack: manipulate the oracle (see [[oracle-manipulation]]) to:
- Trigger liquidations the protocol shouldn't perform → drain collateral.
- Suppress liquidations the protocol should perform → protocol becomes undercollateralised → stablecoin un-pegs.

Single-block oracle attacks via Curve pool LP-token price manipulation have hit several stablecoins.

## Attack 4 — Mint/burn arbitrage gaming

When mint and burn use different liquidity sources, attackers can:
- Mint stablecoin cheap, burn for expensive collateral.
- Exploit during stress when the spread widens.

Frax's AMO (algorithmic market operations) controllers had several minor incidents tuning these spreads.

## Attack 5 — Redemption-queue racing

For LST-backed and some crypto-backed stablecoins, redemption isn't instant — it's queued, sometimes for weeks. Attacks:
- **Frontrun in the queue** — pay gas to be at the head of the queue when stress hits.
- **Cancel/replace race** — game queue position.
- **Cross-protocol arbitrage** during queue delay.

## Attack 6 — Governance / parameter attack

DAOs that govern stablecoin parameters (collateral types, liquidation ratios, oracle source) can be:
- **Voted by attackers** with borrowed tokens (flash-loaned governance).
- **Bribed** via Gauges and meta-governance.
- **Proposal-rushed** before community can react.

MakerDAO has multiple proposed mitigations (delays, multisig veto) reflecting this risk.

## Attack 7 — De-peg cascade via lending markets

Stablecoin is collateral or borrowed asset on Aave / Compound / Morpho. Stablecoin de-pegs → borrowers' positions look healthier than they are (or worse) → liquidations malfunction.

Example: a stablecoin priced at $1 on an oracle but trading at $0.95 lets borrowers exit cheaply or strands lenders.

UST 2022 caused a chain reaction through Anchor Protocol and other Terra ecosystem markets.

## Audit shape for stablecoin protocols

Critical questions:
- **What's the collateral?** Fiat, crypto, LP, LST, other?
- **What oracle for collateral price?** Manipulation resistance?
- **What's the redemption channel?** Instant, queued, KYC?
- **What's the worst-case scenario** if peg breaks 5%? 20%?
- **Is there a circuit breaker?** Mint/burn pauses?
- **What's the governance structure?** Time-locks, multisig veto?

## Detection in a lab

1. Fork the protocol with Foundry.
2. Simulate de-peg event by manipulating the oracle.
3. Trace the cascade through dependent protocols (lending, DEX pools).
4. Author invariant tests for peg-stability under stress scenarios.

## References
- [Chainalysis — UST analysis](https://www.chainalysis.com/blog/terra-luna-collapse/)
- [Circle — USDC SVB statement](https://www.circle.com/blog/an-update-on-usdc-and-silicon-valley-bank)
- [MakerDAO endgame docs](https://makerdao.com/en/whitepaper/)
- [Trail of Bits — stablecoin audits](https://blog.trailofbits.com/)
- See also: [[oracle-manipulation]], [[flash-loan-attacks]], [[bridge-attacks-modern]], [[mev-sandwich-attacks]]
