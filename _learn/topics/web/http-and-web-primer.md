---
title: HTTP and web primer for pentesters
slug: http-and-web-primer
aliases: [http-primer, web-basics]
---

{% raw %}

> **TL;DR:** HTTP is a stateless request/response protocol over TCP (or QUIC for HTTP/3). To attack web apps you need a working mental model of: request anatomy, status codes, sessions/cookies, content types, same-origin, and how a browser differs from `curl`. This is the floor for everything under [[web-application-security]].

## A request, dissected

```
POST /login HTTP/1.1            ← method  path  version
Host: app.example.com           ← virtual-host routing
User-Agent: curl/8.5            ← client identity
Accept: text/html               ← what the client wants back
Cookie: session=abc123          ← state token (server-issued)
Content-Type: application/x-www-form-urlencoded
Content-Length: 27

username=alice&password=hunter2  ← body (only on POST/PUT/PATCH)
```

Each line ends with `\r\n`. The blank line separates headers from body. Get that wrong and you've discovered [[http-request-smuggling]].

## A response, dissected

```
HTTP/1.1 302 Found
Location: /dashboard
Set-Cookie: session=xyz789; HttpOnly; Secure; SameSite=Lax
Content-Length: 0

```

## Methods that matter on OSCP

| Method | Body? | Idempotent? | Common attack |
|---|---|---|---|
| GET | no | yes | reflected XSS, IDOR via query string |
| POST | yes | no | most injection bugs |
| PUT | yes | yes | write-side IDOR, file upload |
| DELETE | optional | yes | unauth deletion |
| OPTIONS | no | yes | CORS preflight inspection |
| PATCH | yes | no | mass assignment |

## Status code families
- **1xx** — informational (rare)
- **2xx** — success (200 OK, 201 Created, 204 No Content)
- **3xx** — redirect (301 permanent, 302/303/307/308 — look at `Location`)
- **4xx** — client error (401 unauthenticated, 403 forbidden, 404 not found, 429 rate-limited)
- **5xx** — server error (500 generic, 502 upstream, 503 overloaded, 504 timeout)

**401 vs 403** matters: 401 = "you didn't authenticate", 403 = "you authenticated but you're not allowed". Confusing the two will mis-route your access-control testing.

## Sessions and cookies

A cookie is just a header. The server sets it; the browser echoes it back on every subsequent request to the same origin.

```
Set-Cookie: session=abc; HttpOnly; Secure; SameSite=Lax; Domain=.example.com; Path=/; Max-Age=3600
```

Attributes worth knowing:
- `HttpOnly` — JS can't read it (mitigates XSS theft).
- `Secure` — only sent over HTTPS.
- `SameSite=Lax|Strict|None` — controls cross-site sending (mitigates [[csrf]]).
- `Domain` / `Path` — scope.

See [[cookie-prefix-and-attribute-attacks]] for what goes wrong.

## Content types you'll meet

| Type | Body shape | Pitfall |
|---|---|---|
| `application/x-www-form-urlencoded` | `a=1&b=2` | HTML form default |
| `multipart/form-data` | `boundary`-delimited parts | file upload |
| `application/json` | `{"a":1}` | needs explicit Content-Type; otherwise CSRF still applies |
| `application/xml` / `text/xml` | XML | [[xxe]] surface |
| `text/html` | HTML | XSS render target |

If a server accepts both JSON and form-encoded, that's often a CSRF gap (form-encoded doesn't require preflight, JSON does).

## Same-origin and CORS in 60 seconds
- Two URLs share an *origin* iff scheme + host + port all match.
- A browser blocks cross-origin reads by default.
- CORS is the server saying "actually, you may read me from those origins."
- The dangerous header is `Access-Control-Allow-Origin: <attacker>` combined with `Access-Control-Allow-Credentials: true`. See [[cors-acam-credential-bypass-patterns]].

## Browser vs `curl`
A browser:
- runs JavaScript and renders the response,
- follows redirects automatically,
- attaches cookies for the cookie's scope,
- sends `Origin` and `Referer`,
- enforces CSP, SOP, mixed-content.

`curl` does none of that unless you tell it to. So:
```bash
# behave more like a browser
curl -sk \
  -L                           # follow redirects
  -b cookies.txt -c cookies.txt  # cookie jar
  -A "Mozilla/5.0 ..."         # ua
  -H "Origin: https://app"     # spoof origin
  https://target/
```

## Tools you'll keep open

- **Burp Suite Community** — proxy, repeater, decoder. Repeater is where you'll live.
- **`curl` / `httpie`** — scripted repro and quick edge tests.
- **Browser devtools — Network tab** — for SPAs that fire 30 requests per click.
- **`ffuf` / `gobuster`** — directory and parameter discovery.

## Workflow for a new web target
1. Visit the site in Burp's embedded browser; let it spider passively.
2. Map auth: register, login, logout, password reset.
3. Map roles: user, admin (if you have one), unauth.
4. For every parameter you see: try injection, IDOR, mass assignment, auth bypass.
5. Repeat with Burp's site map + Repeater per interesting endpoint.

## References
- [MDN HTTP overview](https://developer.mozilla.org/en-US/docs/Web/HTTP/Overview)
- [PortSwigger Web Security Academy](https://portswigger.net/web-security)
- [RFC 9110 — HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110.html)
- See also: [[web-application-security]], [[cookie-prefix-and-attribute-attacks]], [[csrf]], [[cross-site-scripting]]

{% endraw %}
