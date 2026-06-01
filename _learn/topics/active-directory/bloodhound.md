---
title: BloodHound
slug: bloodhound
---

> **TL;DR:** Collect AD/Entra/AzureAD objects and edges once, query the result as a Neo4j graph. The single biggest force multiplier in AD work.

## What it is
BloodHound is a graph-driven analysis frontend for Active Directory and Entra ID. Collector tools ([[sharphound|SharpHound]], BloodHound.py / bloodhound-ce-python, AzureHound) walk LDAP, SAMR, GPO files, ADCS, and Graph API to enumerate principals (users, computers, groups, OUs, GPOs, cert templates) and the relationships between them ("MemberOf", "AdminTo", "HasSession", "GenericAll", "AllowedToDelegate", "AddKeyCredentialLink", "WriteSPN", "ESC1"…). The data lands in Neo4j. Operators query with Cypher to find shortest paths to high-value targets.

## Preconditions / where it applies
- Any authenticated foothold in the domain — most edges are world-readable.
- For session data (HasSession): admin on the queried hosts or sufficient remote registry / SMB access.
- BloodHound Community Edition (CE) or legacy BloodHound 4.x. CE is the active project; tool flags differ.

## Technique
**1. Collect.** Pick a collector matching your situation.

```bash
# From Windows, in-domain
SharpHound.exe -c All,Session,LoggedOn --zipfilename corp.zip
# From Linux, creds only
bloodhound-ce-python -u me -p 'pw' -ns 10.0.0.1 -d corp.lab -c All --zip
# Azure / Entra
azurehound list -u me@corp.onmicrosoft.com -p 'pw' -o az.json
```

`-c All` covers ACLs, GPO links, sessions, trusts, container hierarchies, AD CS templates. Stealth mode (`--stealth`) skips noisy SMB/SAMR queries.

**2. Ingest.** Drop the zip into the BloodHound CE web UI (or legacy app). Neo4j stores nodes/edges.

**3. Query.** Pre-built queries cover "Find Shortest Paths to Domain Admins", "Users with most local admin rights", "Kerberoastable users", "ESC1 / ESC8 paths". Custom Cypher fills the rest:

```cypher
MATCH p=shortestPath((u:User {owned:true})-[*1..]->(g:Group {name:'DOMAIN ADMINS@CORP.LAB'}))
RETURN p
```

Mark your foothold objects `owned`. Mark sensitive targets `highvalue`. The "Outbound" object info pane shows every right your owned principal has — usually the fastest route to the next hop.

**4. Walk the path.** Each edge has documented abuse info (link to [[acl-abuse]], [[shadow-credentials]], [[constrained-delegation]] etc.) — execute, mark new owns, re-query.

For Tier-0 audit on the defender side, run with no `owned` set and look for any non-tier-0 principal with a path to tier-0.

## Detection and defence
- LDAP query volumes from SharpHound/CE are huge — alert on a single account pulling >100k LDAP results in minutes, or on SAMR enumeration of all local groups across many hosts.
- Honeyobjects: users with juicy SPNs or KeyCredentialLink attributes that BloodHound flags as attack paths but that nobody legitimately touches.
- AD restricted-LDAP defenses (LDAP signing + channel binding) don't block collection but make NTLM relay around it harder.
- Run BloodHound internally on a schedule; treat unexpected new edges to tier-0 as incidents.

## References
- [BloodHound CE docs](https://bloodhound.specterops.io/) — collector flags, edge reference, Cypher cookbook
- [SpecterOps blog](https://posts.specterops.io/tagged/bloodhound) — methodology and edge research
- [HackTricks — BloodHound](https://book.hacktricks.wiki/en/windows-hardening/active-directory-methodology/bloodhound.html) — common queries
- [GitHub — bloodhound-ce-python](https://github.com/dirkjanm/BloodHound.py) — Linux collector
