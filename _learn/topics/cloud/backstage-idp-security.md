---
title: Backstage — internal developer platform security
slug: backstage-idp-security
---

> **TL;DR:** Backstage (Spotify, CNCF) is the most popular open-source Internal Developer Platform (IDP) — a developer portal aggregating service catalog, scaffolder (template-driven service creation), TechDocs, and software templates. Sits between developers and every backend system (GitHub, Kubernetes, AWS, secrets). Compromise = mass code execution / cloud access. Hardening is a platform-team responsibility, often underweighted vs developer features.

## What it is
Backstage core (`@backstage/core`) is a React app + Node.js backend with a plugin architecture. Out of the box:
- **Service Catalog** — registry of components, systems, APIs, resources, users, groups
- **Scaffolder** — templates that create repos, deploy resources via GitOps
- **TechDocs** — docs-as-code rendered from Markdown
- **Plugins** — 250+ official + community (GitHub, GitLab, Kubernetes, AWS, Azure, Datadog, PagerDuty, Snyk, etc.)
- **Software Templates** — parameterised flows creating new services with golden-path code, IaC, CI/CD pipeline, monitoring

## Preconditions / where it applies
- Mid-size+ engineering org (~50+ engineers) where service catalog has value
- Backstage instance you operate (or commercial Spotify Portal, RoadieHQ managed)
- Integration with identity provider (OIDC, SAML)

## Attack surface

### 1. Backend plugins as integration sinks
Plugins frequently hold:
- GitHub PAT / app install ID with org access
- GitLab admin token
- Kubernetes kubeconfig for fleet of clusters
- AWS / GCP / Azure SDK credentials
- Vault token / Secret Manager access
- CI/CD trigger tokens
- Service account keys

The Backstage process becomes the convergence point. Compromise of any single plugin's config can leak the lot.

### 2. Scaffolder actions = code execution
Software templates run scaffolder actions: clone repo, fetch base files, push to GitHub, register catalog entity, trigger CI pipeline. Custom actions can run arbitrary code on the backend.

Template authors can craft actions that:
- Run shell commands in scaffolder container
- Access plugin credentials
- Modify other repos
- Create cloud resources with platform IAM

### 3. Catalog data sources
Catalog entities come from `catalog-info.yaml` files in source repos. Backstage auto-discovers via GitHub processor. Malicious commit adds `catalog-info.yaml` claiming ownership of someone else's component → renames in UI → support tickets misrouted.

