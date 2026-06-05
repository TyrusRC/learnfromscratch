---
title: Go module substitution and vanity-domain attacks
slug: go-module-substitution-audit
aliases: [go-supply-chain-audit, go-mod-attacks]
---

{% raw %}

> **TL;DR:** Go modules are referenced by import path (URL-like). The path resolves via `go.sum` checksum + proxy + version. Attacks: vanity-domain takeover (the domain hosting the redirect is now attacker-controlled), GOPROXY rerouting, `go.sum` checksum DB bypass, `replace` directive smuggling, and capability-implicit compile-time exec via `cgo`/`embed`/`init`. Go's static-build culture means a compromised dep ships directly into your binary.

## Attack surface

### 1. Vanity-domain takeover
- Import `example.com/foo` → Go fetches `https://example.com/foo?go-get=1`, expects `meta` redirect to a real repo.
- If `example.com` lapses → attacker registers it → controls the redirect.
- Several known incidents on small personal domains.
- Audit: `go list -m all` to enumerate every module; for each, resolve the host; check domain ownership.

### 2. `replace` directive abuse
- `go.mod` can `replace` any module path with a local path or different module.
- In a malicious PR: `replace github.com/legit/dep => github.com/attacker/dep v1.0.0`.
- `go.sum` updates accordingly. Reviewer sees only `go.mod` and `go.sum` diff; if they don't read the `replace` line carefully → ships.

### 3. GOPROXY substitution
- Default `GOPROXY=https://proxy.golang.org,direct`. If attacker can MitM your CI's proxy access or run a malicious proxy:
- They serve a different module than the public source.
- The Go checksum database (`sum.golang.org`) usually catches this — but if `GOSUMDB=off` or attacker is in the build env, gone.
- Audit: confirm `GOSUMDB` not disabled in CI; pin `GOPROXY`.

### 4. `init()` and `cgo` compile-time exec
- Every imported package's `init()` runs at program start. A compromised dep can:
  - Read filesystem on startup.
  - Open a network listener.
  - Modify other globals via reflection.
- `cgo` directives in deps compile C code at build time → potential RCE on build host (less likely; needs `#cgo CFLAGS` injection).
- `go:embed` directives can embed any file under the module dir into your binary.

### 5. Module version confusion
- `+incompatible` versions, pseudo-versions (`v0.0.0-20240101000000-abcdef`), branch-style versions.
- Attacker can publish a higher version on a stale module, causing `go mod tidy` to upgrade silently.

### 6. Subdomain/subpath squatting
- `github.com/user/repo/v2` vs `github.com/user/repo` — separate module paths.
- Attacker publishes `v2` of a popular `v1`-only module. Users who `go get github.com/user/repo/v2` (typo or upgrade attempt) get attacker's code.

### 7. Compromised maintainer account
- GitHub account takeover → push malicious tag/release.
- Go encourages immutable versions, but a force-push to an existing tag (rare but possible if tag protection is off) replaces the module.

### 8. Capability creep via transitive deps
- `gin-gonic/gin` is fine; one of its 20 transitive deps is sketchy. Each `init()` runs in your process.
- `go list -m -deps all` enumerates the closure.

## Audit workflow

### Static
```bash
# Enumerate full dep graph
go list -m -deps -json all | jq '.Path, .Version, .Replace?.Path'

# Find all replace directives
grep -E '^replace' go.mod

# Find all init() functions in vendor/ (or after go mod vendor)
grep -rn 'func init()' vendor/ | head -20

# Find cgo directives
grep -rn '^// #cgo\|^/\*\n#cgo' vendor/

# Find embed directives
grep -rn '//go:embed' vendor/
```

### Suspicious indicators
- `replace` directive pointing to a non-organisation repo.
- Module hosted on a personal domain with no DNS-level continuity.
- Module first published <90 days, depended on by your transitive tree.
- Unusual `init()` doing network/filesystem ops.

### Tools
- **`govulncheck`** — official Go vuln database; runs at build time. CI-friendly.
- **OSV-Scanner** — broader CVE feed, includes Go.
- **`gosec`** — SAST for your own code, catches dangerous patterns; partial supply-chain via dep manifest scanning.
- **Snyk Open Source / Socket for Go**.
- **`go mod verify`** — verifies all deps match `go.sum`. Run in CI.

## Hardening

### Build pipeline
- `GOFLAGS="-mod=readonly"` in CI — no `go mod tidy` side-effects.
- `GOSUMDB=sum.golang.org` always (don't disable).
- Vendored deps (`go mod vendor`) + commit `vendor/` → reproducible builds + auditable diff in PRs.
- Container build with no internet beyond proxy.

### Repo policy
- Lockstep `go.mod` + `go.sum` in PRs; review any change.
- Tag protection on GitHub repos.
- Pin to a single GOPROXY in CI.
- Require `go mod verify` to pass.

### Pre-build screen
- Compare new `go.sum` against allowlist of known checksums for known deps.
- Alert on every new top-level dep.
- Audit transitive churn: a single `go get` may pull 10 new deps; review each.

## References
- [Go security policy](https://go.dev/security/policy)
- [Go module proxy](https://proxy.golang.org/)
- [Go checksum DB](https://sum.golang.org/)
- [govulncheck docs](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck)
- [Filippo Valsorda — Go supply-chain talks](https://words.filippo.io/)
- See also: [[go-code-auditing]], [[ci-cd-as-cloud-attack-surface]]

{% endraw %}
