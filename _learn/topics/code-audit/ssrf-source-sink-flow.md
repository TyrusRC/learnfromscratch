---
title: SSRF Source-Sink Flow Analysis
slug: ssrf-source-sink-flow
---

> **TL;DR:** SSRF audits trace any user-controlled URL (sources: `req.body.url`, `req.query.target`, webhook config, OAuth `redirect_uri`) into HTTP clients (sinks: `http.get`, `requests.get`, `axios`, `curl`, `fetch`), then check whether DNS rebinding or redirect chains can reach internal metadata services.

## What it is
Server-side request forgery happens when a backend issues an HTTP (or gopher/file) request to a destination an attacker controls. Modern SSRF is rarely about a single sink — auditors must track flows across libraries, redirect-followers, and DNS resolvers. Even with a hostname allowlist, time-of-check/time-of-use DNS rebinding can flip a benign FQDN to `169.254.169.254` between resolution and connect, and HTTP 30x chains can land on link-local IPs the client never validated.

## Preconditions / where it applies
- Any service that fetches user URLs: link previews, webhooks, PDF/HTML renderers, "import from URL" features, SAML/OIDC metadata loaders, image proxies
- Cloud environments with IMDSv1 (`http://169.254.169.254/latest/meta-data/`), GCP metadata (`metadata.google.internal`), or Kubernetes API server reachable from pods
- Languages: Node (`axios`, `node-fetch`), Python (`requests`, `urllib`, `httpx`), Go (`net/http`), Ruby (`Net::HTTP`, `open-uri`), Java (`URL.openConnection`)

## Technique
```javascript
// Source: req.query.url. Sink: axios.get. No allowlist, follows redirects.
app.get('/preview', async (req, res) => {
  const r = await axios.get(req.query.url, { maxRedirects: 5 });
  res.send(r.data);
});
// Attacker hosts evil.com → 302 → http://169.254.169.254/latest/meta-data/iam/

// DNS rebinding — TTL=0, first answer 1.2.3.4, second 169.254.169.254
// dig @ns.attacker rebind.evil → 1.2.3.4   (passes allowlist check)
// dig @ns.attacker rebind.evil → 169.254.169.254 (used by http.get)

// Python equivalent
import requests
requests.get(request.args["url"], allow_redirects=True, timeout=5)
```

## Detection and defence
- Semgrep: `javascript.express.security.audit.express-open-redirect`, `python.requests.security.ssrf`, `go.lang.security.audit.net.ssrf`
- CodeQL: `js/server-side-request-forgery`, `py/full-ssrf`, `go/ssrf`
- Defences: parse URL, resolve hostname yourself, reject private/link-local/loopback ranges (`10/8`, `172.16/12`, `192.168/16`, `127/8`, `169.254/16`, IPv6 `fc00::/7`, `fe80::/10`)
- Pin the resolved IP across redirect + connect (custom `DialContext` in Go, `requests` session with custom adapter, `undici` `connect` hook in Node)
- Disable HTTP redirects or recheck the target on every hop; use `?` token IMDSv2 on AWS; isolate fetcher in a network namespace with egress filtering

## References
- [PortSwigger SSRF cheat sheet](https://portswigger.net/web-security/ssrf) — payload patterns
- [AWS IMDSv2 documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html) — token-protected metadata
- [PayloadsAllTheThings SSRF](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/Server%20Side%20Request%20Forgery) — bypass corpus

See also: [[source-sink-flow-analysis]], [[dangerous-go-sinks]], [[nodejs-prototype-pollution-audit]].
