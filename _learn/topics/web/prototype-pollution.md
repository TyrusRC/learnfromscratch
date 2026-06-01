---
title: Prototype pollution
slug: prototype-pollution
---

> **TL;DR:** Setting Object.prototype.X via user-controlled keys; downstream code inherits the polluted property.

## What it is
In JavaScript every object inherits from `Object.prototype`. A recursive merge or `obj[k1][k2]=v` that lets `k1` be the string `__proto__` (or `constructor.prototype`) writes onto the shared prototype. Every plain object that later checks `obj.foo` and finds it absent walks up the prototype chain, sees the polluted value, and treats it as its own. This converts what looks like a harmless deep-merge of user JSON into RCE, auth bypass, or DoS depending on what downstream code does with the property.

## Preconditions / where it applies
- Server-side: Node app uses a vulnerable merge / clone / `path-set` (`lodash.merge` <4.17.21, `set-value`, `unflatten`, raw recursive helpers)
- Client-side: bundle pulls in a library that does the same on URL params or hash data
- Sink that reads a property without `hasOwnProperty` and uses it (template options, sandbox config, child_process args)

## Technique
Probe via JSON / query string. URL form (DOM PP):

```
https://target/#__proto__[polluted]=yes
?utm_source=foo&__proto__[xxx]=1
?constructor[prototype][polluted]=yes
```

Then in browser console: `Object.prototype.polluted` returns `"yes"` → confirmed.

Server-side JSON body:

```http
POST /api/profile HTTP/1.1
Content-Type: application/json

{"name":"x","__proto__":{"isAdmin":true}}
```

If the handler does `Object.assign({}, req.body)` you're fine; if it does `_.merge(profile, req.body)` with an old lodash, `Object.prototype.isAdmin = true`. Subsequent `if (user.isAdmin)` checks pass for every user.

Gadget-chain RCE. Express's `pug` / `handlebars` look at options like `outputFunctionName`, child_process spawn looks at `shell` / `env`. Pollute the right property and a later legitimate call becomes RCE:

```javascript
// after polluting Object.prototype.shell = '/bin/sh -c "id > /tmp/x" #'
require('child_process').spawn('ls'); // shell option inherited → executes injected command
```

Client-side gadgets: bundle config like `window.appConfig` that lazily fills defaults from prototype; sinks like Vue/jQuery options leading to [[dom-xss]]. PortSwigger's DOM Invader automates probe + gadget chain.

## Detection and defence
- `Object.freeze(Object.prototype)` early in process (server) — prevents writes
- Use `Object.create(null)` for option-bag patterns — no prototype to pollute
- Validate JSON: reject keys `__proto__`, `prototype`, `constructor`
- Update merge libs (lodash ≥ 4.17.21, jQuery ≥ 3.4.0)
- Static analysis: semgrep "prototype-pollution" rules
- In Node 22+, `--disable-proto=delete` removes `__proto__` accessor

## References
- [PortSwigger — Prototype pollution](https://portswigger.net/web-security/prototype-pollution) — labs and gadgets
- [Snyk — Prototype pollution research](https://snyk.io/learn/prototype-pollution/) — library tracker
- [HackTricks — NodeJS prototype pollution](https://book.hacktricks.wiki/en/pentesting-web/deserialization/nodejs-proto-prototype-pollution.html) — gadget catalogue
