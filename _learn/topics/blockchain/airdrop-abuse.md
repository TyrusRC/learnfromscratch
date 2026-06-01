---
title: Airdrop / claim abuse
slug: airdrop-abuse
---

> **TL;DR:** Sybil farming, Merkle-proof reuse, signature replay, and re-entrancy on claim functions let an attacker collect more than their share of an airdrop.

## What it is
Airdrop and claim contracts distribute tokens based on eligibility — usually a Merkle root snapshot, an off-chain signed voucher, or an on-chain activity check. Bugs cluster in four spots: (a) the eligibility predicate is forgeable, (b) the "already claimed" bookkeeping is missing or bypassable, (c) the claim is re-entrant, (d) the eligibility itself is gameable via Sybils.

## Preconditions / where it applies
- Public `claim()` / `redeem()` function gated by Merkle proof or off-chain signature
- Snapshot-based eligibility (token holders, NFT holders, past traders)
- Multichain deployments sharing the same Merkle root / signing key
- Per-address claimed flags vs per-leaf claimed flags

## Technique
1. **Replay across chains.** If the same signed voucher (EIP-712 message) is accepted on every chain because `block.chainid` isn't bound into the domain separator, claim on chain A, replay on chain B.
2. **Per-address vs per-leaf bug.** If the contract marks `claimed[msg.sender] = true` but the Merkle leaf is `(address, amount)`, a wallet present in multiple leaves with different amounts can claim once per leaf — but a stricter bug is the reverse: marking `claimed[leaf]` while letting the caller pass any leaf they have a proof for. Always check both axes.
3. **Re-entrancy on ERC-777 / ERC-1363 / native ETH.** If `claim()` transfers tokens before flipping `claimed[]`, a callback re-enters and double-claims:
   ```solidity
   function claim(uint256 amt, bytes32[] calldata proof) external {
       require(verify(proof, leaf(msg.sender, amt)));
       token.transfer(msg.sender, amt);     // hook fires here
       claimed[msg.sender] = true;          // too late
   }
   ```
4. **Sybil farming.** When eligibility is "any wallet that bridged > $X" or "any wallet that swapped N times", fund 10k EOAs from a mixer, automate the qualifying action, claim from all. Detection signal for defenders: funding-graph clustering.
5. **Signature malleability / front-run.** A voucher addressed to `recipient` but not binding `recipient` into the signed payload can be stolen out of the mempool and claimed by another address.

## Detection and defence
- Bind `chainid`, `address(this)`, `recipient`, and a `nonce` into EIP-712 signatures.
- Use OpenZeppelin `MerkleProof` and mark `claimed[leafHash] = true` keyed by the leaf, not the caller.
- Apply checks-effects-interactions; flip the claimed flag before the external transfer. See [[reentrancy]].
- On-chain: monitor for high volume of claims from freshly funded EOAs sharing a funder.
- Off-chain Sybil scoring (graph analysis, gas-funding clustering, behavioural similarity) before snapshot finalisation.

Related: [[access-control-bugs]], [[reentrancy]], [[smart-contracts-overview]].

## References
- [OpenZeppelin MerkleProof](https://docs.openzeppelin.com/contracts/5.x/api/utils#MerkleProof) — canonical Merkle claim helper
- [EIP-712 Typed structured data](https://eips.ethereum.org/EIPS/eip-712) — domain-separator design
- [Trail of Bits — building secure airdrops](https://blog.trailofbits.com/2023/06/15/secure-your-airdrop/) — common pitfalls
- [Chainalysis — Sybil patterns in airdrops](https://www.chainalysis.com/blog/airdrop-sybil-attacks/) — funding-graph clustering
