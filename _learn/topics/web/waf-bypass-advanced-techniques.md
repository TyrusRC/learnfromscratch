---
title: WAF bypass — advanced techniques
slug: waf-bypass-advanced-techniques
aliases: [advanced-waf-bypass, cloud-waf-evasion]
---

{% raw %}

> **TL;DR:** Modern WAFs (Cloudflare, AWS WAF, Akamai, Imperva, Wallarm, Fastly) use ruleset + ML scoring + reputation + bot management. Bypasses cluster into: parser differential between WAF and origin, payload encoding the WAF doesn't normalise, request smuggling at the WAF/origin boundary, origin direct-access, traffic-shape evasion, and exploiting WAF's own vulnerabilities. Complement to the basic [[waf-bypass]] note.

## What it is
A WAF inspects HTTP requests against rules + signatures + ML scoring. Modern deployments are reverse-proxies at the network edge. The bypass goal is delivering a payload that fires the bug at origin while the WAF either:
- Doesn't see it (different parser).
- Sees it as benign (encoded form).
- Decides it's low-risk (ML below threshold).
- Doesn't run (origin reached directly).

## Bypass categories

### 1. Parser differential
WAF parses HTTP, finds nothing bad, forwards. Origin parses HTTP differently, sees the payload. Example surfaces:
- HTTP/1.1 vs HTTP/2 — WAF on H1 sees `Transfer-Encoding`; origin on H2 ignores it. See [[http2-h2-downgrade-desync-v3]].
- Chunked vs Content-Length disagreements → request smuggling → payload behind smuggled request.
- Multi-value headers (`Host: a, b`) interpreted differently.
- Unicode normalisation differs (see [[unicode-normalization-bypasses]]).

### 2. Encoding the WAF doesn't reverse
- URL-encoding (`%73%65%6C%65%63%74`) — most WAFs decode.
- Double-encoding (`%2573%2565...`) — varies; Apache mod_rewrite decodes twice, AWS WAF typically once.
- HTML entity (`&#x73;elect`) — for HTML-context payloads, WAF may not decode but template engine does.
- Unicode escape (`select`) — JS / JSON contexts.
- Base64 in JWT / cookies — WAF doesn't decode payload contents.
- Mixed-case (`SeLeCt`) — basic WAFs miss; modern ones don't.
- Comments in SQL (`SE/**/LECT`) — many WAFs handle; some still miss certain comment styles.
- Tab / newline / form feed in keywords (`SE\tLECT`) — varies.
- Concatenation (`SE'+'LECT`) — DB-specific evaluation.

### 3. Request smuggling
- Frontend (WAF) and backend (origin) parse the request boundary differently.
- WAF sees request A only; backend sees A + B smuggled.
- Payload in B bypasses WAF entirely.
- See [[http-request-smuggling]], [[request-tunnelling-desync]].

### 4. Origin direct-access
- WAF protects `www.example.com`; origin server at `origin.example.com` or specific IP.
- If origin IP reachable directly (no `X-Forwarded-From-WAF` enforcement), bypass entirely.
- Discovery: historical DNS, certificate transparency, SHODAN, Censys.
- Fix: WAF-signed header check (shared secret in `X-WAF-Token`), IP allowlist origin → CDN only, mTLS.

### 5. Traffic shape evasion
- Bot management uses TLS fingerprint (JA3/JA4), HTTP/2 fingerprint (Akamai Bot Manager).
- Use a real browser (Selenium / Puppeteer) instead of curl → different fingerprint → bypass bot WAF rules.
- Rotate User-Agent; randomise headers; introduce realistic jitter.

### 6. Rate-limit defeats
- IP-per-request: Tor / proxies / residential proxies.
- Account-per-request: account creation throttled (CAPTCHA bypass — see [[captcha-bypass]]).
- Burst vs sustained: very fast within window, then sleep.

