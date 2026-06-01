---
title: HTTP Parameter Pollution (HPP)
slug: http-parameter-pollution
---

> **TL;DR:** Same parameter sent multiple times — server-side and client-side parsers disagree on which value wins. Bypass filters, alter behaviour.

## What it is
HTTP defines no single rule for what a server should do when a request contains the same parameter twice. Each framework picks: first wins, last wins, concatenate with comma, array. When two components of the request pipeline pick differently (WAF takes the first value but app takes the last; reverse proxy forwards both; backend takes both as an array), an attacker hides a malicious value behind a benign one.

## Preconditions / where it applies
- Two or more parsers on the request path — WAF, gateway, reverse proxy, app server, ORM layer
- App that reflects or routes on a single value while another layer inspects a different one
- Server-side template construction of upstream URLs (param injected into outgoing query string)

## Technique
Behaviour matrix (memorise the rough shape):

| Server | Treatment of `?a=1&a=2` |
|---|---|
| PHP `$_GET['a']` | last → `2` |
| ASP.NET | concat → `1,2` |
| Node `qs` (Express default) | array `['1','2']` |
| Java servlet `getParameter` | first → `1` |
| Java servlet `getParameterValues` | array |
| Tomcat/JBoss | varies by container |
| Ruby on Rails | last → `2` |
| Python Flask `args.get` | first → `1` |
| Go `r.URL.Query().Get` | first → `1` |

Filter bypass example. WAF (Apache-fronted, takes first value) inspects `id=1` and passes; backend (PHP) sees the last → executes `id=1' UNION SELECT…`:

```
GET /item?id=1&id=1'+UNION+SELECT+null,user(),null--+- HTTP/1.1
```

Open redirect via mirrored param:

```
GET /login?redirect_uri=https://target.com/cb&redirect_uri=https://attacker.com
```

Server-side HPP: app stitches your param into an outbound URL —

```python
upstream = f"https://api.example/lookup?user_id={user_id}&admin=false"
# user_id = "victim&admin=true"  →  ...?user_id=victim&admin=true&admin=false
```

If the upstream takes the first value, the admin override wins. Related: [[ssrf]], [[application-logic-flaws]].

## Detection and defence
- Always test endpoints with duplicated params and observe response delta
- Burp Param Miner / Intruder cluster-bomb to fuzz duplicates
- Server should reject duplicate params on sensitive endpoints (or canonicalise to first/last with explicit policy)
- WAF must parse params the same way the backend does, or normalise before inspection
- Encode params strictly when constructing outbound URLs — never string-concatenate

## References
- [PortSwigger — HTTP Parameter Pollution](https://portswigger.net/kb/issues/00500300_http-parameter-pollution) — issue overview
- [OWASP — Testing for HPP](https://owasp.org/www-project-web-security-testing-guide/v42/4-Web_Application_Security_Testing/07-Input_Validation_Testing/04-Testing_for_HTTP_Parameter_Pollution) — methodology
- [HackTricks — HPP](https://book.hacktricks.wiki/en/pentesting-web/parameter-pollution.html) — parser table
