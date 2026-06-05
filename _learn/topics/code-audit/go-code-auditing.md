---
title: Go code auditing
slug: go-code-auditing
aliases: [golang-audit, go-source-review]
---

{% raw %}

> **TL;DR:** Go's static typing and `errcheck` discipline kill whole bug classes the older languages bleed on. What's left: SSRF via `http.Get`, command injection via `exec.Command` with concat, SQLi via `fmt.Sprintf` queries, unsafe deserialization in `gob`/`encoding/asn1`/third-party packages, path traversal via `filepath.Join`, goroutine race conditions on shared state, and dangerous use of `reflect` / `unsafe`. See [[dangerous-go-sinks]] for the catalogue.

## What it is
Go's "boring" reputation makes auditors lazy — most bugs hide in the `os/exec`, `text/template`, and ORM-helper layers. The typical Go service is a `net/http` mux or chi/gorilla/echo router → handlers → sqlx/gorm/pgx → response. Concurrency adds a TOCTOU surface that single-threaded runtimes don't have.

## Preconditions / where it applies
- Source (`.go`, `go.mod`)
- Go version (generics from 1.18; key crypto fixes per release; `errors.Is` patterns)
- Framework choice — net/http, gin, echo, chi, fiber, gqlgen

## Technique
1. **Map entry points.**
   - `net/http`: `http.HandleFunc("/path", ...)`, `mux.Handle`, `http.Handler` interfaces.
   - `chi`/`gorilla`: `r.Get("/path", handler)`.
   - `gin`/`echo`/`fiber`: `r.GET/POST/...`.
   - gRPC: handlers generated from `.proto`.
   - Middleware: `func(http.Handler) http.Handler` decorators.
2. **Trace sources.** `r.URL.Query()`, `r.Form` (after `r.ParseForm`), `r.PostForm`, `r.Body` (raw), `r.Cookie`, `r.Header`, `chi.URLParam`, `mux.Vars`. JSON binding via `json.NewDecoder(r.Body).Decode(&v)` — check struct tags + unexported fields.
3. **Sink catalogue** — see [[dangerous-go-sinks]]:
```bash
rg -n 'exec\.Command\([^,]*\+' .                                  # concat in cmd
rg -n 'exec\.Command\("(sh|bash|cmd)"' .                          # shell args
rg -n 'fmt\.Sprintf\(.*SELECT|fmt\.Sprintf\(.*INSERT|fmt\.Sprintf\(.*UPDATE' .  # SQLi via fmt
rg -n 'db\.(Query|Exec|QueryRow)\(\s*fmt\.Sprintf' .              # same
rg -n 'gorm\.\(Raw\|Exec\)\(\s*fmt\.Sprintf' .                    # gorm SQLi
rg -n 'http\.Get\(|http\.Post\(|http\.NewRequest\("[A-Z]+",\s*r\.' .  # SSRF
rg -n 'text/template.*Parse|html/template.*Parse' .               # template injection if user-controlled template
rg -n 'gob\.NewDecoder|encoding/gob' .                            # gob deserialization
rg -n 'filepath\.Join\(.*r\.URL|os\.Open\(\s*r\.URL' .            # path traversal
rg -n 'unsafe\.Pointer|reflect\.NewAt' .                          # unsafe — review carefully
```
4. **Command injection.** `exec.Command("/bin/sh", "-c", "ls " + userInput)` is RCE. `exec.Command("ls", userInput)` is arg-safe but flag injection persists (`userInput = "-l /etc/passwd"`). Reject leading `-` or use `--` separator.
5. **SQL injection.** `database/sql` with `?`/`$1` placeholders is safe. `fmt.Sprintf("SELECT * FROM users WHERE name='%s'", x)` is not. `gorm.Raw(fmt.Sprintf(...))` is SQLi. `sqlx.MustExec(...)` with `Sprintf` is SQLi.
6. **SSRF.** `http.Get(userURL)` with no allowlist. Stdlib redirect-follow default is 10 hops — DNS rebinding possible on each. Wrap `http.Client.Transport` with `DialContext` that checks resolved IP against denylist (RFC1918, link-local, metadata IPs).
7. **Path traversal.** `filepath.Join(root, userPath)` does NOT prevent `..`. Use `filepath.Clean` + check that the cleaned result has `root` as prefix and no `..` after.
```go
clean := filepath.Clean(filepath.Join(root, user))
if !strings.HasPrefix(clean, root+string(os.PathSeparator)) {
    return errInvalid
}
```
8. **Template injection.** `text/template` does not auto-escape (use only for non-HTML). `html/template` escapes context-aware. Both expose `.Funcs` allowing custom functions — if a template loaded from disk is user-controlled, RCE.
9. **Deserialization.** `gob`, `encoding/asn1`, `xml.Unmarshal` with `DisallowUnknownFields=false`, third-party `msgpack` with type discrimination, `protobuf` `Any` types — each is a gadget surface. `json.Unmarshal` is generally safe but `interface{}` targets lose type discipline.
10. **Race conditions.** Run `go test -race`. Shared maps without `sync.Mutex`, `sync.Map`, or channels. `time.Now()` + uniqueness check is a classic TOCTOU. Goroutine leaks from missing `select{}` on cancelable contexts.
11. **Crypto and tokens.** `math/rand` for tokens — flag. `crypto/rand` only for secrets. `crypto/subtle.ConstantTimeCompare` for HMAC checks, not `==`. `golang.org/x/crypto/bcrypt` cost ≥10. JWT libs vary — `github.com/golang-jwt/jwt/v5` requires explicit method.
12. **Mass assignment via JSON.** `json.NewDecoder(r.Body).Decode(&user)` populates every exported field of `User`. Use a DTO struct for input and copy to model. Set `Decoder.DisallowUnknownFields()` for stricter rejection.
13. **Race in middleware.** Shared `*http.Request` across goroutines — `r.Context()` cancels on response write; reads after that return errors silently.

## Detection and defence
- `staticcheck`, `gosec`, `govulncheck` in CI — first two are AST/SSA based, last is dep-CVE.
- `gopls` and `go vet` for obvious bugs; `-race` for data races.
- Semgrep `go.lang.security` ruleset.
- Force prepared queries via a Rubocop-like ban on `fmt.Sprintf` in query paths.
- Use `errors.Is`/`errors.As` for unwrapping; raw `err == sql.ErrNoRows` breaks on wrapping.

## References
- [Go security best practices](https://go.dev/doc/security/best-practices)
- [gosec](https://github.com/securego/gosec) — primary SAST
- [govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck) — CVE deps
- [HackTricks — Go](https://book.hacktricks.wiki/) (general)
- See also: [[dangerous-go-sinks]]

{% endraw %}
