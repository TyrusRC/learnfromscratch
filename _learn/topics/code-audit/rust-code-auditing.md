---
title: Rust code auditing
slug: rust-code-auditing
aliases: [rust-source-review, rust-security-audit]
---

{% raw %}

> **TL;DR:** Memory safety covers UAF/double-free/buffer overflow in safe Rust — but logic bugs, integer overflow on release builds, FFI boundaries, `unsafe` blocks, serde deserialization with type tags, and supply-chain (`build.rs`, proc-macros) all remain. Audit those surfaces; the safe code in between is usually fine.

## What it is
Rust audits flip the bug ratio: memory-corruption RCE is rare, but `unsafe`/FFI/`Box::from_raw` blocks, integer arithmetic without `checked_*`, and supply-chain `build.rs` exec are where real bugs hide. Web stacks (axum, actix-web, rocket, warp) add the usual web bug families on top.

## Preconditions / where it applies
- Source (`*.rs`, `Cargo.toml`, `Cargo.lock`)
- Edition (2021 / 2024) + MSRV — pattern bindings, async traits differ
- Knowledge of ownership/borrowing, lifetimes, the `unsafe` contract

## Technique
1. **Map entry points.**
   - axum: `Router::new().route("/", get(handler))`.
   - actix-web: `App::new().service(web::resource(...))`.
   - rocket: `#[get("/foo")] async fn handler(...)`.
   - warp: `warp::path!("...").and(warp::body::json())`.
   - CLI: `clap` argument structs (`#[derive(Parser)]`).
2. **Audit every `unsafe` block.** `rg -n 'unsafe\s*\{' src/` then read each block's invariants. The `// SAFETY:` comment above is the contract — verify it holds across all callers, not just the file-local ones. Common bugs: missing alignment, lifetime extension, `transmute` of types with different drop semantics, off-by-one in pointer arithmetic.
3. **Audit FFI.** Every `extern "C"` and every `bindgen`-generated wrapper. C lib bugs cross into your Rust UB cleanly. `CString::new` rejects null bytes — handle the error. `from_raw_parts` requires lifetime invariant the borrow checker can't see.
4. **Integer overflow.** Debug builds panic, release builds wrap silently. Audit any arithmetic touching size/offset/index for `checked_add`/`saturating_*`/`wrapping_*` discipline. `a + b` with attacker-controlled `a` or `b` in a length field is a classic OOB-write enabler when the result is used as a buffer index.
5. **Serde deserialization.**
   - `#[serde(untagged)]` enums try variants in order — attacker can pick which Rust type to construct.
   - `#[serde(rename_all = "lowercase")]` with overlapping field names → confusion.
   - `serde_json::Value` then conversion — type-narrow at the boundary.
   - `bincode` / `ciborium` / `postcard`: binary format integer-overflow on length prefixes.
6. **`unwrap`/`expect` audit.** Anywhere in a request path, `.unwrap()` on attacker input → DoS panic crash. Treat each as a bug; require `?` or `unwrap_or`. `tokio::spawn` panic doesn't propagate — silent task death.
7. **Async + locking.** `Arc<Mutex<T>>` held across `.await` is a deadlock waiting to happen. Use `tokio::sync::Mutex` for that case, or scope the lock guard.
8. **Web bug families.** axum extractors trust the type system — `Json<Foo>` with `serde::Deserialize` will populate every field; add `#[serde(deny_unknown_fields)]` to block mass-assignment. SSRF, SQLi (sqlx `query!` is safe; `query` with `format!` is not), template injection (askama/handlebars compile from string), command injection (`std::process::Command` with shell concat) all apply.
9. **`build.rs` and proc-macros.** Both run on the dev machine at `cargo build` time. Malicious crate → RCE on your CI / dev box. Audit deps' `build.rs` and proc-macros for network calls, shell out, env reads, file writes outside `OUT_DIR`. Pin transitively in `Cargo.lock`; review `cargo update` diffs.
10. **`cargo-audit` and `cargo-deny`.** Run in CI. `cargo-vet` (or `cargo-crev`) for trust-chain on top crates.
11. **Cryptography.** `rand::thread_rng()` is CSPRNG; `rand::random()` is too. `RustCrypto` `aes-gcm` / `chacha20poly1305` for symmetric. Constant-time compare via `subtle::ConstantTimeEq`. Avoid hand-rolling block-cipher modes.
12. **`ring`/`rustls` audit.** Both are well-reviewed; flag any custom forks. `webpki` cert chain validation is opt-in for some patterns — check that `verify_is_valid_tls_server_cert` is called.

## Detection and defence
- `cargo clippy -- -W clippy::pedantic -W clippy::nursery` — many security-adjacent lints (`integer_arithmetic`, `panic_in_result_fn`).
- `cargo-audit` (RustSec advisory DB), `cargo-deny` (license/source/dup), `cargo-vet` (trust chain).
- `cargo geiger` — counts `unsafe` use across the tree; spike = new attack surface.
- `loom` for concurrency model checking on critical paths.
- For FFI: pair each `extern` block with `bindgen --no-derive-debug --no-derive-default` review.

## References
- [Rustonomicon (unsafe contract reference)](https://doc.rust-lang.org/nomicon/)
- [RustSec Advisory Database](https://rustsec.org/)
- [Trail of Bits — Rust auditing methodology](https://blog.trailofbits.com/2024/12/12/auditing-rust-code/)
- [Ferrocene / KaniOS — formal verification tooling](https://model-checking.github.io/kani/)
- See also: [[rust-go-reverse]]

{% endraw %}
