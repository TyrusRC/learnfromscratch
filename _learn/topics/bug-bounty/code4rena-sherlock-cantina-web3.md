---
title: Code4rena / Sherlock / Cantina — Web3 contest platforms
slug: code4rena-sherlock-cantina-web3
aliases: [c4-sherlock-cantina, web3-bb-platforms]
---

> **TL;DR:** Code4rena, Sherlock, and Cantina run time-boxed *audit contests* where dozens to hundreds of wardens/watsons compete over 3-7 days to find bugs in a frozen smart-contract codebase, splitting a fixed prize pool weighted by severity and uniqueness. The model is fundamentally different from Immunefi-style live-protocol bounties (which pay per-bug on disclosure). If you are coming from Web2 bounties, treat this as a structured sprint: study the scope like an auditor, write reports like a PR review, and accept that *dupes get pennies*. Companion notes: [[web3-bug-bounty-methodology]], [[blockchain-security]], [[bridge-attacks-modern]], and [[reentrancy]].

## Why it matters

Contest platforms are now the dominant way new DeFi protocols get a *pre-launch* security pass. Most major L2s, vault protocols, stablecoins, and bridges run a Code4rena/Sherlock/Cantina contest *before* deploying mainnet, often in addition to a private audit. For a researcher this means:

- **Predictable funnel:** 1-3 contests per week, public scope, fixed deadline. No "out of scope" ambiguity that plagues Web2 ([[program-scope-reading]]).
- **High learning rate:** Every contest is a fresh codebase. Forces you to read Solidity/Move/Rust contracts fast — similar muscle to [[graphql-source-review]] but for finance code.
- **Different unit economics:** A solo critical on Sherlock can pay $30k-$200k+. A dupe of the same bug among 20 wardens on Code4rena might pay $200. Variance is brutal.
- **Public judging:** Post-contest, findings are published. This is a goldmine — see [[h1-disclosed-report-reading-method]] applied to GitHub `findings.md` files.

If you only do Web2, you are leaving a category of work on the table. If you only do contests, you are exposed to severe payout variance — most pros run both contests *and* a live-bounty pipeline (see [[burnout-and-pipeline]]).

## Platform comparison

### Code4rena (C4)

- **Format:** Open contest. Anyone with a registered "warden" handle can submit. Typical pool: $30k-$200k, sometimes $1M+.
- **Duration:** 3-10 days, occasionally 14 for very large scopes.
- **Submission:** GitHub-flavored Markdown finding via the C4 portal, one finding per submission. Must include impact, PoC (often a Foundry test), and recommended mitigation.
- **Severity:** High / Medium / QA (low/info bundled). Gas reports are a separate optional category.
- **Payout math:** Each severity has a fixed slice of the pool. Slice is split among all valid findings of that severity, weighted by *uniqueness*: if 20 wardens find the same High, each gets ~1/20th of that slot. Solo finds get full slot.
- **Judging:** Lead judge + sponsor review. Wardens can PJQA (post-judging QA) to contest decisions.
- **COI:** Wardens cannot compete on protocols they advise/work for. Judges recuse on conflicts.

### Sherlock

- **Format:** Hybrid contest + watson-led audit. Watsons must stake USDC as skin-in-the-game for some contests.
- **Duration:** 5-14 days typical.
- **Submission:** Single Markdown report submitted via Sherlock dashboard. Discord-style discussion thread per issue.
- **Severity:** High / Medium only (no Lows count for payout). Strict rules — Sherlock's *Hierarchy of Truth* doc defines what qualifies. Many "Web2-style" findings (centralization risk, admin can rug) are explicitly invalid.
- **Payout math:** Fixed pool, weighted by severity points. Sherlock famously pays solo highs *very* well. Also offers a *bug-bounty backstop* — if a critical is missed during the contest and exploited post-launch, Sherlock's pool can pay out under specific SLAs (this is what differentiates Sherlock from pure contest sites).
- **Judging:** Lead Senior Watson (LSW) does primary judging. Escalation rounds let watsons stake to dispute.
- **COI:** Strict — disclosed at registration.

### Cantina (by Spearbit)

- **Format:** Newer entrant, runs both *competitions* and *private reviews*. Backed by Spearbit's auditor network.
- **Duration:** 5-21 days.
- **Submission:** Cantina portal, Markdown, often with required PoC for High severity.
- **Severity:** Critical / High / Medium / Low / Info. Critical exists and is weighted heavily.
- **Payout math:** Pool split by severity weights, with explicit *de-duplication* and *quality* multipliers. Cantina also runs *managed* contests where Spearbit auditors anchor judging.
- **Judging:** Spearbit lead auditor + sponsor. Generally regarded as the most "auditor-like" judging bar.
- **COI:** Strict for Spearbit-affiliated researchers.

### Immunefi (contrast)

- **Not a contest platform.** Immunefi hosts continuous live-protocol bounties. You disclose privately to the protocol, get paid per the program's severity table (often Critical = % of funds at risk, capped at $X). Closer to a traditional H1/BugCrowd model than to C4/Sherlock/Cantina.
- **Use Immunefi for:** Post-launch protocols, long-tail research, n-day work after a public fix ([[one-day-from-patch-diff]]).
- **Use contest platforms for:** Pre-launch code, predictable scope, structured deadlines.