### 4. Auth + identity
Backstage auth integrates with org SSO. Misconfiguration:
- Local guest user enabled in production
- API tokens (Backstage's own auth) without proper scoping
- Frontend auth without matching backend auth (auth UI bypass)
- Plugin-specific auth bypassing main auth (TechDocs static assets)

### 5. TechDocs build
TechDocs builds Markdown to HTML at runtime or at CI. If "build at runtime" enabled with cloud storage, write access to docs bucket = stored XSS in Backstage.

## Tradecraft — hardening

### 1. Authentication
- Disable guest auth: `auth.providers.guest` removed in production
- Force OIDC / SAML from org IdP
- Enforce MFA via IdP (Backstage doesn't enforce MFA itself)
- Service-to-service tokens limited scope, short-lived

```yaml
# app-config.production.yaml
auth:
  environment: production
  providers:
    google:
      production:
        clientId: ${AUTH_GOOGLE_CLIENT_ID}
        clientSecret: ${AUTH_GOOGLE_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: emailMatchingUserEntityProfileEmail
```

### 2. Backend secrets
- Use cloud Secret Manager / Vault; never env vars in plaintext
- Backend reads via `secret://aws/...` URIs (custom resolver) or via mounted secrets
- Rotate quarterly
- Audit `app-config*.yaml` for accidental secret commits — pre-commit hooks (gitleaks, talisman)

### 3. Plugin permissions
Backstage Permission Framework (RBAC):

```typescript
// In backend
permissionIntegrationRouter({
  permissions: [catalogEntityReadPermission, catalogEntityCreatePermission, ...],
  policy: new PermissionPolicy({/* custom logic */}),
});
```

Plus the `@backstage/plugin-permission-backend` for role assignment:

```yaml
permission:
  enabled: true
  rules:
    - resourceType: catalog-entity
      permissions: ['catalog-entity:read']
      conditions:
        - rule: IS_ENTITY_OWNER
```

Map permissions to identity provider groups.

### 4. Scaffolder action allow-list

```yaml
scaffolder:
  defaultAuthor:
    name: 'Backstage Bot'
    email: 'backstage-bot@example.com'
  defaultCommitMessage: 'Initial commit via Backstage'
  actions:
    allowList:
      - fetch:template
      - publish:github
      - publish:gitlab
      - catalog:register
      # Block 'debug:log', 'shell:run' custom actions
```

Whitelist only the actions required; block free-form `shell:run` patterns.

### 5. Template review
- Templates live in protected repos with CODEOWNERS
- Template repo + branch protection: required review for changes
- Template changes deploy via GitOps, not ad-hoc

### 6. Catalog ingestion
Auto-discovery is convenient but lets any repo declare catalog ownership:

```yaml
catalog:
  rules:
    # Only allow entity types operators can verify
    - allow: [Component, API, Resource, System, Domain]

  providers:
    github:
      production:
        organization: 'myorg'
        catalogPath: '/catalog-info.yaml'
        filters:
          # Only repos with the 'backstage' topic auto-registered
          topic: backstage
```

Combine with PR-based catalog change review for high-trust entities (System ownership, Domain mapping).

### 7. TechDocs
- Build TechDocs at CI, NOT at runtime in Backstage
- Use S3 / GCS / Azure Blob with read-only mount; not writeable from Backstage
- Sanitise rendered HTML (Backstage does this by default; verify CSP)
- Don't enable arbitrary Markdown extensions that allow scripting

### 8. Reverse proxy
- Backstage behind reverse proxy (Nginx / Envoy / cloud LB)
- TLS termination + HSTS
- IP allow-list if internal-only
- WAF in front (Cloudflare / AWS WAF) for public-facing instances
- Rate limit /auth endpoint

### 9. Database
- PostgreSQL in production (SQLite for dev only)
- Network isolation (VPC, private subnet)
- Encryption at rest + in transit
- Backup + recovery plan
- Connection pooling sized correctly

### 10. Logging + monitoring
- Backend logs → SIEM
- Auth events → alert on unusual sign-in patterns
- Permission denies → review for misconfig vs actual abuse attempt
- Plugin errors → look for credential failures (token rotation needed)
- Metrics via Prometheus

### 11. Upgrade discipline
Backstage releases biweekly. Plugins may have CVEs (e.g., Backstage Scaffolder template injection 2023).
- Subscribe to backstage/security GitHub advisories
- Pin versions in `package.json`; upgrade in PR reviewed by platform team
- Test upgrades in staging first

### 12. Plugin curation
Don't install every shiny plugin. Each plugin = new backend code with credentials.
- Inventory installed plugins
- Each plugin owner = a platform team member who keeps current
- Disable plugins not actively used

## Software template hardening

Templates are the most-used compromise vector. Patterns:

```yaml
# template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata: {name: golden-microservice}
spec:
  type: service
  parameters:
    - title: Service Details
      properties:
        name:
          type: string
          pattern: '^[a-z][a-z0-9-]{2,40}$'    # validate input
        owner:
          type: string
          ui:field: OwnerPicker        # constrained picker, not free text
  steps:
    - id: fetch-base
      action: fetch:template
      input:
        url: ./content
        values:
          name: ${{ parameters.name }}
    - id: publish
      action: publish:github
      input:
        repoUrl: github.com?owner=myorg&repo=${{ parameters.name }}
        defaultBranch: main
        # GitHub branch protection settings
        protectDefaultBranch: true
        requireCodeOwnerReviews: true
    - id: register
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps['publish'].output.repoContentsUrl }}
        catalogInfoPath: '/catalog-info.yaml'
```

- Validated inputs
- No `debug:log` / `shell:run` actions
- Published repo gets branch protection set automatically
- Catalog registration via standard action

## Multi-tenant / multi-team Backstage

Larger orgs:
- One Backstage instance per division can prevent permission sprawl
- OR single instance with team-scoped permissions (more complex but consistent UX)
- Spotify's own approach evolved over years; their Portal commercial product addresses multi-tenant

## RoadieHQ / Spotify Portal alternative

If running Backstage in-house feels heavy, managed alternatives:
- **Spotify Portal** — official commercial Backstage
- **RoadieHQ** — managed Backstage SaaS
- **Cortex / OpsLevel / Mia-Platform / Port** — alternative IDPs, different architectures

Managed reduces operational burden but adds vendor + data egress considerations.

## Common implementation pitfalls

- **Guest auth in production** — anonymous browse, even sensitive metadata
- **Backend secrets in app-config.yaml committed to repo** — common GitHub leak
- **Scaffolder running with org-admin PAT** — single token = org takeover if compromised
- **No template review process** — anyone can add destructive action
- **Catalog drift** — entities stale, ownership wrong, false sense of inventory
- **Plugin sprawl** — 30 plugins installed, 5 used, 30 attack surfaces
- **Skipping upgrades** — Backstage moves fast; year-old version misses important security fixes
- **No backup / recovery plan** — Backstage DB loss = catalog rebuild from scratch

## OPSEC for blue team

- Auth events: alert on unusual identity providers, geo, time
- Scaffolder execution: log + audit; high-rate templates from one user = anomaly
- GitHub token usage from Backstage IP: monitor scope (each PAT should have known repo-pattern usage)
- Backend pod compromise = treat as platform breach
- Plugin code changes: review like CI/CD code

## References
- [Backstage docs](https://backstage.io/docs/)
- [Backstage Permission Framework](https://backstage.io/docs/permissions/overview)
- [Backstage Security Disclosures](https://github.com/backstage/backstage/security/advisories)
- [Roadie blog — Backstage at scale](https://roadie.io/blog/)
- [CNCF Backstage Threat Model](https://cncf.io/) — community-driven

See also: [[paved-road-pattern-platform]], [[devsecops-platform-engineering]], [[ci-cd-as-cloud-attack-surface]], [[gitops-security-argo-flux]], [[sigstore-cosign-supply-chain-signing]], [[policy-as-code-opa-kyverno-defender]], [[cicd-pipeline-hardening-defender]], [[github-actions-workflow-source-audit]], [[secrets-in-code-detection-patterns]]
