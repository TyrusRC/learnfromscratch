---
title: Integer over/underflow (Solidity)
slug: integer-overflow-solidity
---

> **TL;DR:** Pre-0.8.0 Solidity wraps silently on arithmetic overflow; 0.8+ reverts. Still a live class of bugs in legacy contracts, in `unchecked { ... }` blocks, in inline assembly, and in downcasts (`uint256 -> uint96`).

## What it is
EVM integers are fixed-width (`uint8` ... `uint256`, signed variants). Arithmetic that exceeds the type's range either wraps modulo 2^N (legacy / `unchecked`) or reverts (Solidity ≥ 0.8.0 default). When wrap happens silently, an attacker can mint near-infinite balance with `balance - 1` underflowing or pass a length check by overflowing a multiplication used in array-size math.

## Preconditions / where it applies
- Solidity compiler `< 0.8.0` without OpenZeppelin SafeMath
- Solidity ≥ 0.8.0 inside `unchecked { ... }` blocks (used for gas optimisation)
- Inline `assembly` blocks — Yul does not check
- Downcasts: `uint96(largeUint256)` truncates without revert
- Multiplication of user-controlled values (fees, prices, supply caps)

## Technique
1. **Classic underflow withdraw.** Pre-0.8 token:
   ```solidity
   function transfer(address to, uint256 v) public {
       balances[msg.sender] -= v;   // underflows if v > balance
       balances[to] += v;
   }
   ```
   Calling with `v = 1` while balance is 0 wraps `balances[msg.sender]` to `2^256 - 1`.
2. **`unchecked` block in modern contract.** Devs add `unchecked` around loop counters; if any user input slips into the block (a length or index calculation), wrap returns.
3. **Downcast laundering.** Vault stores `uint256` balance but a withdraw helper casts to `uint96` for packing:
   ```solidity
   uint96 amt = uint96(_amount);   // truncates high bits
   token.transfer(msg.sender, amt);
   ```
   Attacker passes `_amount = 2^96 + smallValue` to withdraw `smallValue` while debiting the full `_amount` against accounting that uses the un-truncated `uint256`.
4. **Signed shenanigans.** `int256` minimum (`-2^255`) negated stays negative; comparisons that assume positivity fail.

PoC harness with Foundry:
```solidity
function testUnderflow() public {
    vm.prank(attacker);
    vulnToken.transfer(address(0xdead), 1);
    assertEq(vulnToken.balanceOf(attacker), type(uint256).max);
}
```

## Detection and defence
- Pin compiler to `pragma solidity ^0.8.20;` or newer and avoid `unchecked` unless the bound is proven.
- Use OpenZeppelin `SafeCast` for downcasts (`SafeCast.toUint96(x)` reverts on truncation).
- Static analysis: Slither `safe-math`, `incorrect-downcast`; Mythril symbolic exec; Halmos / Certora for formal bounds.
- Code review: any `assembly`, any `unchecked`, any cast to a narrower type is a hotspot.

Related: [[reentrancy]], [[access-control-bugs]], [[solidity-basics]].

## References
- [SWC-101 Integer Overflow and Underflow](https://swcregistry.io/docs/SWC-101) — registry entry
- [Solidity 0.8.0 release notes](https://docs.soliditylang.org/en/latest/080-breaking-changes.html) — checked arithmetic
- [OpenZeppelin SafeCast](https://docs.openzeppelin.com/contracts/5.x/api/utils#SafeCast) — checked downcasts
- [Trail of Bits — unchecked math pitfalls](https://blog.trailofbits.com/2021/09/16/the-cost-of-overlooked-edge-cases/) — modern bug patterns
