---
title: Hasura audit patterns
slug: hasura-audit-patterns
aliases: [hasura-security-audit, hasura-permissions]
---

{% raw %}

> **TL;DR:** Hasura generates GraphQL from PostgreSQL/MS-SQL/BigQuery schemas with a declarative per-role permission model. Audit centres on permission rules (row + column + insert/update/delete/select preset bypasses), the admin secret, JWT/webhook auth modes, REST endpoints layered on top, and Actions/Events/Remote Schemas. The "anonymous" role default is the single highest-risk knob.

## What it is
Hasura is a metadata-driven GraphQL engine. Tables → types; configured permissions → resolvers. Role-based:
- Each role gets a row-filter (in JSONLogic-ish form), a column allowlist, and a check (for inserts/updates).
- `admin` bypasses all permissions; gated by the `HASURA_GRAPHQL_ADMIN_SECRET` header.
- Auth modes: JWT (verifies & extracts claims from token), webhook (server resolves claims), unauthenticated (defaults to `anonymous` role if configured).

## Bug patterns

### 1. `anonymous` role permissions too wide
- Default install: no anonymous role. Adding one for "public read" is common.
- Devs often grant `SELECT` on many tables to `anonymous`. Audit: which tables are reachable unauth, and is that intended? Row-level filter set?
- Combined with column-allowlist gap → reads sensitive fields (email, phone, role).

### 2. Row filter logic errors
Row filter is a JSON predicate like `{"_or": [{"user_id": {"_eq": "X-Hasura-User-Id"}}, {"is_public": {"_eq": true}}]}`.
- Common bug: missing predicate (`{}`) — matches all rows.
- Common bug: `_or` instead of `_and` — broadens access when meant to narrow.
- Common bug: missing `_eq` operator → defaults to no-op match.
- Test: pretend to be a low-priv user; can you read rows that aren't yours? Run as `anonymous`; what's reachable?

### 3. Column allowlist permissive
- Select permission with `Toggle All` columns checked → every column readable.
- Sensitive columns (password_hash, mfa_secret, internal_notes) should never be in any non-admin role's column list.

### 4. Insert/Update presets bypass
- Presets force a column value: `{"user_id": "X-Hasura-User-Id"}` — server sets it from session.
- Bug: preset on `user_id` but check (validation) on the row also allows user-supplied `user_id`. Attacker sends `user_id` in input; preset overwrites or check passes — inconsistent behaviour.
- Audit: insert column allowlist should EXCLUDE `user_id` if it's preset.

### 5. Admin secret leak
- `HASURA_GRAPHQL_ADMIN_SECRET` is the master key. If leaked (env file in repo, CI logs, console misconfig) → full bypass.
- Hasura Console (dev UI) requires admin secret; sometimes deployed to prod accessible without IP allowlist.
- Audit: production admin secret rotation; console access control.

### 6. JWT mode misconfig
- `HASURA_GRAPHQL_JWT_SECRET` = `{"type":"HS256","key":"..."}` or `{"jwk_url":"..."}` for asymmetric.
- Misconfig: weak key, wrong type (RS256 vs HS256 confusion), missing claims namespace (`https://hasura.io/jwt/claims`).
- `x-hasura-default-role` and `x-hasura-allowed-roles` must be in claims; if not, role defaults to anonymous.

### 7. Webhook mode auth bypass
- Each request, Hasura calls a webhook with the user's auth headers; webhook returns claims.
- If webhook itself has weak auth (no API key, no IP restriction), attacker can hit it directly to test.
- If webhook returns admin role on certain inputs (bug), Hasura grants admin.

### 8. Remote Schemas
- Hasura can stitch external GraphQL APIs. Trust assumed.
- Forwarded headers can be configured (`x-hasura-user-id` forwarded to remote schema).
- Bug: remote schema in attacker-controlled domain (subdomain takeover, etc.) → sees user identities.

### 9. Actions
- Custom resolvers via HTTP webhook (`POST /myAction`).
- Hasura forwards `session_variables` to the action. If the action doesn't validate input → injection / IDOR in the downstream service.
- Audit: every action's handler.

### 10. Events (triggers)
- Hasura emits events on DB changes to webhooks.
- Webhook receives full row payload. If webhook is exposed publicly, attacker can craft fake events.
- **Fix**: webhook secret in headers; verify on receiver side.

### 11. Scheduled Triggers
- Cron-style. Payload arbitrary. Webhook receives.
- Same as Events: secret + verification.

### 12. REST endpoints layered
- Hasura can expose REST routes that map to GraphQL queries.
- Path templates with `:param` substitution.
- Audit: are these gated by the same role? Often the REST layer is forgotten in permission review.

### 13. Read replicas + write inconsistency
- Hasura's read replicas can lag. UI reads after write may show stale data.
- Side-channel: attacker can detect timing of replica sync; rarely exploitable but worth noting.

## Audit workflow

### Metadata export
```bash
hasura metadata export
```
The exported YAML files in `metadata/` are the source-of-truth for permissions. Review every `select_permissions`, `insert_permissions`, `update_permissions`, `delete_permissions` block per table per role.

### Permissions matrix
For each table:
| Role | Select | Insert | Update | Delete | Filter |
|------|--------|--------|--------|--------|--------|
| anonymous | ? | ? | ? | ? | ? |
| user | ? | ? | ? | ? | ? |
| admin | * | * | * | * | * |

Anonymous row should be near-empty for any sensitive table.

### Run-as test
- Use Hasura Console "Run as Role" feature to query as `anonymous`, `user`, etc.
- Or send `X-Hasura-Role: anonymous` + `X-Hasura-User-Id: 1` headers (only works without strict auth check; useful in dev).

### Common metadata grep
```bash
grep -rn 'filter:\s*{}' metadata/    # empty filter = all rows
grep -rn 'check:\s*{}' metadata/     # empty check = no constraint
grep -rn 'allow_aggregations: true' metadata/   # may leak counts
grep -rn 'role: anonymous' metadata/
```

## Hardening
- `anonymous` role default scope to minimum-viable; add row filters even for public data.
- Column allowlist: exclude PII / secrets from non-admin roles.
- Admin secret rotated; console not publicly reachable.
- JWT mode preferred over webhook (less moving parts).
- `claims_namespace` set; `claims_format` validated.
- Action / event webhooks have secret + IP allowlist.
- Read-replica config audited for staleness assumptions.

## References
- [Hasura security topic](https://hasura.io/docs/latest/auth/overview/)
- [Hasura permission rules](https://hasura.io/docs/latest/auth/authorization/permission-rules/)
- [Hasura JWT mode](https://hasura.io/docs/latest/auth/authentication/jwt/)
- [Hasura security advisories](https://github.com/hasura/graphql-engine/security/advisories)
- See also: [[graphql-source-review]], [[graphql-attacks]], [[apollo-server-audit-patterns]]

{% endraw %}
