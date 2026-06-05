---
title: Node.js code auditing
slug: nodejs-code-auditing
aliases: [node-code-review, javascript-audit]
---

{% raw %}

> **TL;DR:** Node audits hit a different sink set than PHP/Java: prototype pollution, command injection via `child_process`, server-side template engines (EJS/Pug/Handlebars), unsafe `eval`/`vm`, deserialization in `serialize-javascript`/`node-serialize`, and the `__proto__`/`constructor.prototype` lattice. Single-threaded event loop means race-conditions cluster around `await` boundaries.

## What it is
A modern Node app is express/Fastify/NestJS + middleware + ORM (Prisma / TypeORM / Mongoose) + a frontend bundler. The audit splits into: HTTP entry → middleware chain → handler → ORM → response. JavaScript's weak type system means prototype pollution often crosses subsystem boundaries silently.

## Preconditions / where it applies
- Source (preferred) or `node_modules/` tree
- `package.json` — runtime version, framework, key deps
- Build tooling — TypeScript adds compile-time but not runtime safety
- Knowledge of the engine (V8) and event-loop model

## Technique
1. **Map entry points.**
   - Express: `app.get/post/put/delete`, `app.use`, `router.*`.
   - Fastify: `fastify.route`, `fastify.get/post`.
   - NestJS: `@Controller`, `@Get/@Post/...`, `@Body/@Query/@Param`.
   - Native: `http.createServer((req,res)=>...)`.
   - WS: `socket.io` `on('message')`, `ws` `connection`.
2. **Trace sources.** `req.body`, `req.query`, `req.params`, `req.cookies`, `req.headers`. NestJS DTOs via `class-validator` (check for missing decorators). GraphQL resolver args. Watch for `req.body` going to `Object.assign({}, req.body)` — that's a [[prototype-pollution]] funnel.
3. **Sink catalogue** — see [[dangerous-nodejs-sinks]]:
```bash
rg -n 'child_process\.(exec|execSync|spawn|spawnSync)\(' .
rg -n '\beval\(|\bnew Function\(|\bvm\.(runIn|createScript)' .
rg -n 'require\(\s*[^\'"]*\$' .             # dynamic require
rg -n 'fs\.(readFile|writeFile|createReadStream|createWriteStream)\(\s*req\.' .
rg -n 'res\.sendFile\(\s*req\.' .            # path traversal
rg -n 'ejs\.render|pug\.render|handlebars\.compile' .  # SSTI vectors
rg -n 'unserialize\(|node-serialize|serialize-javascript' .
rg -n 'JSON\.parse\(.*req\.' .              # not a sink alone, but with reviver
rg -n 'mongoose\..*\.find\(\s*req\.|\.findOne\(\s*req\.' .  # NoSQL inj
```
4. **Prototype pollution audit.** Any `merge`/`extend`/`assign` recursive on user JSON that doesn't reject `__proto__`/`constructor`/`prototype` keys. lodash `<4.17.21`, jQuery `<3.4`, hoek, just-extend. See [[prototype-pollution]] and [[nodejs-prototype-pollution-audit]].
5. **Command injection.** `child_process.exec(`ls ${userInput}`)` is RCE. `spawn('ls', [userInput])` is safe arg-wise but still risky if `userInput.startsWith('-')` (flag injection). Audit any concat with `&&`, `||`, `;`, `$()`, backticks.
6. **Path traversal.** `path.join(root, req.params.file)` does not strip `..`. Use `path.resolve` + `startsWith` check or `path.normalize` + check.
7. **SSRF.** `fetch(req.body.url)`, `axios.get(req.body.url)` with no allowlist. Common because internal services use IP-based URLs. Pair with [[ssrf]].
8. **NoSQL injection (Mongo).** `User.find({ name: req.body.name })` is safe; `User.find(req.body)` lets `{name: {$ne: null}}` match all. Audit any spread of user input into Mongoose queries.
9. **Server-side template injection.** EJS `<%- include(userInput) %>`, Handlebars `compile(userInput)`, Pug `pug.render(userInput)`. All RCE-equivalent. See [[ssti]].
10. **Deserialization.** `node-serialize.unserialize(str)` accepts `_$$ND_FUNC$$_` IIFE = RCE. `serialize-javascript` is safer but `{deserialize: true}` re-evaluates functions.
11. **JWT / auth.** Check `jsonwebtoken` usage: `jwt.verify(token, secret, { algorithms: ['HS256'] })` — without explicit algorithms list, attacker can downgrade to `none`. See [[jwt]].
12. **Race conditions via async.** Two parallel `await`s on a stateful service (e.g. counter, balance) without locking → TOCTOU. Single-threaded ≠ serial within a request.

## Detection and defence
- `eslint-plugin-security` + `eslint-plugin-no-unsanitized` in CI.
- Semgrep `javascript.express.security`, `nodejs.security`.
- For prototype pollution: use `Object.create(null)` for maps, freeze prototypes (`Object.freeze(Object.prototype)`), or migrate to `Map`.
- Replace `exec` with `execFile` and explicit arg arrays.
- `helmet` for response headers; `csurf` for CSRF (deprecated, prefer SameSite cookies).
- Snyk/`npm audit`/Socket for dep CVEs.

## References
- [Node.js security best practices](https://nodejs.org/en/learn/getting-started/security-best-practices)
- [OWASP Cheat Sheet — Node.js](https://cheatsheetseries.owasp.org/cheatsheets/Nodejs_Security_Cheat_Sheet.html)
- [Snyk research blog](https://snyk.io/blog/) — Node CVE writeups
- [LiveOverflow / SecuriTeam — Node deserialization](https://github.com/ajinabraham/node-serialize-rce-poc)
- See also: [[dangerous-nodejs-sinks]], [[nodejs-prototype-pollution-audit]], [[express-nestjs-audit-patterns]]

{% endraw %}
