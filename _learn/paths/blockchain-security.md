---
title: Blockchain & smart-contract security
slug: blockchain-security
aliases: [smart-contract-audit, web3-security]
---

> Smart-contract security as practised by auditors, bug-bounty hunters
> on Immunefi / Code4rena, and incident responders. EVM-first because
> EVM is where the money is.

## Prereqs

- Solid programming background.
- Comfort with a stack-machine mental model (assembly background
  helps).
- Foundry installed and working.

## Stage 1 — chain mental model

Goal: read a transaction trace and explain what happened.

- [[ethereum-blockchain]] — accounts, gas, txs, EVM execution.
- [[smart-contracts-overview]]
- [[solidity-basics]] — visibility, modifiers, storage layout,
  selectors.

## Stage 2 — classic bug classes

Goal: spot each on sight while reading Solidity.

- [[reentrancy]] — checks-effects-interactions, transient storage in
  modern Solidity.
- [[integer-overflow-solidity]] — relevant on legacy 0.7-and-below.
- [[access-control-bugs]] — missing onlyOwner, tx.origin abuse,
  delegatecall-to-untrusted.
- [[airdrop-abuse]] — eligibility logic and double-claim races.
- Oracle manipulation — price-feed sandwich, flash-loan-driven
  oracle skew.
- Slippage / front-running / MEV exposure.

## Stage 3 — tooling and workflow

- [[remix-tool]] — quick PoC.
- [[foundry-toolkit]] — forge / cast / anvil; fork-mainnet PoCs are
  the standard.
- [Slither](https://github.com/crytic/slither) — static analysis.
- [Echidna](https://github.com/crytic/echidna) — property-based
  fuzzing.
- [Mythril](https://github.com/Consensys/mythril) — symbolic execution.

## Stage 4 — competing for payouts

- Read every public Code4rena and Spearbit report you can find — the
  bug-class distribution shifts every quarter.
- [Immunefi](https://immunefi.com/) bug-bounty programs.
- [Code4rena](https://code4rena.com/) contests — fixed-window audits.
- Practice: [Damn Vulnerable
  DeFi](https://www.damnvulnerabledefi.xyz/) ·
  [Ethernaut](https://ethernaut.openzeppelin.com/).

## References

- [SWC Registry](https://swcregistry.io/) — historical weakness
  catalogue.
- [Solidity by
  Example](https://solidity-by-example.org/) — pattern reference.
- [Secureum](https://secureum.xyz/) curriculum.
- [Trail of Bits Building Secure
  Contracts](https://github.com/crytic/building-secure-contracts).
- *Handbook for CTFers* (Nu1L Team, Springer) — structural source for
  this hub's smart-contract coverage.