### 7. ML-score evasion
- WAFs (Cloudflare, Wallarm) score requests on multiple features; threshold blocks high scorers.
- Payload split across multiple parameters / requests → individually below threshold.
- Padding with benign tokens reduces relative malicious-token density.
- Adversarial examples: known to confuse some ML models (research; less practical).

### 8. WAF's own vulnerabilities
- Each WAF has CVE history.
- Cloudflare ScrapeShield disclosure bypass (CVE-2024-XXXX), AWS WAF rule eval bugs, Akamai WAF chunked encoding bugs.
- Worth checking current advisories for the specific WAF in scope.

### 9. Header injection / CRLF
- CRLF in user-supplied path injects a second request line; WAF inspected only first.
- See [[crlf-injection]].

### 10. Long parameter / overflow
- Some WAFs cap inspection at N bytes of body / header. Payload > N → unscanned.
- AWS WAF default body inspection 8KB (now configurable to 64KB on WCU plan).
- Pad pre-payload with junk, place attack payload past the cap.

### 11. JSON / XML / multipart subtleties
- WAF rules often regex against raw body. JSON with whitespace tricks (`{"q":<long whitespace>"...SQLi..."}`) confuses regex anchoring.
- multipart: parameter declared multiple times; WAF takes first, origin takes last (or vice versa).
- XML CDATA sections that hide payload from regex but XML parser sees.

### 12. Path normalisation differential
- `/api/../admin` — WAF sees `/api/...` (denied for admin path rules), origin normalises to `/admin`.
- `//admin` — double slash.
- `/admin;param=x` — semicolon path parameter (older Tomcat parsed).
- `/admin/` vs `/admin` — trailing slash; rules sometimes anchor on one.

### 13. Method override
- `X-HTTP-Method-Override: DELETE` honoured by some frameworks but ignored by WAF rules tagged to method.
- POST with override → bypasses DELETE rules.

### 14. WebSocket / SSE upgrade
- WAFs often relax inspection on upgraded WebSocket connections.
- Initial handshake passes; subsequent messages may not be inspected.

## Discovery workflow

### Identify the WAF
- Server / Set-Cookie headers (`cf-ray` for Cloudflare, `x-akamai-edgescape` for Akamai).
- Tools: `wafw00f`, `whatwaf`.
- Behaviour: 403/406/blocked-by-WAF page.

### Identify the origin
- `dig` historical DNS via crt.sh, SecurityTrails.
- Censys search by JA3 fingerprint of origin if known.
- Misconfigured `mail.example.com` MX often hosts on same server.
- `Server:` header difference between WAF response and origin direct response.

### Test parser differentials
- Burp Smuggler (jameskettle's HTTP Request Smuggler).
- Manually craft `Transfer-Encoding: chunked` + `Content-Length` mismatches.

### Test encoding
- Burp Intruder with encoding payload sets.
- Compare baseline (blocked) vs encoded variants.

### Test rate / shape
- Distributed traffic from residential proxies.
- Browser-driven requests.

## Defence (the audit angle)
- WAF + origin must agree on parsing rules.
- Origin IP not directly reachable; mTLS or IP allowlist.
- WAF token in headers verified by origin.
- Request smuggling defence at protocol level (HTTP/2 end-to-end, reject ambiguous H1).
- Rate limit at app level too (defence in depth).
- Audit WAF rule coverage: every protected endpoint, every method.

## References
- [Cloudflare WAF docs](https://developers.cloudflare.com/waf/)
- [AWS WAF docs](https://docs.aws.amazon.com/waf/)
- [PortSwigger — WAF bypass research](https://portswigger.net/research)
- [Wallarm Lab — WAF testing](https://lab.wallarm.com/)
- [Akamai security research](https://www.akamai.com/security-research)
- [OWASP WAF testing methodology](https://owasp.org/www-community/Web_Application_Firewall)
- See also: [[waf-bypass]], [[http-request-smuggling]], [[unicode-normalization-bypasses]], [[http2-h2-downgrade-desync-v3]]

{% endraw %}
