---
title: ReDoS hunting methodology
slug: redos-hunting-methodology
---

> **TL;DR:** Regular Expression Denial of Service (ReDoS) bugs come from catastrophic backtracking in NFA-based regex engines (JavaScript, Python's `re`, Java, .NET, Ruby). A crafted input causes exponential matching time, hanging an endpoint per request. Findable from source review, dependency audit (`vuln-redos` packages), or black-box fuzzing of user-controlled fields validated by regex.

## What it is
NFA regex engines (the default in Node.js, Python, Java, .NET, PHP, Ruby) explore possible matches via backtracking. Certain regex patterns combined with non-matching inputs trigger O(2^n) work — a 50-character input can take minutes. Modern bounty programs accept ReDoS reports against authenticated and unauthenticated endpoints.

## Vulnerable patterns
Three families:
1. **Nested quantifiers**: `(a+)+`, `(.*)*`, `(\w+)*` — the inner and outer quantifier both expand
2. **Quantified overlapping alternations**: `(a|a)+`, `(x|xx)*`, `(.|\w)+`
3. **Quantified groups with optional content**: `(a*)*b` — when `b` is missing, engine retries every split of `a*`

Real-world examples:
- `^(.*)*$` against `aaaaaaaaaaaaaaaaaaaaaa!` → seconds
- `^(([a-z])+.)+[A-Z]([a-z])+$` (CVE-2017-15010, rack-protection) → hours on long lowercase strings
- `^([^,]+,)+$` against `,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,!`
- CVE-2017-16026 `request@2.88.0`: redirect URL regex

## Tradecraft (bounty hunter)

**Black-box approach:**

```bash
# Time delta probe — measure baseline first
for i in 1 2 4 8 16 32 64 128 256 512; do
  time curl -s -o /dev/null \
    --data "email=$(python3 -c "print('a'*$i + '!')")@x" \
    https://target.tld/register
done
```

Look for non-linear growth (10ms → 200ms → 2s → 20s). Linear is fine; super-linear is a bug.

**Common attack surfaces:**
- Email validators (RFC 5322 attempt regex)
- URL parsers (CVE-2024-37890 `ws` library)
- Markdown/BBCode parsers
- Username/password complexity validators
- HTTP header parsers (`User-Agent`, `Cookie`)
- JSON schema validators using regex `pattern`
- Search field server-side parsing
- GraphQL string field validators

**Test inputs (start small, escalate):**

```python
# Generic patterns — most regex engines die on at least one
attacks = [
    'a' * 30 + '!',                # for ^(a*)+$ style
    'a' * 30,                       # for ^(a*)*$ unanchored
    '!' + 'a' * 30,
    '/' + '/a' * 30 + '/',          # path-style
    '@' * 30 + '!',                 # email-style
    'http://' + 'a.' * 30,          # URL-style
]
```

**Source-review approach:** grep your dependency tree for vulnerable patterns:

```bash
# All quantified groups inside quantifiers
rg --pcre2 '\([^)]*[+*][^)]*\)[+*]' --type js
# Common ReDoS shapes in JS regex literals
rg '/.*\(.*\+.*\).*[+*].*/' --type js
```

**Tools:**
- `vuln-regex-detector` (Davis et al.) — checks libraries against known bad patterns + EGRET fuzzer
- `safe-regex` / `safe-regex2` (npm) — yes/no on a regex string
- `recheck` (JS) — runtime ReDoS detector
- `ReScue` — DFA-based safety checker
- `RegexBuddy` debug mode — visual backtracking
- `regex101.com` — debugger shows step count; slow patterns explode obviously
- `node-rate-limiter-flexible` ReDoS test harness

**Programmatic generator** for crafted bad-input strings — Wüstholz et al. "regex attack" technique:

```python
# Given a vulnerable regex, find shortest input causing exponential blowup
pip install regex-attack
regex-attack '^([a-zA-Z0-9])(([\.\-]?[a-zA-Z0-9]+)*)\@([a-zA-Z0-9]+)$'
# Outputs: "AAAAAAAAAAAAAAAAAAAAA!"
```

**Impact escalation for the report:**
- Endpoint hangs server thread → multiple requests exhaust thread pool → DoS
- For Node.js (event loop): a single ReDoS request blocks ALL pending requests on that worker
- Memory growth: some engines allocate per-step state — OOM crash variant
- Authenticated ReDoS on shared workers still affects other tenants in multi-tenant SaaS

**Demonstrate impact safely**:

```bash
# Single curl, measure response time; report includes
# normal: 80ms; attack input: 47,000ms; same input × 5: 503 errors
```

## Detection and defence

For program defenders:
- Migrate hot-path regex to RE2 (Go default, available for Node via `re2`, Python via `re2`) — DFA, no backtracking, linear time
- Bound regex execution time: Python `regex` library supports `timeout`; Java has no per-regex timeout but you can use [`Pattern.compile` + interrupt](https://stackoverflow.com/q/910740/) trick
- Replace nested quantifiers with possessive quantifiers (`(a++)+` is impossible to write incorrectly because possessives don't backtrack)
- For email validation: don't write your own; use `validator.isEmail()` (RFC 5322 with safety) or accept anything containing `@` and verify via confirmation link
- WAF rules can block obvious attack inputs (long repeats + tail char) — defense in depth, not fix
- Move validation client-side AND server-side, but rate-limit server-side endpoint per IP

## OPSEC pitfalls (bounty)

- Don't escalate to multi-request bombardment without test plan in scope; many programs treat traffic floods as DoS-out-of-scope even when the root cause is ReDoS
- Test against a separate canary account if program supports staging — production locking yourself out via complexity validator ReDoS is common
- Report ONE vuln, not a list: each vulnerable regex is a separate disclosure
- Provide patched regex + proof — "use possessive quantifier" / "use RE2" raises payout tier

## References
- [OWASP — Regular Expression DoS](https://owasp.org/www-community/attacks/Regular_expression_Denial_of_Service_-_ReDoS)
- [Davis et al. — "The Impact of Regular Expression Denial of Service (ReDoS) in Practice" (ICSE 2018)](https://people.cs.vt.edu/~davisjam/) — large-scale measurement
- [Snyk — ReDoS vulnerability database](https://security.snyk.io/vuln?type=npm&q=redos)
- [Cloudflare — How a single regex took down Cloudflare](https://blog.cloudflare.com/details-of-the-cloudflare-outage-on-july-2-2019/)
- [vuln-regex-detector](https://github.com/davisjam/vuln-regex-detector)

See also: [[automated-fuzzer-vuln-discovery]], [[rate-limit-bypass]], [[wordlist-fuzzing-tactics]], [[python-dangerous-sinks]], [[dangerous-nodejs-sinks]], [[email-gateway-bypass-techniques]], [[graphql-batching-aliasing-abuse]], [[reading-public-pocs-effectively]]
