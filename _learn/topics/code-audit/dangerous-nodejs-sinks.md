---
title: Dangerous Node.js sinks
slug: dangerous-nodejs-sinks
aliases: [node-sinks, javascript-sinks]
---

{% raw %}

> **TL;DR:** Catalogue of high-impact Node sinks for grep-driven [[source-sink-flow-analysis]]. Group by impact tier; cross-link the methodology in [[nodejs-code-auditing]].

## Tier 1 — RCE / arbitrary code execution
| Sink | Pattern | Notes |
|------|---------|-------|
| `eval` | `eval(x)` | Strict mode does not save you. |
| `new Function` | `new Function('a','b','return ' + x)` | Same surface as eval. |
| `vm.runInThisContext` / `runInNewContext` / `runInContext` | direct code exec in a V8 context | Sandbox is NOT a security boundary. |
| `child_process.exec` / `execSync` | `exec(`cmd ${x}`)` | RCE via shell metachars. |
| `child_process.spawn` / `spawnSync` shell:true | `spawn(x, [], {shell:true})` | Same as exec. |
| `child_process.execFile` with user-controlled first arg | `execFile(x)` | If `x` is a script path the attacker controls. |
| Dynamic `require(x)` | `require(x)` with attacker-controlled x | Local file → load + exec; npm registry → supply chain. |
| `node-serialize.unserialize` | accepts `_$$ND_FUNC$$_` IIFE | RCE. |
| `serialize-javascript` with `{deserialize:true}` | functions re-evaluate | RCE. |
| Template engines compile-from-string | `handlebars.compile(x)`, `pug.compile(x)`, `ejs.render(x)`, `mustache.render(x)` | SSTI → RCE. |
| `vm2` < 3.9.20 escape | several CVEs | Project is officially abandoned; consider `isolated-vm`. |

## Tier 2 — file / path
| Sink | Pattern | Notes |
|------|---------|-------|
| `fs.readFile` / `createReadStream` with user path | `fs.readFile(x)` | Arbitrary file read; check for null-byte and traversal. |
| `fs.writeFile` / `createWriteStream` | `fs.writeFile(x, body)` | Write where you can; symlink races. |
| `res.sendFile(x)` (Express) | `sendFile(req.params.f)` | Path traversal unless `root` set + `dotfiles:deny`. |
| `res.download(x)` | same | same. |
| `path.join(root, x)` | NOT a sanitiser by itself | `..` segments persist. |
| `fs-extra.copy(a, b)` | symlink race during walk | Older versions vulnerable. |

## Tier 3 — injection / SSRF
| Sink | Pattern | Notes |
|------|---------|-------|
| `fetch(x)` / `axios.get(x)` / `request(x)` / `node-fetch(x)` | SSRF | Block link-local + RFC1918 in resolver. |
| SQL raw query | `pool.query(`SELECT * FROM users WHERE id=${id}`)` | SQLi. |
| Sequelize `sequelize.query(`... ${x}`)` | same | Use `:replacements`. |
| Knex `.raw(x)` | same | Use `?` placeholders. |
| Mongoose `.find(x)` / `.findOne(x)` where x is a user object | NoSQL injection | `{ $ne: null }`, `{ $gt: '' }`. |
| `redis.eval(x)` | Lua eval on Redis | Use static scripts. |
| LDAP client `search({filter: x})` | LDAP injection | Encode filter chars. |

## Tier 4 — prototype pollution sources
| Pattern | Notes |
|---------|-------|
| Recursive merge of `req.body` into a base object | Sets `__proto__.x = ...` |
| `lodash.merge`/`mergeWith`/`set` < 4.17.21 | CVE-2019-10744. |
| jQuery `$.extend(true, ...)` < 3.4 | Same. |
| `hoek.applyToDefaults` < 4.2.1 | Same. |
| `Object.assign(target, req.body)` | Only top-level keys; `Object.assign({}, ...nested)` recursive merges leak. |
| Custom recursive merge missing `__proto__`/`constructor`/`prototype` denylist | The reference bug. |

See [[prototype-pollution]] for the impact-chain side.

## Tier 5 — auth / crypto / tokens
| Pattern | Notes |
|---------|-------|
| `crypto.createHash('md5')` for passwords | Replace with `argon2`/`bcrypt`/`scrypt`. |
| `Math.random()` for tokens / IDs | Not CSPRNG. Use `crypto.randomBytes`. |
| `jwt.verify(t, secret)` with no `algorithms` option | Algorithm confusion → none. |
| `jwt.decode` used as verify | Returns payload without checking signature. |
| `===` on secrets | Timing leak. Use `crypto.timingSafeEqual`. |
| `cookie-session` without `signed:true` | Tamperable session. |

## Tier 6 — misc patterns that bite
| Pattern | Notes |
|---------|-------|
| `JSON.parse(x, reviver)` where reviver mutates `__proto__` | Pollution. |
| `dotenv.parse(req.body)` | env-injection. |
| `child_process.exec` with arg starting `-` | Flag injection (`-o`, `--config`). |
| YAML `js-yaml.load` (deprecated alias of `loadAll`) | Code exec on `!!js/function`. Use `yaml.safeLoad`. |
| Express trust-proxy not configured behind proxy | `req.ip` is attacker-supplied. |
| Express `body-parser` `urlencoded` with `extended:true` | qs library quirks — array/object injection. |

## Grep / Semgrep starter pack
```bash
rg -n 'eval\(|new Function\(|vm\.run' .
rg -n 'child_process\.(exec|spawn|execSync|spawnSync)\(' .
rg -n 'require\(\s*[^"\x27`]' .
rg -n '(handlebars|ejs|pug|mustache)\.(compile|render)\(' .
rg -n '\.merge\(|\.extend\(true' .
rg -n 'fs\.(readFile|writeFile)\(' .
rg -n 'jwt\.verify\([^,]+,[^,]+\)\s*$' .
```

## References
- [Node.js security WG](https://github.com/nodejs/security-wg)
- [eslint-plugin-security rules](https://github.com/eslint-community/eslint-plugin-security#rules)
- [HackTricks — NodeJS](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/nodejs-express.html)
- See also: [[nodejs-code-auditing]], [[nodejs-prototype-pollution-audit]]

{% endraw %}
