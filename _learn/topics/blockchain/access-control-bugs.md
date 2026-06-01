---
title: Access-control bugs (Solidity)
slug: access-control-bugs
---

> **TL;DR:** Privileged functions left unprotected, `tx.origin` used for auth, or `delegatecall` into attacker-influenced code — any of these grants ownership or drains funds.

## What it is
Access-control flaws are missing or wrong authorisation checks on functions that change ownership, mint tokens, withdraw balances, or upgrade logic. In Solidity the bug usually looks like a function that should be gated by `onlyOwner` / role check but isn't, or one that gates on `tx.origin` (phishable), or a proxy that `delegatecall`s into an address the attacker can set.

## Preconditions / where it applies
- Public/external function that mutates privileged state (owner, admin role, treasury, upgrade slot)
- No modifier, or a modifier that checks the wrong principal (`tx.origin` vs `msg.sender`)
- Proxy contracts following EIP-1967 / UUPS where `_authorizeUpgrade` is missing or weak
- Initialiser functions on upgradeable contracts not protected against re-init

## Technique
1. **Find the sinks.** Grep the source (or decompiled bytecode via Dedaub / Panoramix) for `selfdestruct`, `delegatecall`, `transferOwnership`, `mint`, `setImplementation`, `initialize`, `upgradeTo`.
2. **Check the guard.** Does it have an `onlyOwner` / `AccessControl` modifier? Is the modifier itself sane? A common bug:
   ```solidity
   modifier onlyOwner() { require(tx.origin == owner); _; }
   ```
   `tx.origin` lets any contract the owner interacts with relay a privileged call — classic phishing primitive.
3. **Exploit unprotected init.** On a freshly deployed UUPS proxy where `initialize()` was never called, anyone can call it and become owner, then call `upgradeTo(attackerLogic)` and `delegatecall` into a payload that `selfdestruct`s the implementation (the Parity multisig 2017 pattern) or steals funds.
4. **Delegatecall hijack.** If a function does `target.delegatecall(data)` and `target` is settable by a non-owner, point it at a contract whose function signature collides with `transferOwnership` and rewrite slot 0.

Forge PoC skeleton:
```solidity
vm.prank(attacker);
victim.initialize(attacker);          // unprotected initialiser
victim.upgradeTo(address(evilImpl));  // attacker now controls logic
```

## Detection and defence
- Static analysis: Slither detectors `unprotected-upgrade`, `arbitrary-send`, `tx-origin`, `uninitialized-state`.
- Use OpenZeppelin `Ownable2Step` / `AccessControl` and the `initializer` / `reinitializer` modifiers; disable initialisers in the constructor of upgradeable logic contracts (`_disableInitializers()`).
- Never authenticate with `tx.origin`. Always `msg.sender`.
- On monitoring: alert on `OwnershipTransferred`, `Upgraded`, and `RoleGranted` events from unexpected addresses.

Related: [[reentrancy]], [[integer-overflow-solidity]], [[smart-contracts-overview]].

## References
- [SWC-115 Authorization through tx.origin](https://swcregistry.io/docs/SWC-115) — registry entry on tx.origin auth bug
- [SWC-118 Incorrect Constructor Name](https://swcregistry.io/docs/SWC-118) — historical init/ownership pitfall
- [OpenZeppelin AccessControl docs](https://docs.openzeppelin.com/contracts/5.x/access-control) — canonical role pattern
- [Trail of Bits — Not so smart contracts](https://github.com/crytic/not-so-smart-contracts) — annotated bug examples
