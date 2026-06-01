---
title: Delegatecall and Storage Collisions
slug: delegatecall-storage-collision
---

> **TL;DR:** `delegatecall` runs another contract's code in your storage context — if the proxy and implementation disagree on slot layout, an attacker can overwrite the admin, the owner, or anything else.

## What it is
Upgradeable contracts rely on a thin proxy that `delegatecall`s into a logic contract. Because `delegatecall` keeps the caller's storage, sender, and value, any state written by the logic contract lands in the proxy's slots. If slot 0 holds `address owner` in the implementation but something else in the proxy, calling an innocuous setter rewrites a critical variable. The Parity multisig freeze (Nov 2017, ~514k ETH locked) and the original Parity hack (Jul 2017, ~150k ETH stolen) are the canonical incidents.

## Preconditions / where it applies
- Proxy pattern (EIP-1967, transparent proxy, UUPS, beacon)
- Implementation contract has its own state variables declared in the same slot order as the proxy expects
- Initialisation function is not protected, or storage layout changes between upgrades
- Logic contract is itself callable directly and holds a `selfdestruct` or ownership transfer

## Technique
```solidity
// Proxy expects: slot 0 = implementation address (or EIP-1967 keccak slot)
contract BadProxy {
    address public implementation; // slot 0
    fallback() external payable {
        (bool ok,) = implementation.delegatecall(msg.data);
        require(ok);
    }
}

// Implementation also declares slot 0:
contract Logic {
    address public owner; // slot 0 — COLLIDES with `implementation`
    function setOwner(address a) external { owner = a; } // rewrites impl pointer!
}

// Attacker: proxy.setOwner(attackerContract) -> next call delegatecalls into attacker code
// with the proxy's storage and balance. Game over.
```
The Parity wallet variant was different but related: the library contract was uninitialised, anyone could call `initWallet` on it directly, become owner, then `selfdestruct` the library — bricking every proxy that depended on it.

## Detection and defence
- Auditor red flags: hand-rolled proxies, mismatched inheritance order between proxy and logic, unprotected `initialize()`
- Use OpenZeppelin `TransparentUpgradeableProxy` / `UUPSUpgradeable` with `Initializable` and `initializer` modifier
- Follow EIP-1967 standardised storage slots (`keccak256("eip1967.proxy.implementation") - 1`)
- Reserve storage gaps (`uint256[50] __gap;`) in upgradeable base contracts
- Static analysis: Slither's `storage-layout` detector, OpenZeppelin Upgrades plugin diffs layouts on upgrade
- Always `disableInitializers()` in the implementation constructor

## References
- [OpenZeppelin Proxies](https://docs.openzeppelin.com/contracts/4.x/api/proxy) — patterns and gotchas
- [EIP-1967: standard proxy slots](https://eips.ethereum.org/EIPS/eip-1967) — slot derivation
- [Parity multisig post-mortem](https://www.parity.io/blog/a-postmortem-on-the-parity-multi-sig-library-self-destruct/) — the 514k ETH freeze

See also: [[access-control-bugs]], [[solidity-basics]], [[smart-contracts-overview]].
