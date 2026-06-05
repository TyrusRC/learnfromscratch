---
title: ERC-4626 vault attacks
slug: erc4626-vault-attacks
aliases: [erc4626-attacks, vault-inflation-attack, share-inflation]
---

> **TL;DR:** ERC-4626 is the tokenised-vault standard underlying most modern DeFi yield products. The "inflation" / "donation" attack class: an attacker is the first depositor (1 wei), then directly transfers a large amount of the underlying asset to the vault, inflating the share-price. Subsequent honest depositors round down to zero shares, and their deposit accrues to the attacker. Defended by deposit guards (virtual shares, dead shares). Companion to [[reentrancy]] and [[oracle-manipulation]].

## Why ERC-4626 vaults are a high-impact target

ERC-4626 sits underneath:
- Yield aggregators (Yearn, Beefy, Reaper).
- Money-market deposit shares (Aave aTokens, Compound cTokens use similar math).
- Lending-pool LP tokens.
- Liquid-staking deposit tokens.

The standard is small but the conversion math (`convertToShares`, `convertToAssets`) is subtle. The same bug class has hit different implementations many times.

## The inflation / donation attack

The vault's share math:

```
shares = assets * totalSupply / totalAssets
assets = shares * totalAssets / totalSupply
```

With `totalSupply == 0`, the first deposit usually mints `shares = assets` (1:1). After that:

- Attacker is first depositor, deposits 1 wei → mints 1 share. `totalSupply == 1`, `totalAssets == 1`.
- Attacker directly transfers 1e18 of the asset to the vault (no deposit call, just `IERC20.transfer`). `totalAssets == 1e18 + 1`.
- Honest user deposits 1e18 → expects ~1e18 shares.
- Math: `shares = 1e18 * 1 / (1e18 + 1) = 0` (rounded down).
- Honest user has 0 shares but their 1e18 is in the vault.
- Attacker withdraws their 1 share → receives `1 * (2e18 + 1) / 1 = 2e18 + 1` assets. They stole the honest deposit.

The bug is **rounding** combined with attacker control over the vault's asset balance.

## Mitigations

### Virtual shares + virtual assets (OpenZeppelin)

Vault constructor adds **virtual shares** and **virtual assets** to the formula:

```solidity
function _convertToShares(uint256 assets) internal view returns (uint256) {
    return assets * (totalSupply() + 10**DECIMALS_OFFSET)
                  / (totalAssets() + 1);
}
```

With virtual shares 1e18 and virtual assets 1, the first depositor can't manipulate the ratio.

### Dead shares

Mint a small amount of shares to a burn address on first deposit, raising the floor.

### Initial-deposit minimum

Require a non-trivial initial deposit (e.g., 10^9 wei) so rounding doesn't zero out subsequent deposits.

### Use `deposit()` only (no direct transfers)

Vault accounts for assets only via deposit / withdraw flows; direct transfers are tracked but don't accrue to share-price. Hard to enforce on chain.

## Workflow to audit a vault

1. Check `convertToShares` / `convertToAssets` for rounding direction.
2. Check whether `totalAssets()` reads `IERC20.balanceOf(vault)` or a separately tracked accounting variable.
3. If `balanceOf`, donation attack is plausible — verify mitigation present.
4. Test with first deposit = 1 wei, then direct transfer 1e18, then second deposit. Observe share allocation.
5. Test rounding edge cases at small share counts.

Use Foundry; `forge test` with carefully sized values.

## Related ERC-4626 bug classes

- **Hook reentrancy** — vaults that call into external strategies before updating `totalSupply` accounting allow reentrancy ([[reentrancy]]).
- **Cross-vault routing bugs** — wrappers that batch-call into multiple ERC-4626 vaults can be confused by `previewDeposit` mismatches.
- **Adversarial strategy** — vault strategy implements `harvest()` in a way that lets attacker MEV-front-run yield distribution.
- **Asset-recovery functions** — admin functions that can rescue tokens may be exploitable as withdraw-without-burn paths.

## Real-world incidents

- Multiple early-2023 lending-protocol bugs of this exact shape.
- Several yield aggregators had post-mortems specifically about inflation attacks.
- The OpenZeppelin ERC4626 implementation hardening became the de-facto baseline.

## References
- [EIP-4626 specification](https://eips.ethereum.org/EIPS/eip-4626)
- [OpenZeppelin ERC4626 with virtual shares](https://docs.openzeppelin.com/contracts/4.x/erc4626)
- [Trail of Bits — ERC-4626 vault inflation](https://blog.trailofbits.com/)
- [Spearbit / Cantina audits — ERC-4626 case studies](https://spearbit.com/)
- See also: [[reentrancy]], [[oracle-manipulation]], [[bridge-attacks-modern]], [[integer-overflow-solidity]]
