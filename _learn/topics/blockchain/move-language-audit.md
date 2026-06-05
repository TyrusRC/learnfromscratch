---
title: Move language audit (Sui, Aptos)
slug: move-language-audit
aliases: [move-audit, sui-move-audit, aptos-move-audit]
---

> **TL;DR:** Move is a resource-oriented language designed for safety: resources (assets) can't be duplicated or accidentally dropped, and ownership is enforced by the type system. Sui's Move (Mysten Labs) and Aptos's Move (formerly Diem / Meta) differ in object model and storage. Audit focus: storage / ability misuse, type confusion across modules, capability leakage, dynamic-field access, and oracle / arithmetic patterns familiar from Solidity. Companion to [[solana-program-attacks]] and [[reentrancy]].

## Why Move

- **Resource safety** — assets can't be duplicated; the language refuses to compile copy-of-resource code.
- **Strong type system** with **abilities** (copy, drop, store, key) controlling what types can do.
- **No reentrancy** at the language level — calls are statically tracked.
- **Designed for assets** from the start.

But: Move programs are still software, with logic bugs. Resource safety prevents one bug class; many others remain.

## Sui Move vs Aptos Move

- **Sui Move**: object-centric. Each object has an ID; objects are owned by addresses or shared. Storage is object-by-object.
- **Aptos Move**: account-centric (like Diem). Resources stored under account addresses.

Audit patterns differ in storage model but share the language safety properties.

## Class 1 — Ability mis-set

Each Move struct declares abilities:
- `copy` — can be copied. Resources should not have this.
- `drop` — can be dropped. Resources usually shouldn't.
- `store` — can be stored in global storage / objects.
- `key` — can be a top-level resource.

Setting `copy` on what should be a unique asset is catastrophic: attacker can duplicate the asset.

## Class 2 — Public functions that should be friend / package-private

Move's visibility:
- `public` — callable by any module.
- `public(friend)` (Aptos) / `public(package)` (Sui) — only by listed modules.
- `entry` — entry point for transactions.

A `public` function that mutates internal state without auth check is exploitable. Common mistake: making a helper `public` for testing, forgetting to revert before production.

## Class 3 — Capability pattern leakage

A common pattern: a "capability" object grants permission to call privileged functions.

```move
struct MintCap has key, store { ... }

public fun mint(_cap: &MintCap, recipient: address, amount: u64) { ... }
```

Bugs:
- Capability stored in shared object → anyone can borrow → call privileged.
- Capability transferred carelessly via Sui object transfer.
- Capability passed across modules where it shouldn't be.

## Class 4 — Dynamic field / shared object misuse (Sui)

Sui supports dynamic fields on objects. Access patterns:
- `dynamic_field::borrow_mut(obj, key)` — borrow mutably.
- Bugs: borrowing twice (compile errors usually), wrong key, type confusion at the field type.

Sui shared objects can be accessed concurrently by multiple transactions; race-condition-like patterns exist within consensus.

## Class 5 — Type confusion in generic functions

A `public fun deposit<T: store>(coin: Coin<T>)` is generic over `T`. If the function trusts the type without per-type accounting:
- Pool accounts for `T=USDC` and `T=DAI` shared can be confused.
- Deposit `USDC` but withdraw `DAI` from same pool.

Audit: every generic function over an asset type should keep per-type accounting separate.

## Class 6 — Arithmetic

Move has integer types `u8`, `u64`, `u128`, `u256`. Arithmetic overflow / underflow:
- Aborts on overflow by default (unlike Rust release).
- This *prevents* silent wrap but *enables* DoS — attacker forces an abort to grief.

Audit: where abort-on-overflow is the security property, fine. Where it's an availability concern, use saturating / checked math explicitly.

Division by zero aborts.

## Class 7 — Oracle and price manipulation (Sui DeFi)

Same as EVM: lending markets relying on weak price oracles are manipulable via flash-loan-equivalents in Sui's design.

Sui flash-loan equivalents: borrow + repay within the same transaction using shared mutable references. The atomicity is similar to EVM flash loans.

See [[oracle-manipulation]] for the underlying class.

## Class 8 — Sui PTB (programmable transaction block) composition

Sui transactions compose multiple Move calls and arbitrary input/output piping. Attack:
- Compose call A's output as call B's input in a way the modules don't expect.
- Get more output than economically sound by chaining favourable calls.

Audit: ensure each module's public functions handle adversarial inputs even when the user composes them in unusual sequences.

## Class 9 — Object model: ownership transfer surprises (Sui)

Sui objects can be transferred to addresses, sent to package-objects, or wrapped in other objects. Bugs:
- Object's `id` reused across upgrades.
- Object frozen / unfrozen state mismatch.
- Wrapping not accounted for in market logic.

## Audit shape

For a Move module:
1. List **all `public` and `entry`** functions.
2. For each, identify the **capability or access check**.
3. List **all abilities** on structs holding value.
4. List **generic functions** over asset types; ensure per-type accounting.
5. List **arithmetic operations**; classify as safety-criticial-abort vs availability-concerning.
6. For Sui: list **shared objects** and concurrent-access invariants.
7. For Sui: list **dynamic fields**; ensure type / key correctness.

## Real-world disclosures

- Public Sui / Aptos audit reports (Zellic, OtterSec, MoveBit, Kunchok) publish detailed case studies.
- Multiple early bug-bounty findings on Sui / Aptos DeFi protocols documented capability-leakage and shared-object race patterns.

## Workflow to study

1. Install Sui CLI or Aptos CLI.
2. Walk through Move Book (Mysten / Aptos docs).
3. Build a small token / DEX module locally.
4. Introduce a capability-leakage bug intentionally; attack with adversarial transaction.
5. Patch using the friend / capability discipline.

## Related

- [[solana-program-attacks]] — alternate non-EVM model.
- [[reentrancy]] — EVM bug class for comparison.
- [[oracle-manipulation]] — applies to all chain DeFi.
- [[bridge-attacks-modern]] — cross-chain.

## References
- [Move Book (Sui)](https://move-book.com/)
- [Aptos Move developer docs](https://aptos.dev/move/move-on-aptos)
- [OtterSec Move audit blog](https://osec.io/blog/)
- [Zellic — Move audits](https://www.zellic.io/blog/)
- [MoveBit](https://movebit.xyz/)
- See also: [[solana-program-attacks]], [[reentrancy]], [[oracle-manipulation]], [[bridge-attacks-modern]], [[cosmos-ibc-attacks]]
