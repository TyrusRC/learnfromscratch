---
title: Web3 / smart-contract bug bounty methodology
slug: web3-bug-bounty-methodology
aliases: [web3-bb-method, smart-contract-bb-methodology]
---

> **TL;DR:** Web3 bug-bounty hunting splits into two economies: always-on Immunefi-style programs (single-finder bounty, severity tiers, KYC payouts) and time-boxed pooled-prize contests (Code4rena, Sherlock, Cantina) where many auditors share a pot weighted by severity and dupe count. Winning at either requires reading thousands of lines of Solidity or Move quickly, identifying *protocol invariants* (not just bug-class pattern matches), and proving impact with Foundry PoCs that revert when the invariant breaks. Companion to [[reentrancy]], [[oracle-manipulation]], [[bridge-attacks-modern]], [[erc4626-vault-attacks]], and [[blockchain-security]].

## Why it matters

DeFi TVL sits in the tens of billions of USD. A single missed invariant on a vault, oracle, or bridge has historically drained $100M+ (Ronin, Wormhole, Nomad, Euler, Multichain). That economic pressure is why Web3 bounties pay 10x what most Web2 programs do — a single critical on Immunefi can be capped at $1M-$10M, and contest pots routinely hit $100k-$500k.

But the methodology is *not* the same as Web2 bug bounty (see [[bug-bounty-methodology]]). There is no recon phase, no subdomain enumeration, no fuzzing of unknown endpoints. The entire surface is the source code in the repo, and so is every other hunter's surface. You compete on speed, depth of mental model, and ability to articulate invariants — not on finding hidden assets.

This note maps the landscape and the workflow. For the bug classes themselves, follow the cross-links.

## Contest vs traditional bounty: the economic models

### Immunefi (and project-direct) — traditional bounty

- Single finder per bug. First valid report wins; later dupes get nothing (similar to [[dupe-mental-model]] in Web2).
- Severity tiers fixed in policy: Critical / High / Medium / Low / Informational, with USD caps per tier.
- Payouts gated by KYC + on-chain wallet (sanctions screening, no anonymous claims).
- Programs run continuously — code freezes only happen during upgrades.
- Reward usually based on *funds at risk* at the time of disclosure, capped at the program max.

### Code4rena — pooled-prize contest

- Time-boxed (typically 3-14 days). Prize pool is fixed (e.g., $80k USDC + sponsor token).
- Findings split: ~80% of pool to High/Medium findings, ~20% to QA/gas reports.
- Severity-weighted shares. Each unique High is worth more shares than each unique Medium.
- Dupes share the share. Ten people who report the same High split that High's slice.
- Judges (separate role) decide validity and severity post-contest.

### Sherlock — pooled-prize, H/M only

- Same time-boxed model, but **only High and Medium are paid**. No low/QA/gas pool.
- Stricter validity rules: low-likelihood + low-impact issues are kicked even if technically correct.
- Watson (auditor) ranking system; higher-ranked Watsons get tiebreaker on escalations.
- Sherlock judges weigh "external requirements" heavily — a finding that needs governance to act maliciously is often downgraded or invalidated.

### Cantina — pooled-prize, marketplace-style

- Mix of Sherlock and Code4rena conventions; sponsor has more say in severity.
- Often runs invitational or private contests with smaller researcher pools.
- Reputation-weighted payouts in some events.

## Reading the codebase fast

The first hour determines whether you find anything. You cannot read every line. Triage like an auditor, not a reader.

### Initial map (first 30-60 minutes)

1. Read the README, docs, and any `SPEC.md` or whitepaper link first. Note the **mental model** the protocol *wants* you to have. Bugs live in the gap between docs and code.
2. `cloc` or `scc` the in-scope contracts. If the contest scope says 2000 SLoC and you see 8000, ask in the contest channel — sometimes libraries are out-of-scope.
3. Build the call graph mentally: which contract is the entrypoint for users? Which is the entrypoint for governance? Which holds funds?
4. Open the test suite. Tests reveal *intended* behaviour. Anywhere tests are thin or missing, the implementation is suspect.

