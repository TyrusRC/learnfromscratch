---
title: npm postinstall and typosquat — audit
slug: npm-postinstall-and-typosquat-audit
aliases: [npm-supply-chain, node-supply-chain-audit]
---

{% raw %}

> **TL;DR:** npm's two biggest supply-chain entry points are `postinstall` scripts (run shell commands during `npm install`) and typosquat packages (visually similar names tricking developers). Audit `package.json` and `package-lock.json` for: which deps have install scripts, which deps have suspiciously short publish history, and which deps were added in the last 90 days. Several high-profile incidents (event-stream, ua-parser-js, node-ipc) followed this pattern.

## Attack surface

### 1. `postinstall` / `preinstall` / `prepare`
- Run on `npm install` with full user privileges.
- Sees: working directory, env (incl. `NPM_TOKEN`, `AWS_ACCESS_KEY`, CI secrets), can read/write filesystem, can shell out.
- Targets: CI runners (steal `GITHUB_TOKEN`, push backdoors), dev machines (steal `~/.aws`, browser cookies), production builds (inject into build output).

### 2. Typosquat
- `lodash` vs `loadash`, `react-router` vs `react-routerdom` (no hyphen), `colors.js` vs `colorss.js`.
- Often combined with payload obfuscation (`eval(Buffer.from('base64...').toString())`) to evade casual review.
- Reported regularly by Phylum, Socket, Snyk.

### 3. Account takeover / 2FA-not-required
- npm requires 2FA for top-1000 packages only (as of 2026). Smaller deps still vulnerable to credential reuse.
- Maintainer turnover (project handed off to anonymous helper) — see `event-stream` incident.

### 4. Dependency confusion
- Private package name accidentally claimed on public registry → `npm install` may resolve to attacker's public copy.
- Affects scoped vs unscoped packages and any registry that falls back to public.

### 5. Compromised CI build chain
- Attacker compromises a tool used in your build (`@vercel/ncc`, `webpack-cli` plugin), publishes a backdoored version. Your CI installs and runs it.

## Audit workflow

### Static audit of repo
```bash
# 1. Enumerate every install hook in the tree
jq -r '.. | objects | select(.scripts) | .scripts | to_entries[] | select(.key | test("^(pre|post)?install$|^prepare$")) | .key + " " + .value' \
  node_modules/*/package.json 2>/dev/null | sort -u

# Or with npm
npm ls --all --json | jq '..|.dependencies?|select(.)|keys[]' -r | sort -u

# 2. Direct dependencies in your package.json
jq '.dependencies, .devDependencies' package.json

# 3. Lockfile age (when was each dep first added?)
git log --oneline -- package-lock.json | head -20
```

### Suspicious indicators per dep
- Very recent first publish (<90 days) for a dep that claims maturity.
- Single maintainer with no GitHub linkage.
- Repository URL doesn't match registry name.
- Recent version bumps with low download numbers.
- `postinstall` script that runs anything beyond a single compile command.

### Lockfile diff in PRs
- `package-lock.json` diff is the high-signal audit surface.
- Any new transitive dep, any maintainer change, any registry URL drift → flag.
- Bots like `dependabot` / `renovate` merge confusion is a known attacker pattern; require human review on lockfile-only diffs from these bots.

### Tools
- **Socket.dev** — runtime analysis of npm packages; flags eval, network calls, postinstall behaviour.
- **Phylum** — supply chain risk score for each version.
- **Snyk Open Source** + `snyk test` in CI.
- **`npm audit signatures`** — verify package signatures (npm 9+).
- **`npm-force-resolutions`** + `overrides` field — pin transitive vulnerable deps.
- **OSV-Scanner** (Google) — open-source dep CVE scan.
- **OpenSSF Scorecard** — repo health score.

## Hardening

### Build pipeline
- `npm ci --ignore-scripts` for production install — skips postinstall entirely. Build artefacts pre-compiled into ship-ready form.
- Use `pnpm` with `ignoreDepScripts: true` + explicit allowlist for known-safe deps that need install hooks.
- Run install in a sandbox (Firejail, gVisor, container without network) — install can't reach internet beyond registry.

### CI
- Separate token for npm install (read-only npm); main `GITHUB_TOKEN` not in install scope.
- Don't run `npm install` in the same job that has deploy creds.
- Cache `node_modules` keyed on lockfile hash — install rarely runs in CI if lockfile unchanged.

### Repo policy
- Pin lockfile (`npm ci`, not `npm install`, in CI).
- Require human review on every lockfile diff.
- Enable npm 2FA + signed commits org-wide on packages you publish.
- Use `private: true` on root `package.json` to prevent accidental publish.

### Pre-install screening
- `package.json` allowlist via a wrapper script that runs before `npm install` and rejects unknown deps.
- Block install of any dep with `postinstall` unless explicitly whitelisted.

## References
- [Socket.dev research blog](https://socket.dev/blog)
- [Phylum incident writeups](https://blog.phylum.io/)
- [npm — security best practices](https://docs.npmjs.com/policies/security)
- [GitHub Advisory Database](https://github.com/advisories)
- [Alex Birsan — Dependency confusion](https://medium.com/@alex.birsan/dependency-confusion-4a5d60fec610)
- See also: [[nodejs-code-auditing]], [[ci-cd-as-cloud-attack-surface]]

{% endraw %}
