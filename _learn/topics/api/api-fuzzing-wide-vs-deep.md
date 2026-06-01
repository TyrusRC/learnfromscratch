---
title: "API fuzzing: wide vs deep"
slug: api-fuzzing-wide-vs-deep
---

> **TL;DR:** Wide fuzzing sweeps every endpoint with a single payload set to spot anomalies; deep fuzzing pours curated, type-aware payloads into one endpoint. Use wide first to find candidates, deep to weaponise.

## What it is
Two complementary strategies for stressing API parameters. **Wide** treats the API as a flat surface and looks for the one endpoint that crashes, leaks, or auth-bypasses on a generic payload. **Deep** picks one endpoint, models every parameter (type, length, encoding, enum), and exhausts the input space with tailored mutations. Mature targets resist wide but still break on deep; immature targets fall to wide and rarely need deep.

## Preconditions / where it applies
- A parsed spec or a captured request corpus (use [[swagger-discovery]] or [[api-content-discovery]] first)
- Authentication tokens for both low- and high-privilege roles — anomalies often only show under auth
- A baseline of "normal" responses for diff-based anomaly detection

## Technique
**Wide pass.** Replay every known request with the same small payload bundle and diff responses:

```bash
# replay every endpoint with one boundary value per param type
ffuf -u https://api.target.com/FUZZ -w endpoints.txt \
     -X POST -H 'Authorization: Bearer T' \
     -d '{"x":"AAAA...4096","n":2147483648,"a":[null,null]}' \
     -mc all -fs $(curl -s -o/dev/null -w'%{size_download}' baseline)
```

Triage by status, response size, latency. A single 500 in a sea of 400s is the signal.

**Deep pass.** Feed one endpoint to a stateful fuzzer that knows its grammar:

1. Generate a JSON template from the spec (`prance`, `schemathesis`).
2. Mutate per type: strings -> traversal, SQL, XXE, template syntax; integers -> ±MAX, negative, 0, type-juggle; arrays -> empty, deeply nested, mixed types.
3. Add semantic mutations: swap IDs across tenants ([[bola]]), add forbidden fields ([[mass-assignment]]), bump role enums ([[bfla]]).
4. Track coverage by distinct error/stack-trace hashes — stop when new mutations stop producing new hashes.

```bash
schemathesis run --checks all -H 'Authorization: Bearer T' \
  https://api.target.com/openapi.json
```

## Detection and defence
- High parameter-cardinality from a single token in a short window — characteristic deep-fuzz signature
- 5xx spike — log every distinct exception stack and alert on novel ones, attackers depend on these for differentiation
- Strict input validation at the gateway (schema-based, not allowlist patterns)
- Centralise error responses so behaviour does not leak which validator rejected the payload

## References
- [Schemathesis](https://schemathesis.readthedocs.io/) — property-based fuzzer driven by OpenAPI
- [OWASP API Security Top 10 2023](https://owasp.org/API-Security/editions/2023/en/) — anomaly classes to target
- [HackTricks: Web fuzzing](https://book.hacktricks.wiki/en/pentesting-web/web-vulnerabilities-methodology.html) — payload corpora reusable for APIs