### Second pass (next 2-3 hours)

- For every external/public function: who can call it, what state does it mutate, what tokens does it move, what invariant does it claim to preserve?
- Mark every `onlyOwner`, `onlyGovernance`, `onlyKeeper` with the trust assumption. If the contest README says "we trust the keeper", *do not* report keeper bugs — they will be invalidated as out-of-scope.
- Note every external call: ERC-20 `transfer`/`transferFrom`, oracle reads, cross-contract calls. Each is a candidate for [[reentrancy]] or [[oracle-manipulation]].

## Invariant identification (the actual skill)

Pattern-matching ("is there a missing nonReentrant?") finds the easy bugs that everyone else also finds and you split with ten dupes. The high-EV work is identifying *protocol invariants* and asking how to break them.

Examples of invariants worth listing per protocol:

- **Vault**: `totalAssets >= sum(userBalance * sharePrice)` always. See [[erc4626-vault-attacks]] for inflation/donation attacks against this.
- **Lending**: `sum(debt) <= sum(collateral * LTV)` after every action. Breaking it = bad debt or free withdrawals.
- **Stablecoin**: `1 stable redeemable for $1 of backing` regardless of market price. See [[stablecoin-depeg-attacks]].
- **AMM**: `k = x * y` only changes by the fee on swaps; donations should not let an attacker extract more than they donated.
- **Bridge**: `mint on chain B <= lock on chain A` per asset per epoch. See [[bridge-attacks-modern]].
- **Governance**: `quorum and timelock cannot be bypassed by a single proposer`. See snapshot-replay and flash-loan-vote attacks.

Write the invariants down. Then for each, ask: which functions touch the variables in this invariant, and is there a sequence that breaks it?

## Common bug-class checklist (DeFi)

A working triage list. Walk it for every contract:

- [[reentrancy]] — classic, read-only, cross-function, cross-contract.
- [[oracle-manipulation]] — spot price as oracle, single-source Chainlink without staleness, TWAP window too short.
- [[flash-loan-attacks]] — combined with oracle or governance manipulation.
- [[erc4626-vault-attacks]] — first-deposit inflation, donation, rounding direction.
- [[bridge-attacks-modern]] — signature replay, merkle proof reuse, mint/burn asymmetry.
- [[permit-eip2612-phishing]] — front-end relevant but sometimes contract-side too (missing deadline checks).
- [[nft-signature-replay]] — missing chainId or nonce in EIP-712 typed data.
- Access control — missing modifiers on `initialize`, `upgrade`, `setOracle`, `mint`.
- Token compatibility — fee-on-transfer, rebasing, USDT-style return-bool-missing, weird ERC-777 callbacks.
- Math — fixed-point precision loss, division before multiplication, casting overflows in Solidity 0.8 with `unchecked`.
- Storage collisions in upgradeable proxies — appended variables in V2, slot reuse across implementations.
- Front-running / MEV — sandwich-able swaps without slippage caps, unprotected `claim` functions.
- DoS — unbounded loops, push-payment patterns, revert-on-zero-transfer tokens.

For non-EVM, see [[solana-program-attacks]] and [[move-language-audit]] — different bug classes (account confusion, missing signer checks, resource lifecycle).

## Governance, oracle, and bridge hotspots

The three categories of "real money" findings.

### Governance

- Flash-loan votes when voting power = current token balance. Fix is snapshot-based voting.
- Timelock bypasses: proposal executed by privileged role without delay.
- Single-step ownership transfer (`transferOwnership` → wrong address → bricked admin).
- Cross-domain messengers (Optimism L1↔L2) where governance is impersonated via crafted L1 calls.

### Oracle

- Chainlink without `updatedAt` staleness check or `answeredInRound` check.
- Uniswap V2 spot reserves used as price.
- TWAP window < 30 min in a low-liquidity pool — flash-loan moveable.
- LP token pricing using `getReserves()` directly (Alpha Finance / Warp Finance class).
- Custom oracle that reverts on extreme prices, causing liquidations to be impossible.

