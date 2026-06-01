---
title: Solidity basics
slug: solidity-basics
---

> **TL;DR:** The minimum mental model: state lives in storage slots, functions are dispatched by 4-byte selectors, visibility is enforced at compile time only, modifiers wrap bodies, and `storage` vs `memory` vs `calldata` decides cost and aliasing. Read bytecode when source lies.

## What it is
Solidity is a statically typed, contract-oriented language that compiles to EVM bytecode. A contract is a struct of state variables plus functions; the deployed bytecode begins with a dispatcher that reads the first 4 bytes of calldata (`keccak256("funcSig(types)")[:4]`) and jumps to the corresponding function. Knowing the data location rules (where a variable lives at runtime) and the storage layout (slot assignment) is what separates "I can write a contract" from "I can find bugs in one."

## Preconditions / where it applies
- Reading audit targets and writing PoCs
- Reasoning about gas, reverts, and storage collisions in proxies
- Decompiling unverified contracts when only bytecode is on-chain

## Technique
**State variable layout.** Variables declared at contract scope land in storage, packed into 32-byte slots in declaration order. Booleans, small uints, and addresses are packed together; mappings and dynamic arrays use a derived slot:
- `mapping(k => v)` value at slot `keccak256(abi.encode(k, p))` where `p` is the mapping's declared slot.
- `T[] dyn` length at slot `p`, data at `keccak256(p) + i`.
- `struct` fields packed contiguously starting at the struct's slot.

```bash
forge inspect MyContract storageLayout | jq .
```

**Visibility.** `public` (auto-getter), `external` (cheaper for external callers, can't be called internally without `this.`), `internal` (subclass + this contract), `private` (this contract only — *not* secret, on-chain readable). Visibility is compile-time; nothing stops anyone from reading storage with `eth_getStorageAt`.

**Function selectors + dispatch.**
```solidity
bytes4 sel = bytes4(keccak256("transfer(address,uint256)"));  // 0xa9059cbb
```
The dispatcher is just a sequence of `EQ`/`JUMPI` against these constants. Selector collisions (cheap to find for 4-byte space) can be weaponised when a proxy forwards calldata to a logic contract.

**Modifiers.** Syntax sugar for wrapping a function body. Place `_;` where the body runs. Used for `onlyOwner`, `nonReentrant`, `whenNotPaused`. Reentrant or order-dependent logic in modifiers is a common bug.

**Data locations.** Reference types (`string`, `bytes`, arrays, structs) need a location:
- `storage` — persistent contract state (writes cost SSTORE gas)
- `memory` — temporary, allocated per-call
- `calldata` — read-only, cheapest, only valid for `external` params

Aliasing trap: assigning a `storage` pointer copies the *reference*; assigning a `memory` variable copies the *data*.

**`unchecked`, `try/catch`, low-level calls.**
```solidity
(bool ok, bytes memory ret) = target.call{value: 0, gas: 50_000}(data);
require(ok, string(ret));
```
`call` returns success bool — do *not* ignore it. `delegatecall` runs target code in caller's context (proxies); `staticcall` forbids state writes.

**Reading bytecode.** `cast disassemble` or Dedaub / Panoramix decompile unverified contracts. `cast 4byte 0xa9059cbb` resolves a selector via the OpenChain registry.

## Detection and defence
Not a defence topic on its own — but the patterns to watch for in code review:
- Public state with sensitive values (assume world-readable)
- Modifiers with state writes or external calls (re-entry surface)
- Missing visibility (`function foo()` defaults to public in old code)
- Implicit storage pointers in functions returning structs
- `unchecked { ... }` blocks (see [[integer-overflow-solidity]])

Related: [[smart-contracts-overview]], [[ethereum-blockchain]], [[foundry-toolkit]], [[remix-tool]].

## References
- [Solidity docs](https://docs.soliditylang.org/) — language reference
- [Solidity by Example](https://solidity-by-example.org/) — annotated patterns
- [EVM Codes](https://www.evm.codes/) — opcode + gas reference
- [OpenChain 4byte directory](https://openchain.xyz/signatures) — selector lookup
- [Solidity storage layout](https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html) — slot rules
