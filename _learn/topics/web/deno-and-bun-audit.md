---
title: Deno and Bun audit patterns
slug: deno-and-bun-audit
aliases: [deno-security-audit, bun-security-audit]
---

{% raw %}

> **TL;DR:** Deno's capability-based permission model (`--allow-net`, `--allow-read`) is a real defence — but only when actually used. Most production Deno runs with `--allow-all` because devs don't audit permission scope. Bun is permissive by default (Node-compat). Audit: capability flags, npm-compat surface (Bun inherits npm risks), Deno's URL-based imports (supply chain via attacker-controlled URL), and KV/Deploy specifics.

## Deno

### Permission model
Deno requires explicit capability flags at runtime. Without them, the program can't read files, network, env, or spawn subprocesses. This is the strongest production runtime sandbox in mainstream JS.

Bug patterns:

### 1. `--allow-all` in production
Most deploys do this because anything less requires devs to enumerate permissions. Audit: `deno run` invocations, Dockerfile CMD, deno.json `tasks`.
- **Fix**: minimum-viable permission flags. `--allow-net=api.example.com --allow-read=./data`.

### 2. Over-broad `--allow-net`
`--allow-net` (no value) = all network. `--allow-net=8.8.8.8,api.example.com` = specific only. Common slip: dev permission level promoted to prod.

### 3. URL-imported modules
`import { x } from "https://deno.land/x/something@v1.2.3/mod.ts"`. Import URL is the supply chain.
- `deno.land/x` mirrors GitHub but versioning is tag-based; tag could be force-pushed.
- `import_map.json` lets you alias URLs; if attacker controls the map, supply-chain hijack.
- `deno.lock` pins integrity hash — verify it's committed and CI checks it.

### 4. JSR (Deno's package registry) supply chain
- `jsr:@scope/pkg@version` — newer; scoped + 2FA required for top packages.
- Still subject to typosquat at the scope level.

### 5. Env var leak via `Deno.env`
- `--allow-env` (no value) exposes all env. Use `--allow-env=PATH,API_KEY` to limit.
- Deno KV with `Deno.openKv()` requires `--unstable-kv` historically; now stable but still scope-relevant.

### 6. Subprocess exec
- `Deno.Command` requires `--allow-run`. Without it, blocked. With it (no value), all binaries; with value, specific paths only.
- `--allow-run=git,cat` is a meaningful restriction.

### 7. FFI loaded shared libs
- `Deno.dlopen` requires `--allow-ffi`. Loading attacker-controlled `.so` = RCE outside the JS sandbox.

### 8. Deno Deploy specifics
- KV access scoped by deploy.
- Cron jobs (`Deno.cron`) run with the same permissions as the main worker.
- Edge runs at Cloudflare-like global presence; cold start similar surface.

## Bun

Bun is Node-compatible by default with extra speed. No capability model.

### 1. Audit npm-compat surface
- `bun install` uses npm registry; same risks as [[npm-postinstall-and-typosquat-audit]].
- Bun runs `postinstall` scripts; `--ignore-scripts` is the opt-out.

### 2. `bun:sqlite` and `bun:test` no isolation
- `bun:sqlite` runs in-process — same trust as the host code.
- `bun:test` has no sandboxing for tested code.

### 3. `Bun.spawn`, `Bun.write`, `Bun.serve` — Node-equivalent risks
- Same shell-concat, path-traversal, SSRF concerns as Node.
- No additional flags to limit; relies on app-level checks.

### 4. Native modules
- Bun supports Node-compat native modules. Same supply-chain surface but Bun resolves and builds differently — audit `bun.lockb` (binary lock; less human-reviewable than `package-lock.json`).

### 5. Bun's HTTP server
- `Bun.serve({ fetch })` is a clean primitive. Audit handler for same web-app surface as any Node server.

### 6. Workers via `Worker`
- Web-Worker compat exists; not full Node-isolate. Cross-worker state via SharedArrayBuffer possible.

## Audit checklist

### Deno
```bash
# Find every deno invocation
rg -n 'deno (run|task|test|deploy|cache)' .
# Check permission flags
rg -n '\-\-allow-(net|read|write|env|run|ffi|hrtime)' .
# Find URL imports
rg -n 'from\s+["\x27]https?://' .
# Verify lock file present
ls -la deno.lock
```

### Bun
```bash
# Lockfile present and binary
ls -la bun.lockb
# Scripts in package.json
jq '.scripts' package.json
# postinstall enumeration
jq '.dependencies, .devDependencies' package.json
# Check ignore-scripts in CI
grep -n 'bun install' .github/workflows/*.yml
```

## Hardening

### Deno
- Lowest-viable permission flags in prod.
- `deno.lock` committed; CI enforces.
- `import_map.json` reviewed; URLs from trusted sources only.
- Prefer JSR over `deno.land/x` for new code.
- `Deno.permissions.query()` runtime check before sensitive ops.

### Bun
- `bun install --ignore-scripts` in CI for production builds.
- Lock to specific Bun version (`bun-version` file).
- Same secret-management discipline as Node.
- Snyk/Socket scan `package.json` deps.

## References
- [Deno security manual](https://docs.deno.com/runtime/manual/basics/permissions/)
- [Deno KV docs](https://docs.deno.com/deploy/kv/manual/)
- [JSR security policy](https://jsr.io/docs/security)
- [Bun docs](https://bun.sh/docs)
- See also: [[nodejs-code-auditing]], [[dangerous-nodejs-sinks]], [[npm-postinstall-and-typosquat-audit]]

{% endraw %}
