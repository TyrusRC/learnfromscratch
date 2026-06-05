---
title: Solana program attacks
slug: solana-program-attacks
aliases: [solana-attacks, solana-program-vulns, anchor-vulns]
---

> **TL;DR:** Solana programs (smart contracts) live in a fundamentally different model from EVM: accounts are explicit and passed in, programs are stateless, and ownership is verified by program ID. The dominant vulnerability classes are account-confusion (missing owner check, wrong account passed in), arithmetic with implicit conversions in Rust, PDA (Program Derived Address) collision, and CPI (cross-program invocation) trust assumptions. Anchor framework reduces but doesn't eliminate the classes. Companion to [[bridge-attacks-modern]] and [[reentrancy]].

## Why Solana differs from EVM

- **Accounts model**: every state is an account; the program is stateless; accounts must be passed in explicitly.
- **Owner check is the security boundary**: a program owns the accounts it can mutate; reading another account requires checking its owner field.
- **Rust language**: type-safe but Rust arithmetic still requires explicit checked operations.
- **PDA (Program Derived Address)**: accounts derived deterministically from seeds — no private key, owned by a program.
- **CPI**: programs call other programs; the called program inherits some context from the caller.
- **Compute budget**: each transaction has a max compute units (CU), not gas-priced linearly.

The EVM mental model (storage slots, msg.sender, gas) doesn't transfer; you must learn Solana's primitives.

## Class 1 — Missing owner check

A program receives an account in its instruction. The program needs to verify the account is owned by the expected program ID (e.g., SPL Token program for token accounts). Without the check:

```rust
// Vulnerable: trust the account without owner check
let token_account = &ctx.accounts.token_account;
let amount = token_account.amount;  // attacker can fake a struct
```

Attacker creates a fake account with the same byte layout, places desired numbers in the fields, passes it. The program reads the fake values; logic produces unintended behaviour.

Anchor's `Account<'info, T>` automatically owner-checks if `T` has a discriminator; but lower-level `AccountInfo` bypasses it.

## Class 2 — Missing signer check

Similar but for `is_signer`. If a program assumes the user signed the transaction but doesn't check `signer_info.is_signer`, anyone can call the function pretending to be that user.

```rust
// Vulnerable
let user = &ctx.accounts.user;
// no check: ensure!(user.is_signer, ErrorCode::Unauthorized);
do_something_as_user(user);
```

## Class 3 — Account substitution

Two accounts of the same type passed in different parameter slots. If the program doesn't distinguish them by some unique key:

```rust
// Both vault_a and vault_b are token accounts — same struct.
// Attacker swaps to drain a different vault.
let vault = &ctx.accounts.vault_a;
let recipient = &ctx.accounts.recipient;
// transfer from vault to recipient...
```

If `vault_a` is supposed to be a specific account, verify by stored config or PDA derivation.

## Class 4 — PDA bump / seeds confusion

PDAs are derived from `(seeds, program_id, bump)`. Attacks:
- **Wrong bump** — `find_program_address` gives the canonical bump; if the program accepts attacker-supplied bump without verification, attacker can pass a different valid PDA.
- **Seed collision** — two derived PDAs collide if seeds aren't disambiguated.
- **PDA spoofing** — caller-supplied PDA used without re-derivation.

Anchor's `seeds = [...]` constraint mitigates this; manual code may not.

## Class 5 — Arithmetic underflow / overflow

Rust panics on overflow in debug, wraps in release by default — but Solana programs compile in release. Use `checked_add` / `checked_sub` etc., or use `overflow-checks = true` in Cargo.

Many older Solana programs shipped without `overflow-checks`. Attackers exploit subtractions producing wraparound.

## Class 6 — CPI without signer privilege check

Cross-program invocations allow program A to call program B with A's signer privilege over a PDA. If A signs the CPI with a PDA seed it shouldn't have authority for:
- Or if A reuses someone else's PDA;
- Or fails to verify B is the expected program ID.

The chain can let an attacker call privileged functions of B impersonating A.

## Class 7 — Reentrancy (sort of)

Solana doesn't allow direct reentrancy (a program can't invoke itself), but CPI chains can simulate reentrancy in some patterns:
- Program A calls B which calls A — Solana prevents this (will fail).
- Program A calls B which calls C which writes to A's accounts in a way A didn't expect.

The classic EVM reentrancy class is rare; logic-error chains via CPI are more common.

## Class 8 — Anchor discriminator collision

Anchor accounts begin with an 8-byte discriminator derived from the struct name (`sha256(struct_name)[:8]`). If two structs have the same discriminator (rare but possible across crates), they can be substituted.

## Class 9 — Token-program assumptions

SPL Token program is the standard token. Attacks:
- **Wrong token mint** passed but program doesn't verify mint matches expected.
- **Wrong token program** (e.g., Token-2022 with hooks) treated as classic SPL.
- **Frozen account** state not checked.

## Recent / public incidents

- **Wormhole bridge Solana side (Feb 2022)** — see [[bridge-attacks-modern]]. The Solana program failed to verify the `signature_set` account was the legitimate one; attacker passed fake set.
- **Mango Markets (Oct 2022)** — oracle / price manipulation; not a Solana-program-specific vuln but lived on Solana.
- Various Anchor program audit reports from Neodyme, OtterSec, Trail of Bits document recurring patterns.

## Audit checklist

For an Anchor program:
- `#[account]` attributes — owner, signer, has_one, constraint clauses.
- `seeds = [...]` and `bump` in PDAs.
- All numerical ops use checked or `overflow-checks` enabled.
- CPI calls: verify program ID matches expected.
- Token operations: verify mint matches expected.
- Discriminator-collision impossible across struct universe.

For raw Rust Solana programs:
- Every account access starts with manual owner check.
- Manual signer checks.
- Manual seed verification.
- Manual mint check on token operations.
- Test invariants under wrap / overflow.

## Workflow to study in a lab

1. Set up Solana CLI + Anchor.
2. Clone a known-vulnerable program (CTF-grade examples exist on Sec3 / OtterSec repos).
3. Reproduce the attack against `localnet`.
4. Patch with the standard pattern (owner check, PDA verification).
5. Test the patched version against the same attack.

## Related

- [[bridge-attacks-modern]] — Solana side of cross-chain bugs.
- [[oracle-manipulation]] — applies to Solana DeFi.
- [[reentrancy]] — EVM analogue.
- [[move-language-audit]] — Sui / Aptos.

## References
- [Anchor docs](https://www.anchor-lang.com/)
- [Neodyme — Solana audit research](https://blog.neodyme.io/)
- [OtterSec writeups](https://osec.io/blog/)
- [Sec3 — Solana program security](https://www.sec3.dev/blog)
- [Helius — Solana developer security guide](https://www.helius.dev/blog/)
- See also: [[bridge-attacks-modern]], [[oracle-manipulation]], [[reentrancy]], [[move-language-audit]], [[cosmos-ibc-attacks]]
