---
title: Foundry toolkit
slug: foundry-toolkit
---

> **TL;DR:** Rust-based Solidity dev kit — `forge` for build/test/fuzz, `cast` for RPC + ABI surgery, `anvil` for local mainnet forks. The de-facto 2025 stack for writing audit PoCs.

## What it is
Foundry is a fast, Rust-implemented EVM development toolkit. Tests are written in Solidity itself against a cheatcode-enriched VM (`vm.*`), which means PoCs can deploy contracts, fork mainnet at a block, impersonate any address, manipulate time and storage, and assert revert reasons — all without leaving the language under test.

## Preconditions / where it applies
- Reproducing an exploit against a known mainnet contract at a specific historical block
- Property-based fuzzing of state machines (`forge test --match-test testInvariant_`)
- Quick on-chain reads/writes from the shell without writing a script
- Spinning a local fork to safely replay or test transactions

## Technique
**Install + init.**
```bash
curl -L https://foundry.paradigm.xyz | bash && foundryup
forge init my-poc && cd my-poc
```

**Forked PoC pattern.** Pin to a block just before the exploit, prank the attacker, run the steps:
```solidity
contract Exploit is Test {
    function setUp() public {
        vm.createSelectFork(vm.envString("RPC"), 17_000_000);
    }
    function testDrain() public {
        address attacker = makeAddr("attacker");
        vm.startPrank(attacker);
        IVictim(0xVICTIM).vulnFunction(payload);
        vm.stopPrank();
        assertGt(IERC20(TOKEN).balanceOf(attacker), 0);
    }
}
```
Run: `forge test --fork-url $RPC --match-test testDrain -vvvv` (traces include opcode-level revert reasons).

**Useful cheatcodes.** `vm.prank`, `vm.startPrank`, `vm.deal`, `vm.warp`, `vm.roll`, `vm.store` (overwrite storage slot), `vm.expectRevert`, `vm.recordLogs`, `vm.mockCall`.

**Cast one-liners.**
```bash
cast call $C "balanceOf(address)(uint256)" $V --rpc-url $RPC
cast send $C "approve(address,uint256)" $SPENDER 1e18 --private-key $PK
cast sig "transfer(address,uint256)"          # -> 0xa9059cbb
cast --calldata-decode "transfer(address,uint256)" 0xa9059cbb...
cast storage $C 0 --rpc-url $RPC
```

**Anvil.** `anvil --fork-url $RPC --fork-block-number N` gives you a JSON-RPC at `localhost:8545` with 10 funded accounts. Use `anvil_impersonateAccount` to send tx as any address.

**Fuzzing + invariants.** Annotate test args with `function testFoo(uint256 x)`; Foundry generates inputs. For stateful properties use `invariant_*` tests and a handler contract.

## Detection and defence
Not a defensive tool, but the same workflow defenders use:
- Post-incident: fork at the exploit block-1, replay the attacker tx, instrument with `vm.recordLogs` to attribute fund flow.
- Pre-deploy: invariant fuzzing catches accounting bugs (`sum(balanceOf) == totalSupply`).
- CI: `forge test --gas-report` and `forge coverage` gate merges.

Related: [[remix-tool]], [[solidity-basics]], [[smart-contracts-overview]], [[ethereum-blockchain]].

## References
- [Foundry Book](https://book.getfoundry.sh/) — official docs
- [Foundry cheatcodes reference](https://book.getfoundry.sh/cheatcodes/) — full `vm.*` list
- [Damn Vulnerable DeFi (Foundry)](https://www.damnvulnerabledefi.xyz/) — PoC training ground
- [Secureum gas + invariants notes](https://secureum.substack.com/) — practical patterns