### Bridge

- Message replay across chains (no chainId domain separation).
- Trusted relayer with no slashing — see Ronin (5/9 sigs compromised).
- Merkle root signed but leaves not validated — Nomad-style.
- Mint authority shared between bridge and another module.
- Withdrawal proofs that don't bind to the recipient address.

## Workflow to study

1. Pick three past contests on Code4rena with public reports. Read the *finalised* findings, then re-read the source and try to spot each finding yourself in the source before reading the report. Calibrates your eye.
2. Set up Foundry. `forge init`, write a fork test against mainnet (`--fork-url`), reproduce a known historical exploit (Euler, Beanstalk, Mango) end-to-end.
3. For invariant discovery, learn `forge test --invariant` and Echidna basics. Even shallow invariant tests catch real bugs.
4. Read 10 Spearbit / Trail of Bits / OpenZeppelin public audits cover-to-cover. Note how findings are written, severities argued, mitigations recommended.
5. Enter one Code4rena contest as a "shadow auditor" — audit it for the full duration, then compare your private notes to the published report. Track which findings you got, missed, false-positived. Iterate.
6. Read [[reentrancy]], [[oracle-manipulation]], [[flash-loan-attacks]], [[erc4626-vault-attacks]], [[bridge-attacks-modern]] in order, with PoCs.

## Submission discipline

- One issue per submission. Bundling a High and a Medium loses the Medium.
- Title states the bug, not the impact. "Missing slippage check in `swap()`" not "User loses funds".
- Body structure: summary, vulnerability detail, impact, PoC (Foundry test that asserts the invariant breaks), recommendation.
- PoC must be runnable from a fresh clone of the repo with `forge test --mt testYourFindingName`.
- Sherlock especially: argue the impact and the likelihood explicitly. Med = "loss of funds with conditions" or "core function broken". Don't waste a slot on a Low you've labeled High.
- Don't argue with judges in escalation unless you have new evidence. Re-litigating loses ranking.

## Dupe handling in pooled-prize contests

You will be duped. The top auditors expect to share Highs with 5-15 others. The strategy is volume of *high-severity* findings, not chasing uniqueness on Mediums. Submitting two Highs that each have 8 dupes still beats submitting one unique Medium. See [[dupe-mental-model]] for the parallel logic in Web2 bug bounty.

What you can control:

- Be the *clearest* report on a duped finding. Sometimes the judge promotes the best-written instance and downgrades the others as partial credit.
- Find the *generalised* form of a finding. If others report "function X has bug", you report "the underlying pattern affects X, Y, Z" — sometimes scored as one finding worth more.
- Find true uniques on subtle invariant breaks. These are where the rank-leading payouts come from.

## Related

- [[blockchain-security]]
- [[smart-contracts-overview]]
- [[reentrancy]]
- [[oracle-manipulation]]
- [[flash-loan-attacks]]
- [[erc4626-vault-attacks]]
- [[bridge-attacks-modern]]
- [[permit-eip2612-phishing]]
- [[nft-signature-replay]]
- [[stablecoin-depeg-attacks]]
- [[l2-rollup-sequencer-attacks]]
- [[solana-program-attacks]]
- [[move-language-audit]]
- [[cross-chain-multi-vm-attacks]]
- [[bug-bounty-methodology]]
- [[dupe-mental-model]]
- [[report-writing-step-by-step]]
- [[demonstrating-impact]]

## References

- <https://docs.code4rena.com/> — Code4rena official docs: severity, judging, payout math.
- <https://docs.sherlock.xyz/audits/judging/judging> — Sherlock judging criteria and H/M definitions.
- <https://immunefi.com/learn/> — Immunefi vulnerability severity standard and reporting guide.
- <https://book.getfoundry.sh/> — Foundry book: forge test, fork testing, invariant fuzzing.
- <https://secure-contracts.com/> — Trail of Bits "Building Secure Contracts" guide.
- <https://github.com/crytic/building-secure-contracts> — companion repo with Slither, Echidna, Medusa workflows.
