---
title: Authorization patterns — RBAC, ABAC, ReBAC, Zanzibar, OPA
slug: authorization-patterns-rebac-abac
aliases: [authz-models, rebac-zanzibar, abac-opa]
---

{% raw %}

> **TL;DR:** RBAC (roles) is simple but coarse; ABAC (attributes) is flexible but hard to debug; ReBAC (relationships, Zanzibar-style) scales to social graphs; OPA/Cedar are policy-as-code engines that can express any of the above. Audit centres on which model is in use, where the policy lives (centralised or scattered), how it's evaluated (request-time check vs query-rewrite), and whether the decision is enforced consistently at every access point.

## What it is
Authorization (authz) determines what an authenticated user can do. Authentication says who you are; authorization says what you can touch. Most appsec bugs are authz bugs (IDOR, BOLA, BFLA, privilege escalation chains).

## Model 1 — RBAC (Role-Based Access Control)

### Pattern
- Users have roles (`admin`, `editor`, `viewer`).
- Roles grant permissions (`post:create`, `post:delete`).
- Check: `if (user.role in allowedRoles) allow()`.

### When it fits
- Small static permission set.
- Few roles (< 20).
- Coarse-grained access.

### Common bugs
- Role check without resource check → IDOR (`editor` can edit any post, not just their own).
- Role enumeration via guessable ordinals (see [[auth-bypass-from-source-review]]).
- Role assignment via mass assignment.

### Audit
- Find every role check; for each, is there a resource-ownership check too?
- Map role → permissions; flag any role with unexpected breadth.

## Model 2 — ABAC (Attribute-Based Access Control)

### Pattern
- User has attributes (department, region, clearance).
- Resource has attributes (sensitivity, owner, tags).
- Environment has attributes (time, IP, MFA-recent).
- Policy: `allow if user.department == resource.department && user.clearance >= resource.sensitivity`.

### When it fits
- Fine-grained, context-sensitive decisions.
- Compliance constraints (GDPR data residency, HIPAA roles).
- Many resources, many actors, varied combinations.

### Common bugs
- Attribute injection: user-supplied attribute trusted (always read from session/auth context, never request).
- Policy bug: `||` instead of `&&` in conditions.
- Time-of-check / time-of-use: attributes change between check and action.
- Policy explosion: thousands of overlapping rules, no central audit.

### Audit
- Find the policy engine call site; trace attribute sources.
- Test edge cases: missing attribute (defaults?), max-length attribute, special chars.
- Run policy through fuzz testing.

## Model 3 — ReBAC (Relationship-Based Access Control, Zanzibar-style)

### Pattern
- Authorization graph: nodes are users + resources, edges are relationships.
- Examples: `user:alice has_role member of group:eng`, `doc:42 owner user:alice`, `doc:42 viewer member of group:eng`.
- Check: "does there exist a path from user to permission on resource?"
- Origin: Google's Zanzibar paper (2019).

### When it fits
- Social graph (Google Docs, Slack, GitHub).
- Hierarchical orgs with sharing.
- Permission inheritance (group → folder → file).

### Common bugs
- Stale tuples after a revoke.
- Tuple injection: write permission for "doc:42 viewer user:alice" via a sloppy API.
- Caching / consistency: eventually-consistent reads return old answer.
- Wildcards in relations (`group:*`) overbroad.

### Implementations
- [SpiceDB](https://github.com/authzed/spicedb) (Authzed).
- [OpenFGA](https://github.com/openfga/openfga) (CNCF, Auth0).
- [Permify](https://github.com/Permify/permify).
- [Keto](https://www.ory.sh/keto/) (Ory).

### Audit
- Schema: each relation, each permission. Look for overpermissive relations.
- Write API: who can create tuples? Should be system-only, not user-controlled.
- Consistency choice: strong reads vs eventually consistent — for sensitive paths, force strong.

## Model 4 — Policy-as-code (OPA, Cedar)

### Pattern
- Policy expressed in a DSL (Rego for OPA, Cedar for AWS Cedar).
- Decoupled from application code.
- App queries policy engine: "can user X do action Y on resource Z?"
- Engine returns allow/deny + reasons.

### Example (Rego)
```rego
package auth.posts

default allow := false

allow {
  input.user.id == input.resource.owner_id
}

allow {
  input.user.role == "admin"
}
```

### When it fits
- Many services need consistent policy.
- Compliance audit ("show me every rule that allows X").
- Policy evolves independently of app deploy.

### Common bugs
- Default not deny: `default allow := true` (or no default) — fail-open.
- Policy compiled wrong: typo silently accepted.
- App ignores `reasons`: blanket deny logged as "user error" not "policy decision".
- Performance: complex policy + every request → latency.

### Audit
- Find every policy file; review for fail-open patterns.
- Find app integration points; confirm decisions enforced consistently.
- Run policy tests (OPA has `opa test`).

## Where the policy is enforced

### App-layer
- Most common; explicit `if` checks in handlers.
- Risk: scattered, easy to miss.

### Framework-layer
- Annotations / decorators / middleware (`@PreAuthorize`, `@UseGuards`, `before_action`).
- Risk: depends on framework correctly invoking; gaps via custom code paths.

### API gateway
- Centralised auth/authz check at the edge.
- Risk: internal endpoints bypass if reachable directly.

### Database-layer
- Row-level security (Postgres RLS, MySQL views, Hasura permissions).
- Pro: defence in depth; even if app forgets, DB enforces.
- Risk: complex policies in SQL are hard to debug; performance.

### Service mesh
- mTLS + policy at network layer (Istio, Linkerd + Cilium/OPA).
- Pro: catches service-to-service authz gaps.
- Risk: separate operational team; policy drift.

## Defence patterns

### Centralise the policy
- One source of truth (OPA bundle, Cedar policy, ReBAC schema).
- App calls; doesn't re-implement.
- Single audit surface.

### Per-resource ownership check
- Always check ownership/permission at the time of read/write.
- Never trust the route to filter by user.

### Default deny
- Every policy starts at "no". Explicit `allow` for each path.
- Catches the omitted-check bug.

### Decision logs
- Every authz check logged with input + decision + reason.
- Privacy-preserving (no PII in log).
- Used for audit + debug.

### Per-role test suites
- For each role, integration test the access patterns: can do X, cannot do Y.
- Run on every PR.

## Common audit findings

### Tier 1
- Resource ownership check missing → IDOR/BOLA.
- Role check without context → broken access control.
- Mass-assignment of role/permission field.
- Default-allow policy.

### Tier 2
- Stale ReBAC tuples after user removed from org.
- Inconsistent policy between API and admin panel.
- Cache between policy engine and app missing invalidation.

### Tier 3
- Performance-driven shortcuts that bypass policy (admin endpoint reads from cache that's not policy-aware).

## References
- [Google Zanzibar paper](https://research.google/pubs/pub48190/)
- [OPA — Open Policy Agent](https://www.openpolicyagent.org/)
- [AWS Cedar](https://www.cedarpolicy.com/)
- [Authzed SpiceDB](https://docs.authzed.com/)
- [OWASP ASVS V4 — Access Control](https://owasp.org/www-project-application-security-verification-standard/)
- See also: [[broken-access-control]], [[idor]], [[bfla]], [[bola]], [[auth-bypass-from-source-review]]

{% endraw %}
