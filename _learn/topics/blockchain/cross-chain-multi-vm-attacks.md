---
title: Cross-chain / multi-VM attack patterns
slug: cross-chain-multi-vm-attacks
aliases: [cross-chain-attacks, multi-vm-attacks, hop-bridge-attacks]
---

> **TL;DR:** Cross-chain protocols span EVM, Solana, Cosmos, Move, Bitcoin. Their attack surface composes: every VM-specific bug class lives at one endpoint, every bridge bug class lives in the link, and protocol-level assumptions create new bugs at the seams. The dominant patterns: bridge fault classes ([[bridge-attacks-modern]]), oracle desync across chains, replay across chains, governance attacks reaching across, and asset-accounting confusion when a wrapped asset is recombined. Companion to [[bridge-attacks-modern]] and [[oracle-manipulation]].

## Why cross-chain is its own class

Each chain has its own:
- Consensus model.
- Finality semantics.
- Asset representation.
- VM bug surface.

Combining them creates failure modes neither chain has in isolation. Most large cross-chain incidents are *seam* bugs, not chain bugs.

## Pattern 1 — Finality mismatch

Chain A finalises in 12 seconds; chain B in 12 hours. A protocol moving an asset from A to B might:
- Accept B's representation of A's deposit before A's deposit is final.
- A re-orgs; B's representation is now backed by nothing.

Attackers can:
- Deposit on A during re-org window.
- Move to B before re-org.
- Re-org A to invalidate the original deposit while keeping B's tokens.

Mitigation: wait for finality of the source chain before crediting destination.

## Pattern 2 — Cross-chain oracle desync

A lending protocol uses chain A's oracle to value collateral on chain B (via a bridge). If A's oracle is stale or manipulated:
- B's lending logic uses stale value.
- Liquidations / borrowings malfunction.

If the oracle is itself bridged, the bridge can be a manipulation vector — see [[oracle-manipulation]] and [[bridge-attacks-modern]].

## Pattern 3 — Wrapped asset recombination

The same underlying asset (say, USDC) may exist on chain A as native, on chain B as bridged-from-A (Wormhole USDC), on chain B as Circle CCTP USDC, on chain C as Stargate USDC, etc.

Each wrapping/unwrapping is a trust boundary. Bugs:
- DEX pool conflates two USDC variants → arbitrage opportunity.
- Lending market accepts wrong wrapped variant as collateral.
- Bridge unwrapping logic mis-attributes which originating bridge issued the wrap.

After UST 2022 and several wrapped-token incidents, careful accounting per-source-bridge is standard practice but not universal.

## Pattern 4 — Replay across chains

A transaction signed for chain A is valid bytewise on chain B if EIP-155 / chain-id binding is absent.

Pre-EIP-155 Ethereum transactions could be replayed across ETH/ETC. Modern Ethereum binds via chain id; but:
- Non-Ethereum chains may use different binding schemes.
- Off-chain signed messages (EIP-712 typed data) sometimes lack chain-id binding.

The Nomad bridge bug ([[bridge-attacks-modern]] class 2) had a replay component within a single bridge protocol.

## Pattern 5 — Governance reaching across

DAO governance on chain A controls a protocol on chain B via cross-chain message. If A's governance is compromised (flash-loan vote, whale takeover), B's protocol is exposed.

Mitigations:
- Cross-chain governance message with time-delay.
- Independent multi-sig on B with veto power.
- "Guardian" pattern with off-chain monitoring.

## Pattern 6 — CCTP-style native burn-and-mint vs lock-and-mint

Modern cross-chain dollar issuance (Circle's CCTP) burns USDC on source chain and mints fresh USDC on destination. Old design (lock-and-mint via bridge) holds USDC on source and issues wrapped on destination.

CCTP avoids the bridge's lock-vault attack surface; lock-and-mint inherits all bridge classes.

Practitioner question: when an asset is "USDC" on a chain, which path produced it? Different paths have different trust assumptions.

## Pattern 7 — Multi-VM seam audit gaps

A protocol with EVM and Solana components: who audits the seam?
- EVM auditor knows EVM, may miss Solana-side assumptions.
- Solana auditor knows Solana, may miss EVM-side assumptions.
- Cross-chain message format and packet semantics often slip between.

Trail of Bits, Halborn, OtterSec, and others have built cross-VM audit practices, but the supply of skilled multi-VM auditors is thin.

## Pattern 8 — Light client trust on resource-constrained chains

Some chains can't run a full light client of every counterparty:
- IBC light clients can be expensive (e.g., parsing Ethereum proofs).
- Substituted with multi-sig "validator set" — collapses to [[bridge-attacks-modern]] class 1.

The trust model is what it is in practice, not what it claims in marketing.

## Recent incidents shaped by cross-chain patterns

- **Multichain / Anyswap (2023)** — multi-vault, multi-chain bridge; reports of internal key compromise affecting multiple chains.
- **Harmony Horizon (2022)** — multi-sig compromise affecting multiple chain bridges.
- **Nomad (2022)** — see [[bridge-attacks-modern]].
- **Wormhole Solana side (2022)** — see [[bridge-attacks-modern]].
- **Ronin (2022)** — Axie game bridge; see [[bridge-attacks-modern]].

## Audit shape for cross-chain

When auditing a cross-chain protocol:
- **Finality assumptions** — every "accepted" event needs source-chain finality confirmation.
- **Replay protection** at every layer (transaction, message, packet).
- **Asset path tracking** — for each wrapped representation, document the issuing path.
- **Governance reach** — what cross-chain governance scope exists; what time-delay protects.
- **Oracle dependencies** — which prices feed across chains; what manipulation paths exist.
- **Per-VM bug classes** — every endpoint inherits its chain's bug surface.

## Operator / user-side hygiene

When using cross-chain protocols:
- Prefer **native asset issuance** (CCTP for USDC) over lock-and-mint where possible.
- Don't keep large positions on chains you're not actively using.
- Check the **specific bridge used** for the asset you hold.
- Follow incident response from major bridges; treat unfamiliar wrapped variants as higher-risk.

## Workflow to study

1. Walk an asset from chain A to chain B via two different bridges (e.g., Stargate and Wormhole for USDC).
2. Trace the on-chain events on both chains.
3. Identify the asset's source path on chain B.
4. Try the same with two different DEX pools holding the asset — confirm they're segregated.
5. Read a public bridge audit (Trail of Bits / Halborn / Spearbit) for shape.

## Related

- [[bridge-attacks-modern]] — bridge class.
- [[oracle-manipulation]] — DeFi class.
- [[solana-program-attacks]], [[move-language-audit]], [[cosmos-ibc-attacks]] — VM-specific bug classes.
- [[stablecoin-depeg-attacks]] — wrapped-asset failure mode.

## References
- [Vitalik — Cross-chain vs multi-chain](https://old.reddit.com/r/ethereum/comments/rwojtk/ama_we_are_the_efs_research_team_pt_7_07_january/hrngyk8/)
- [L2BEAT — risk analysis](https://l2beat.com/)
- [Trail of Bits — bridge audits](https://blog.trailofbits.com/)
- [Rekt — incident archive](https://rekt.news/)
- See also: [[bridge-attacks-modern]], [[stablecoin-depeg-attacks]], [[solana-program-attacks]], [[cosmos-ibc-attacks]]
