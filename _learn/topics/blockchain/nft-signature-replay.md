---
title: NFT signature replay and Seaport phishing
slug: nft-signature-replay
aliases: [nft-replay, seaport-signature-phishing, opensea-signature-phishing]
---

> **TL;DR:** OpenSea's Seaport (and similar NFT exchange protocols) let users sign off-chain orders authorising NFT transfers. Phishing the signature is sufficient to take NFTs from the victim — no transaction in their wallet, no gas paid. Variants: stale-order replay, conduit-key abuse, signature reuse across compatible exchanges. Pattern parallels [[permit-eip2612-phishing]] for ERC-20s. Companion to [[oauth-token-theft]].

## Why off-chain NFT orders are attack surface

NFT exchanges use a "gasless listing" UX: sellers sign an order off-chain; buyers fulfill on-chain. The signed order is the seller's authorisation to transfer their NFT.

If the seller can be tricked into signing an order for **zero cost or low cost**, the attacker fulfills the order and pays the low cost; victim's NFT transfers; attacker resells.

The signing UX is **identical to legitimate listing**: same wallet prompt, same EIP-712 typed data. Only the order contents differ.

## The Seaport order

Seaport's `OrderComponents` include:

- `offerer` — the signer (victim).
- `offer` — what the offerer is giving up (the NFT).
- `consideration` — what they get back (price + fees + recipient).
- `startTime`, `endTime` — validity window.
- `salt`, `nonce` — uniqueness / replay protection.
- `zone` — optional moderator address.
- `conduitKey` — which Seaport conduit holds the approval.

Phishing payload examples:

- Offer = victim's high-value NFT. Consideration = 0 ETH to attacker. Victim signs "approve transfer for 0 ETH".
- Offer = victim's NFT. Consideration = 1 wei. Same outcome at "negligible cost".
- Offer = entire collection of victim's NFTs via batch order.

## How the phish presents

Same wallet prompt as a legitimate listing. The user sees the EIP-712 JSON; few users decode it.

Common pretexts:
- "Verify your collection" / "Validate your NFTs".
- "Claim your airdrop" — site asks for an authorisation it claims is for the airdrop, actually a sell order.
- "Migrate to v2" — fake migration.
- "Re-list with reduced fees" on a phishing copy of a marketplace.

## Conduit-key abuse

Seaport approvals are held by a **conduit** — a separate contract that intermediates token transfers. A user approves the conduit; orders specify which conduit's approval to use.

Attackers can register their own conduits and trick users into approving them. Once the user's NFT is approved to attacker's conduit, the attacker can transfer it without further signature.

Defence: check what conduit you're approving; OpenSea's main conduit has a known address.

## Cross-marketplace signature reuse

If two marketplaces share the **same order format** (Seaport-compatible), a signature for one may be valid on the other. Defence is domain-separator binding in EIP-712, which Seaport does. But:

- Forks of Seaport with weak domain separator.
- Marketplaces that re-broadcast orders to other venues.

Audit: confirm `verifyingContract` and `chainId` in the typed-data domain match the expected marketplace.

## Permit2 + Seaport chain

Some drainer kits combine:
- Phishing a **Permit2 signature** for ERC-20 drain.
- Phishing a **Seaport signature** for NFT drain.

Both in the same connect-wallet flow. The user signs two innocuous-looking messages and loses everything.

## What victims should do

- **Revoke any Seaport conduit approval** if the attacker's conduit got approved.
- **Cancel outstanding orders** via Seaport's `cancel` function (costs gas, invalidates by nonce).
- **Increment counter** — Seaport supports `incrementCounter` to invalidate every signature for the offerer.
- **Move remaining NFTs** to a fresh wallet.

## Audit shape for NFT marketplaces

- Reject orders with `consideration = 0` unless there's an off-chain reputation signal.
- Display order contents in **human-readable form** before signing.
- Default to **short expiry** (hours, not weeks).
- Display the **conduit being approved** clearly.
- Implement **rate-limit on listing signatures** per IP / per session for new wallets.

## Workflow to study in a lab

1. Set up a local Seaport deployment.
2. Sign a malicious order from a victim wallet.
3. Fulfill from an attacker wallet; observe transfer.
4. Practice cancellation flow.
5. Test detection tools (Wallet Guard, Blockaid) against the same payload.

## Related signature-phishing classes

- [[permit-eip2612-phishing]] — ERC-20 variant.
- **CryptoPunks "offerPunkForSale"** historical pattern.
- **Blur bid manipulation** — different protocol, similar UX risk.
- **ENS name approval phishing** — typed-data signatures over ENS records.

## References
- [Seaport protocol](https://github.com/ProjectOpenSea/seaport)
- [OpenSea security model](https://opensea.io/blog/articles/details-of-the-attack)
- [Scam Sniffer — drainer reports](https://www.scamsniffer.io/)
- [revoke.cash — NFT approval hygiene](https://revoke.cash/learn/)
- [PhishingDB](https://web3antivirus.io/) — phishing-site lists
- See also: [[permit-eip2612-phishing]], [[erc20-approval-phishing]], [[oauth-token-theft]], [[bridge-attacks-modern]]
