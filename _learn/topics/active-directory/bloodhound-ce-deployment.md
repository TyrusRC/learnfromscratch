---
title: BloodHound CE deployment & differences from legacy
slug: bloodhound-ce-deployment
aliases: [bloodhound-ce, bhce, bh-community, specterops-ce]
---

> **TL;DR:** BloodHound Community Edition (CE) replaced the legacy Neo4j-on-desktop app in 2023. It's a containerised web app backed by Postgres+Neo4j with a REST API and Python SDK (`bhe-py`). Edges and Cypher syntax changed; old custom queries break. New ESC1-16 / Coerce / OWNS edges live here, not in legacy.

## Mental model

Legacy BloodHound (4.x) = an Electron desktop client speaking Bolt directly to a Neo4j you ran yourself. BloodHound CE (5.x/6.x) = a containerised stack — API server + Postgres (auth/users/asset groups) + Neo4j (graph) + web UI — with auth, multi-user, REST API, and SDK access. Same SharpHound collector for AD; new AzureHound collector for Entra. The CE web UI is the only first-class client.

```
┌────────────┐   /api/v2   ┌──────────────┐   bolt   ┌──────────┐
│  Web UI    │ ──────────► │  bhapi (Go)  │ ───────► │  Neo4j   │
│  (React)   │             │              │ ───────► │ Postgres │
└────────────┘             └──────────────┘          └──────────┘
        ▲                          ▲
        │ ZIP upload               │ POST /api/v2/file-upload
        │                          │
   SharpHound CE             AzureHound CE
```

## Deployment

The official compose stack — fastest path:

```bash
git clone https://github.com/SpecterOps/BloodHound
cd BloodHound/examples/docker-compose
docker compose pull && docker compose up -d
# UI: http://localhost:8080  (admin / printed-on-first-start password)
```

Production knobs in `bloodhound.config.json`:

```jsonc
{
  "database":    { "addr": "postgres:5432", "database": "bloodhound", "username": "bloodhound", "password": "..." },
  "neo4j":       { "addr": "neo4j:7687", "username": "neo4j", "password": "..." },
  "default_admin": { "principal_name": "admin", "email_address": "admin@example.com", "password": "Rotate-Me-1" },
  "tls":         { "cert_file": "/etc/bh/cert.pem", "key_file": "/etc/bh/key.pem" },
  "saml_enabled": true
}
```

Memory: budget ≥8 GB for Neo4j heap on any tenant > 50k objects. `NEO4J_dbms_memory_heap_max__size=4G` in the compose env.

## Collection

```bash
# AD on-prem — same SharpHound binary, --CollectionMethods unchanged
SharpHound.exe -c All,GPOLocalGroup --outputdirectory C:\Temp
# CE-recommended low-noise sweep
SharpHound.exe -c DCOnly --domain corp.lab

# Entra ID
AzureHound.exe list --refresh-token <rt> --tenant <tid> -o azurehound.json
# or via roadrecon DB then translate
```

Upload via UI **File Ingest → Upload** or:

```bash
curl -k -X POST https://bhce/api/v2/file-upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@20260611_corp_lab.zip"
```

API tokens come from **Profile → API Tokens**; HMAC-signed JWT with full RBAC.

## New & changed edges (vs legacy 4.x)

- `ADCSESC1..ADCSESC16` — full ESC family ([[adcs-esc13-oid-group-linked]], [[adcs-esc14-altsecidentities]], [[adcs-esc15-ekuwu]], [[adcs-esc16-securityext-disabled]]).
- `CoerceAndRelayNTLMToLDAP|SMB|ADCS` — synthesises [[petitpotam-coercion]] / [[dfscoerce]] / [[shadowcoerce]] reachability with relay targets, including signing-required gating.
- `DCSync`, `SyncLAPSPassword`, `WriteAccountRestrictions`, `WriteGPLink`, `WriteSPN` exposed as first-class edges (previously you had to traverse `GenericAll` + ACEs).
- `OWNS` deprecated; `Owns_RAW` + `OwnsLimitedRights` reflect MS 2024 ACL change (Owner does **not** auto-grant `WriteDACL` when `OwnerRights` is denied — collector reports both).
- `DCFor`, `SameForestTrust`, `CrossForestTrust`, `AbuseTGTDelegation` for forest-cross traversal.

Legacy custom queries that reference `MemberOf*1..` paths usually still work, but anything querying `n.haslaps`, `n.unconstraineddelegation` as booleans needs the new property names (`hasLAPS`, `unconstrainedDelegation` — camelCase).

## Tradecraft

```cypher
// Tier-zero owners (everyone with a write on a DA-equivalent)
MATCH p=(n)-[:Owns|GenericAll|WriteDACL|WriteOwner|GenericWrite*1..]->(g:Group)
WHERE g.objectid ENDS WITH '-512' OR g.objectid ENDS WITH '-519'
RETURN p LIMIT 25

// Every coerce-and-relay reachable DA path
MATCH p = shortestPath((u {owned:true})-[:CoerceAndRelayNTLMToLDAP|CoerceAndRelayNTLMToADCS|ADCSESC1|ADCSESC3|ADCSESC8|ADCSESC9a|ADCSESC9b*1..]->(t:Group))
WHERE t.objectid ENDS WITH '-512'
RETURN p

// Kerberoastable users in tier-zero
MATCH (u:User {hasspn:true})-[:MemberOf*1..]->(g:Group)
WHERE g.objectid ENDS WITH '-512'
RETURN u.name
```

The CE UI's **Cypher** tab has saved queries and an analysis pre-built (Findings panel) — run **Run All Analysis** after every ingest to refresh attack-path findings.

## Detection / Telemetry

- LDAP collection from SharpHound/AzureHound is rapid-fire `(objectClass=*)` enumeration. Defender for Identity / ITDR alerts:
  - "Reconnaissance using directory services" (M-DI 2031)
  - "Suspicious LDAP enumeration"
- AzureHound queries Graph at >200 RPS by default. Tenant audit logs show `Get-AzureAD*` / `/v1.0/users` floods.
- BHCE API server logs every file upload + ingest — useful for blue teams running BHCE *defensively*: pipe ingest into Sentinel for path-watching.

## OPSEC pitfalls

- Default `bloodhound` compose binds to `0.0.0.0:8080` — don't expose the API to the engagement network. Bind to `127.0.0.1` and tunnel.
- The Postgres + Neo4j volumes contain a full graph of the target. Treat the docker volume like a sensitive artefact; wipe at engagement end (`docker compose down -v`).
- SharpHound CE's default `--CollectionMethods All` includes `LocalGroup`/`Session` over SMB — touches every workstation. Use `DCOnly` first, then targeted collection.
- Don't `--Stealth` and `--CollectionMethods All` together — they conflict; All wins silently, and you blast LDAP.
- AzureHound default scope is the whole tenant. For phased ops use `--scope` to limit to a few directories or apps.

## References

- https://bloodhound.specterops.io/
- https://github.com/SpecterOps/BloodHound
- https://github.com/SpecterOps/SharpHound
- https://github.com/SpecterOps/AzureHound
- https://posts.specterops.io/introducing-bloodhound-ce-9f8f8c1f7f5e

See also: [[bloodhound]], [[sharphound]], [[ldap-enumeration]], [[adcs-attacks]], [[adcs-esc13-oid-group-linked]], [[adcs-esc14-altsecidentities]], [[adcs-esc15-ekuwu]], [[adcs-esc16-securityext-disabled]], [[acl-abuse]], [[ad-coercion-and-relay-matrix-2025]], [[netexec-nxc-workflow]]