## The pooled-prize model: what it changes for your strategy

The economic mechanic — *fixed pool split by uniqueness* — drives everything:

1. **Dupes are a tax, not a kill-shot.** On H1 a dupe pays $0. On C4 a dupe of a High among 30 wardens still pays ~$300-$1k. So *submit anyway*, but optimize for solo finds.
2. **Severity inflation is policed.** Submitting Highs that judges downgrade to Medium hurts your "warden score" on C4 and your stake on Sherlock. Read the platform's severity rubric like a contract ([[testing-methodology-checklists]]).
3. **Time-to-find matters less than novelty.** On Day 1, low-hanging bugs (reentrancy, missing access control) are already getting dupes. By Day 4, only *deep* bugs (math edge cases, cross-function reentrancy, oracle staleness windows) survive ([[expanding-attack-surface]]).
4. **PoCs win ties.** Two wardens report the same bug; the one with a Foundry test that *demonstrates fund loss* often gets graded higher. See [[demonstrating-impact]].
5. **QA reports are real money.** On C4, a well-written QA aggregating 15 low/info findings can pay $500-$2k. Don't ignore them — they teach you the codebase for the *next* contest.

## Defensive baseline (for protocol teams)

If you are the sponsor side, here is the minimum hygiene to run a contest well:

- **Freeze the codebase.** No mid-contest edits except for clarifications. Use a tagged commit SHA.
- **Publish a clear scope file:** in/out, deployed networks, trust assumptions, *known issues* list (so judges can dedupe against it).
- **Pre-contest cleanup:** Slither, Aderyn, and Foundry's `forge test --gas-report` should be clean. Wardens will burn time on already-known issues otherwise.
- **Sponsor responsiveness:** Have a dev in the contest Discord. Ambiguous trust models eat warden hours and degrade finding quality.
- **Post-contest:** Engage with judging, fix Highs/Mediums, *re-audit* the fixes (this is where Cantina's managed model shines).

## Workflow to study

1. **Pick a finished C4 contest** with public findings. Code4rena's GitHub has every contest as a repo (`code-423n4/2024-XX-protocol-findings`).
2. **Read the scope `README.md`** as if you were entering. Note in/out, lines of code, complexity score.
3. **Try to find the top-3 Highs *yourself*** with only the scope, before reading findings. Time-box to 2 hours.
4. **Open the findings.** Map each finding to: which file, which function, what invariant was broken, what PoC was used.
5. **Pattern-cluster.** Across 5 contests, the same bug classes recur: oracle staleness ([[oracle-manipulation]]), reentrancy via callbacks ([[reentrancy]]), vault share inflation ([[erc4626-vault-attacks]]), bridge message replay ([[bridge-attacks-modern]]), permit signature replay ([[permit-eip2612-phishing]]).
6. **Pick a *live* contest** with <72h remaining (low entry cost, urgent). Submit one finding, even a Medium. The submission UX itself is half the learning.
7. **After it ends**, read every finding the judges accepted. Add the bug class to your personal checklist ([[testing-methodology-checklists]]).

Repeat weekly for 8-12 weeks before expecting consistent payouts. The skill curve is steeper than Web2 because the bug surface is narrower but deeper.

## Common pitfalls

- **Submitting "centralization risk" as High on Sherlock.** It will be invalidated per their rules. Read the *Hierarchy of Truth* first.
- **Skipping the PoC for a math bug.** Judges will downgrade. Always write a Foundry test, even a 20-line one.
- **Chasing every contest.** Pick 2-3/month that match your strengths (vaults vs. AMMs vs. bridges vs. cross-chain). Depth > breadth ([[program-selection-tactics]]).
- **Ignoring QA.** Even a $300 QA payout funds another week of focused study.
- **Not reading judge comments.** When your finding is invalidated, the comment usually tells you *exactly* what the bar was. Free education.

## Related

- [[web3-bug-bounty-methodology]]
- [[blockchain-security]]
- [[smart-contracts-overview]]
- [[reentrancy]]
- [[oracle-manipulation]]
- [[flash-loan-attacks]]
- [[erc4626-vault-attacks]]
- [[bridge-attacks-modern]]
- [[permit-eip2612-phishing]]
- [[program-selection-tactics]]
- [[demonstrating-impact]]
- [[report-writing-step-by-step]]
- [[testing-methodology-checklists]]
- [[one-day-from-patch-diff]]

## References

- Code4rena docs and contest archive: https://docs.code4rena.com/
- Code4rena findings repos (GitHub org): https://github.com/code-423n4
- Sherlock audit docs and Hierarchy of Truth: https://docs.sherlock.xyz/audits
- Cantina competitions and docs: https://cantina.xyz/competitions
- Immunefi vulnerability severity classification (for contrast): https://immunefi.com/immunefi-vulnerability-severity-classification-system-v2-3/
- Secureum / Rekt News write-ups for case studies: https://rekt.news/
