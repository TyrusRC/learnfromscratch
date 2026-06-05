---
title: Express / NestJS audit patterns
slug: express-nestjs-audit-patterns
aliases: [express-audit, nestjs-audit, node-framework-audit]
---

{% raw %}

> **TL;DR:** Express's minimalism means every security check is opt-in — audit middleware order, missing helmet/csurf, route-level auth gaps, and prototype pollution surfaces (`body-parser` `extended:true`, `qs`). NestJS adds DI + decorators that look secure but require guard/pipe wiring to actually be; verify `@UseGuards`/`@UsePipes` on every controller method, not just the class.

## Express bug patterns

### 1. Middleware ordering
- Auth middleware after a route registers = auth bypass for that route.
- Logging or error-handler before auth means logs see secrets.
- `app.use(express.static('public'))` before auth = public files reachable; combined with predictable upload paths → IDOR.

### 2. Route-level auth gaps
- `app.get('/admin/:id', adminOnly, handler)` — every admin route must include the middleware. Forgetting one = unauthenticated admin endpoint.
- Wildcard routes (`app.get('/api/*', ...)`) at the bottom of the file catch unintended paths.

### 3. Prototype pollution funnel
- `body-parser` `extended:true` (default!) uses `qs` library — parses `?a[__proto__][admin]=1` into `{a: {__proto__: {admin: 1}}}`. If downstream merges that into another object → [[prototype-pollution]].
- `app.use(express.json())` with `Object.assign(target, req.body)` recursive variants — same risk.
- Audit any `_.merge`, `_.set`, custom recursive copy that touches `req.body`.

### 4. CSRF / cookies
- `csurf` deprecated in 2022 — replacement options: SameSite=strict + double-submit pattern, or `csrf-csrf` npm package.
- `cookie-parser` with no `secret` arg = unsigned cookies (tamperable).
- `express-session` with default `MemoryStore` in prod = process-local + memory leak; clusters break.

### 5. SSRF
- `app.post('/fetch', (req, res) => fetch(req.body.url))` — classic SSRF entry.
- `request`/`axios`/`node-fetch` with no allowlist or IP filter.
- Internal `IMDS` / metadata pivot via redirect-follow (default true).

### 6. Path traversal
- `app.get('/file/:name', (req, res) => res.sendFile(path.join(root, req.params.name)))` — `..` in `name` traverses.
- `res.sendFile` with `{root: '/var/www'}` arg AND a `dotfiles:'deny'` is correct; absent → traversal.

### 7. SQLi via raw queries
- `db.query('SELECT * FROM users WHERE id=' + req.params.id)` — raw concat.
- `mysql2` `connection.query(sql, [params])` parameterised when `?` placeholders used.
- `pg` `client.query('... $1', [val])` parameterised; `client.query(\`... ${val}\`)` is SQLi.

### 8. Template engines
- `app.set('view engine', 'ejs')` + `res.render(req.params.template, ...)` — template-name injection → render attacker-controlled file → SSTI/LFI.
- Handlebars `compile(userInput)` = RCE-equivalent.

### 9. NoSQL injection
- `User.find({name: req.body.name})` safe.
- `User.find(req.body)` — attacker sends `{name: {$ne: null}}` to match all rows. See [[nosql-injection]].

### 10. JWT
- `jsonwebtoken.verify(token, secret)` with no `algorithms` option = allows `none`. Always specify `algorithms: ['HS256']`.
- `jwt.decode` returns payload without verifying signature; common dev mistake.

## NestJS bug patterns

### 1. Guards per-method vs per-class
- `@UseGuards(JwtAuthGuard)` on class is fine for full coverage; per-method only protects that method. Mixed → easy to miss.
- `@Public()` decorator (custom) often used to opt-out; audit every `@Public()` for whether the route really should be unauth.

### 2. ValidationPipe + class-validator
- Global `app.useGlobalPipes(new ValidationPipe({whitelist: true, forbidNonWhitelisted: true}))` blocks mass-assignment via DTO whitelisting. Without `whitelist: true`, extra fields pass through → mass-assignment via `Object.assign(entity, dto)`.
- DTO must use `class-validator` decorators; plain types are unvalidated.

### 3. Interceptors vs guards order
- Guards run before interceptors. Auth must be a guard, not an interceptor.
- `@UseInterceptors(LoggingInterceptor)` running before `@UseGuards` = logging fires on unauth requests too (sometimes desired, sometimes a secret leak).

### 4. TypeORM/Prisma raw query
- `userRepo.query(`SELECT * FROM users WHERE name='${name}'`)` → SQLi.
- TypeORM `QueryBuilder.where("name = '" + name + "'")` → SQLi.
- Prisma `$queryRaw\`... ${val}\`` parameterises (Prisma tagged template); `$queryRawUnsafe(query, ...args)` does not unless you pass args.

### 5. GraphQL resolvers (NestJS + Apollo)
- `@ResolveField` without `@UseGuards` allows nested data leak even if parent query is gated.
- N+1 query through resolvers → DoS; `@nestjs/graphql` has `DataLoader` integration — audit usage.
- Query depth/complexity not capped → DoS.

### 6. WebSocket / Microservice transports
- `@WebSocketGateway` handlers — auth typically done in `handleConnection`, but per-message guards are opt-in (`@UseGuards` on `@SubscribeMessage`).
- Microservice `@MessagePattern` handlers — same trust assumption that may not hold cross-network.

### 7. Common CVEs
- `@nestjs/swagger` <recent — XSS via spec generation.
- `cookie-signature` parsing CVE chain.
- `mongoose` query selector injection CVEs (pre-7).

## Grep starter
```bash
# Express
rg -n 'app\.use\(express\.static' src
rg -n 'app\.get|app\.post|app\.use' -A1 src | grep -v -E 'auth|require'  # routes lacking auth
rg -n 'extended:\s*true' src
rg -n 'jwt\.verify\([^,]+,[^,]+\)\s*[,)]' src   # missing algorithms
# NestJS
rg -n '@UseGuards\(' src/**/*.ts | wc -l
rg -n '@Controller' src/**/*.ts | wc -l   # compare counts
rg -n '@Public\(\)' src
rg -n '\$queryRawUnsafe|\.query\(.*\$' src
rg -n '@WebSocketGateway|@MessagePattern' src
```

## Tooling
- `eslint-plugin-security` + `eslint-plugin-no-unsanitized`.
- `npm audit` / `pnpm audit` / Snyk / Socket.
- Semgrep `javascript.express.security`, `javascript.nestjs.security`.
- NestJS: `@nestjs/throttler` for rate-limiting, must be applied per controller.

## References
- [Express security best practices](https://expressjs.com/en/advanced/best-practice-security.html)
- [NestJS security](https://docs.nestjs.com/security/authentication)
- [Snyk Node CVE writeups](https://snyk.io/vuln/?type=npm)
- See also: [[nodejs-code-auditing]], [[dangerous-nodejs-sinks]], [[nodejs-prototype-pollution-audit]]

{% endraw %}
