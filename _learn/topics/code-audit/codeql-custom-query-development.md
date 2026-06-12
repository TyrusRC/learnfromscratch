---
title: CodeQL — custom query development
slug: codeql-custom-query-development
---

> **TL;DR:** CodeQL treats code as data: extractors build a relational database from a source tree, queries written in QL (a Datalog/SQL-like declarative language) ask security questions across that DB. Custom queries beat default rulesets when you know your codebase's specific sinks, sources, and sanitisers. Standard in GitHub Advanced Security and competitive bug-bounty source-review.

## What it is
CodeQL has three pieces:
- **CLI** (`codeql`) — builds DBs, runs queries
- **Language packs** — extractors + standard library (JavaScript/TypeScript, Python, Java/Kotlin, C/C++, C#, Go, Ruby, Swift)
- **Query packs** — prebuilt queries (`codeql/security-queries`, `codeql/security-extended`, custom packs)

Queries return rows. Security queries are usually expressed as `path-problem` (taint-flow) or `problem` (single point). Output is SARIF for tooling integration.

## Preconditions / where it applies
- Source code you can compile (compiled languages) or parse (interpreted)
- CodeQL CLI installed: `gh extension install github/gh-codeql` or direct download
- VS Code + CodeQL extension for interactive query development

## Tradecraft

**Create a database from a project:**

```bash
# Compiled (Java/Kotlin) — needs build invocation
codeql database create db-java --language=java --command="mvn clean install -DskipTests"

# Compiled (C/C++) — needs build invocation
codeql database create db-cpp --language=cpp --command="make clean && make"

# Interpreted (JavaScript / Python) — no build needed
codeql database create db-js --language=javascript --source-root=./src
codeql database create db-py --language=python --source-root=./src
```

DB ends up as a directory; typical size 100 MB–10 GB.

**Run prebuilt queries:**

```bash
codeql database analyze db-js --format=sarif-latest \
  --output=results.sarif \
  codeql/javascript-queries:codeql-suites/javascript-security-extended.qls
```

`security-extended` is the deeper ruleset (precision: high+medium); `security-and-quality` adds maintainability queries (verbose).

**Write a custom query — anatomy:**

```ql
/**
 * @name Unsafe deserialisation via custom helper
 * @description Calls to MyApp.Helpers.UnsafeDeserialize() with user-controlled input
 * @kind path-problem
 * @problem.severity error
 * @precision high
 * @id myorg/unsafe-deser
 * @tags security
 *       external/cwe/cwe-502
 */

import javascript
import semmle.javascript.security.dataflow.UnsafeDeserializationQuery
import DataFlow::PathGraph

class MyConfig extends TaintTracking::Configuration {
  MyConfig() { this = "MyConfig" }

  override predicate isSource(DataFlow::Node source) {
    source instanceof RemoteFlowSource
  }

  override predicate isSink(DataFlow::Node sink) {
    exists(DataFlow::CallNode call |
      call.getCalleeName() = "UnsafeDeserialize" and
      sink = call.getArgument(0)
    )
  }
}

from MyConfig cfg, DataFlow::PathNode source, DataFlow::PathNode sink
where cfg.hasFlowPath(source, sink)
select sink.getNode(), source, sink,
       "Unsafe deserialisation of $@.", source.getNode(), "user input"
```

Run it:

```bash
codeql query run --database=db-js path/to/myquery.ql
codeql database analyze db-js path/to/myquery.ql --format=sarif-latest --output=out.sarif
```

**Taint-tracking primitives** every QL learner needs:

```ql
// Define source from a specific framework annotation
override predicate isSource(DataFlow::Node n) {
  exists(Decorator d | d.getName() = "RequestBody" and
                       n.asExpr() = d.getElement())
}

// Define sanitizer
override predicate isSanitizer(DataFlow::Node n) {
  exists(CallExpr c | c.getCalleeName() = "escapeHtml" and n.asExpr() = c)
}

// Define additional taint step (helper that passes taint through)
override predicate isAdditionalTaintStep(DataFlow::Node a, DataFlow::Node b) {
  exists(MethodCall mc | mc.getMethodName() = "format" and
                          a = DataFlow::exprNode(mc.getAnArgument()) and
                          b = DataFlow::exprNode(mc))
}
```

**Path-problem vs problem:**
- `@kind problem` — finding at one location (e.g., hardcoded secret)
- `@kind path-problem` — taint flow from source to sink, full path emitted

**Develop iteratively in VS Code:**
- Open query → "CodeQL: Run Query on Selected Database"
- Results pane shows hits + flow paths
- Click any result → jumps to code
- "CodeQL: View AST" for any node — invaluable for figuring out the QL type to match

**Test queries:**
QL tests live in `<query>.expected` files. Tweak query, run `codeql test run`. Treat queries as code — version control, code review, CI.

**Reuse standard library:**

```ql
import semmle.javascript.security.dataflow.SqlInjectionQuery
// Extend rather than rewrite — add your custom sinks to the existing config
class MySqlInjConfig extends SqlInjection::Configuration {
  override predicate isSink(DataFlow::Node n) {
    super.isSink(n) or
    exists(DataFlow::CallNode c | c.getCalleeName() = "rawQuery" and n = c.getArgument(0))
  }
}
```

**GitHub Code Scanning integration:**

```yaml
# .github/workflows/codeql.yml
- uses: github/codeql-action/init@v3
  with:
    languages: javascript, python
    queries: +./security-queries/myorg-extended.qls
- uses: github/codeql-action/analyze@v3
```

`+` prepends to the default suite. Findings appear in repo Security tab; PR check fails when new alerts exceed threshold.

**Common custom-query patterns worth writing:**
- Sinks in your internal framework (`MyLogger.logRaw()` if it bypasses sanitisation)
- Auth-decorator absence — find controllers without `@RequireAuth`
- Secret detection beyond regex (entropy + name patterns + variable context)
- Insecure crypto: MD5/SHA1 on password fields
- Logging of sensitive variables (PCI / GDPR violation)
- Cross-tenant ID propagation patterns
- Custom deserialisation helpers your library defines as "safe" but aren't

## Bounty / pentest practitioner usage

- Build DB on every release artifact you have access to — even unmodified, default queries catch low-hanging
- Read the candidate's open-source dependencies via `codeql download` — saves recompiling them
- For closed-source PHP / Python web apps you can review: zip + extract = DB; iterate
- Triage results: order by precision DESC, severity DESC; sample top-50 manually
- CodeQL Compete (LGTM successor) — practice public CTFs

## OPSEC pitfalls

- DB size on large monorepos (LLVM, Chromium): plan for 50+ GB and 4-8 hours build
- C++ extraction requires the EXACT compile commands; if `make` skips a TU, it's missing from DB
- Python: dynamic dispatch is approximate; queries flag false positives more than Java
- Suite selection: `security-extended` finds more bugs but also more false positives — calibrate per repo

## References
- [CodeQL documentation](https://codeql.github.com/docs/)
- [CodeQL standard library reference](https://codeql.github.com/codeql-standard-libraries/)
- [github/codeql repository](https://github.com/github/codeql) — every default query, study these as patterns
- [CodeQL CTF — securitylab](https://securitylab.github.com/ctf/) — practitioner training
- [Lukas Stefanko / GitHub Security Lab blog](https://github.blog/category/security/)

See also: [[semgrep-custom-rule-development]], [[source-sink-flow-analysis]], [[whitebox-to-exploit-methodology]], [[dangerous-java-sinks]], [[dangerous-nodejs-sinks]], [[python-dangerous-sinks]], [[dangerous-aspnet-sinks]], [[dangerous-go-sinks]], [[sast-dast-ci-integration]], [[sast-dast-iast-vendor-selection]], [[appsec-champions-program]]
