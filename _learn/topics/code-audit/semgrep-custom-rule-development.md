---
title: Semgrep — custom rule development
slug: semgrep-custom-rule-development
---

> **TL;DR:** Semgrep is grep-for-code with structural awareness — patterns match AST shapes, not raw text. Rules are YAML, fast to write, fast to run (seconds on million-line repos). Best for codebase-specific anti-patterns where CodeQL would be overkill: forbidden function calls, missing decorators, dangerous coding idioms. Pairs with [[codeql-custom-query-development]] for deep taint analysis.

## What it is
Semgrep open-source CLI + Semgrep AppSec Platform (commercial backend, optional). Three rule registries:
- `semgrep --config auto` — community rules, language auto-detect
- `semgrep --config p/security-audit` — curated security pack
- `semgrep --config ./my-rules/` — local custom rules

Rule language: YAML with `pattern`, `patterns`, `pattern-either`, `metavariable-pattern`, `taint` modes.

## Preconditions / where it applies
- Source code; works on partial / non-compiling code (unlike CodeQL)
- ~30 supported languages; depth varies (JS/Python/Java/Go/C# mature, Rust/Swift improving)
- For CI: works in GitHub Actions, GitLab, Jenkins, pre-commit hooks

## Tradecraft

**Run defaults:**

```bash
pip install semgrep
semgrep --config auto src/
# Or specific pack
semgrep --config p/owasp-top-ten src/
```

**Anatomy of a custom rule:**

```yaml
rules:
  - id: jwt-no-expiry-check
    message: JWT verification without expiry check
    severity: ERROR
    languages: [javascript, typescript]
    metadata:
      cwe: 'CWE-613: Insufficient Session Expiration'
      owasp: 'A07:2021'
    pattern-either:
      - pattern: jwt.verify($TOKEN, $KEY)
      - pattern: jsonwebtoken.verify($TOKEN, $KEY)
    pattern-not: jwt.verify($TOKEN, $KEY, { ..., maxAge: ..., ... })
    pattern-not: jwt.verify($TOKEN, $KEY, { ..., expiresIn: ..., ... })
```

`$TOKEN` / `$KEY` are metavariables — they match any expression. `$...ARGS` matches variable-length argument lists.

**Common pattern primitives:**

```yaml
# Match function call
pattern: dangerous_func($X)

# Match with type info (Java/Go/TS)
pattern: |
  String $X = request.getParameter("...");
  $SINK($X);

# Boolean combinator
patterns:
  - pattern: db.query($Q)
  - pattern-not: db.query("SELECT * FROM users WHERE id = ?", $X)

# Metavariable regex
pattern: |
  process.env.$VAR
metavariable-regex:
  metavariable: $VAR
  regex: '(?i)(secret|key|token|pass)'

# Ellipsis matches any expression
pattern: |
  if (req.user.role === 'admin') {
    ...
    db.execute(req.body.query);
    ...
  }
```

**Taint mode** — first-class source-to-sink tracking:

```yaml
rules:
  - id: custom-ssti
    mode: taint
    pattern-sources:
      - pattern: request.args.get(...)
      - pattern: request.form.get(...)
    pattern-sinks:
      - pattern: render_template_string($X)
    pattern-sanitizers:
      - pattern: escape($X)
      - pattern: markupsafe.escape($X)
    message: SSTI via render_template_string with user input
    severity: ERROR
    languages: [python]
```

Not as deep as CodeQL but covers most direct flows in seconds.

**Match Java annotations:**

```yaml
pattern: |
  @RequestMapping(...)
  public $RET $METHOD(...) {
    ...
  }
pattern-not-inside: |
  @PreAuthorize(...)
  public $RET $METHOD(...) {
    ...
  }
languages: [java]
message: Endpoint missing @PreAuthorize
```

**Codebase-specific examples worth writing for any team:**

```yaml
# Forbid raw SQL through internal ORM
rules:
  - id: no-raw-sql-orm
    pattern-either:
      - pattern: MyORM.raw(...)
      - pattern: $X.rawQuery(...)
    message: Use parameterised builder, not raw()

# Detect logging of PII fields
  - id: log-pii-leak
    patterns:
      - pattern-either:
          - pattern: logger.$LEVEL($X)
          - pattern: console.$LEVEL($X)
      - metavariable-pattern:
          metavariable: $X
          patterns:
            - pattern-either:
                - pattern: $OBJ.ssn
                - pattern: $OBJ.creditCard
                - pattern: $OBJ.email

# Detect new commits adding TODO security comments
  - id: todo-security
    pattern-regex: 'TODO.*(security|auth|crypto|fix.*later)'

# Forbid go's exec.Command with user input
  - id: go-exec-tainted
    mode: taint
    pattern-sources:
      - pattern: r.URL.Query().Get(...)
    pattern-sinks:
      - pattern: exec.Command(...)
    languages: [go]
```

**Run only changed files in CI (fast PR scan):**

```bash
semgrep --config ./rules \
  --baseline-ref origin/main \
  --error
```

`--baseline-ref` diffs against base branch; only new findings fail the build. Critical for adopting on legacy codebases without bankruptcy.

**Autofix:**

```yaml
rules:
  - id: md5-replace-sha256
    pattern: hashlib.md5($X)
    fix: hashlib.sha256($X)
    languages: [python]
    message: Use SHA-256 instead of MD5
```

`semgrep --autofix` rewrites code in place. Use carefully; reviewer must still validate.

**Test rules:**

Drop test file `my-rule.test.py`:

```python
# ruleid: jwt-no-expiry-check
jwt.verify(token, key);

# ok: jwt-no-expiry-check
jwt.verify(token, key, { maxAge: 3600 });
```

`semgrep --config my-rule.yaml --test` runs.

**Rule registry contribution:**
Send rules to `semgrep/semgrep-rules` repo for community benefit. Acceptance criteria: high precision, real-world relevance, tests included.

## CI integration

```yaml
# .github/workflows/semgrep.yml
jobs:
  semgrep:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/security-audit
            p/owasp-top-ten
            ./.semgrep/
          generateSarif: '1'
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: semgrep.sarif
```

Findings surface in GitHub Security tab alongside CodeQL.

## When to pick Semgrep vs CodeQL

| Need | Semgrep | CodeQL |
|---|---|---|
| Find a specific forbidden API call | ✅ minutes | overkill |
| Codebase-wide pattern enforcement | ✅ | ✅ but slow to author |
| Cross-procedural taint with library awareness | partial | ✅ |
| Compiled-language extraction | partial | ✅ |
| CI on every PR | ✅ seconds | minutes |
| Per-team customisation by AppSec engineer (not specialist) | ✅ low barrier | high barrier |
| Path-explanation for triage | basic | rich |

Many teams run BOTH: Semgrep on every PR (fast guardrails), CodeQL on nightly (deep audit).

## OPSEC pitfalls

- `--config auto` downloads rules at runtime; pin a version (`p/security-audit:v1.x`) for reproducible CI
- Pattern-not blocks have subtle semantics — `pattern-not-inside` vs `pattern-not` differ
- Metavariable scope: `$X` matches differently across `patterns:` vs `pattern-either:`
- Performance: 50,000+ rules across a monorepo can take 30 min — split rule packs by language and run in parallel
- False positives degrade trust — disable noisy rules per-project rather than letting team ignore all findings

## References
- [Semgrep documentation](https://semgrep.dev/docs/)
- [Semgrep Registry](https://semgrep.dev/r) — public rules
- [Semgrep playground](https://semgrep.dev/playground) — write + test interactively
- [Semgrep Rule Ideas](https://semgrep.dev/blog/) — practitioner blog
- [returntocorp/semgrep-rules](https://github.com/semgrep/semgrep-rules) — community rules repo

See also: [[codeql-custom-query-development]], [[source-sink-flow-analysis]], [[whitebox-to-exploit-methodology]], [[sast-dast-ci-integration]], [[sast-dast-iast-vendor-selection]], [[appsec-champions-program]], [[secrets-in-code-detection-patterns]], [[ghost-commit-smuggling]], [[dangerous-java-sinks]], [[dangerous-nodejs-sinks]], [[python-dangerous-sinks]]
