---
title: ServiceNow attacks
slug: servicenow-attacks
aliases: [servicenow-exploitation, snow-attacks, servicenow-security]
---

> **TL;DR:** ServiceNow instances expose a massive attack surface through misconfigured ACLs, unauthenticated table API access, Glide record injection, script include abuse, and MID Server RCE. Default configurations often leave sensitive tables (e.g., `sys_user`, `kb_knowledge`) world-readable. Assetnote and MDSec research uncovered CVEs enabling full unauthenticated remote data exfiltration.

## What it is
ServiceNow is an enterprise platform for IT service management (ITSM), HR, security operations, and custom workflows. It runs as a cloud-hosted instance (`<company>.service-now.com`) with a complex server-side scripting engine (Glide), REST/SOAP APIs, and a large default schema. Its attack surface matters because it typically stores credentials, employee PII, infrastructure inventories (CMDB), and security incident data — high-value targets for both external attackers and insiders.

## Key attack vectors

### 1. Unauthenticated ACL bypass (CVE-2024-4879 / CVE-2024-5217)

Assetnote discovered that the `jelly` template rendering engine allowed unauthenticated access to internal APIs by chaining input validation bypasses. Combined with CVE-2024-5217 (Glide expression injection), this enabled full unauthenticated RCE.

```http
GET /login.do?jvar_page_title=<PAYLOAD>
```

The chain: bypass authentication check via jelly template injection → access server-side Glide API → execute arbitrary code. Patched in Washington DC and later releases, but instances running older versions remain vulnerable.

### 2. Misconfigured table ACLs (the most common finding)

ServiceNow's ACL model defaults to restricting access, but admins routinely open tables for integrations and forget to tighten them. The Table API at `/api/now/table/<table_name>` respects ACLs — if a table's ACL allows unauthenticated or low-privilege reads, the data is exposed.

```bash
# Probe for world-readable tables (unauthenticated)
curl -s "https://TARGET.service-now.com/api/now/table/sys_user?sysparm_limit=1" \
  -H "Accept: application/json"

# Common sensitive tables to check
# sys_user          — all user accounts, emails, phone numbers
# sys_user_has_role — role assignments
# kb_knowledge      — knowledge base articles (may contain creds/procedures)
# cmdb_ci           — configuration items (servers, IPs, software inventory)
# incident          — security/IT incidents
# sc_req_item       — service catalog requests
# sys_attachment     — file attachments
# alm_license       — license keys
# oauth_credential  — OAuth tokens
```

AppOmni and Assetnote documented thousands of internet-facing instances leaking `sys_user` and CMDB data.

### 3. Glide record injection

Server-side scripts use `GlideRecord` for database queries. If user input is concatenated into `addEncodedQuery()` without sanitization, an attacker can modify the query logic — analogous to SQL injection but in ServiceNow's query language.

```javascript
// Vulnerable server-side script include
var gr = new GlideRecord('incident');
gr.addEncodedQuery('assignment_group=' + current.getParameter('group'));
gr.query();
// Attacker sends: group=SomeGroup^ORDERBYsys_created_on^active=true^NQ
// The ^NQ (new query) or ^OR injections can exfil additional data
```

Encoded query operators to abuse: `^OR` (boolean OR), `^NQ` (new query — starts a fresh query block), `^ORDERBY`, `^GROUPBY`, `JAVASCRIPT:` prefix (Glide script evaluation in query context on older versions).

### 4. Script include abuse

Script includes are server-side JavaScript libraries. If a script include is marked `client_callable=true`, it can be invoked from the client via the `xmlhttp.do` or GlideAjax endpoint — even by low-privilege or guest users.

```http
GET /xmlhttp.do?sysparm_processor=AJAXScript
    &sysparm_name=VulnerableScriptInclude
    &sysparm_function=getData
    &param=INJECTED_VALUE
```

Audit: query `sys_script_include` for `client_callable=true` entries and review their `script` field for dangerous operations (`GlideRecord` queries without ACL enforcement, `eval()`, `GlideSystem.exec()`).

### 5. MID Server RCE

MID (Management, Instrumentation, and Discovery) Servers are on-prem agents that bridge the ServiceNow instance with internal networks. They poll the instance for commands and execute them locally. Compromise paths:

- **MID Server credential theft**: MID Server config stores instance credentials in `config.xml` — often cleartext or weakly encrypted. Steal creds → authenticate to the instance as the MID user (which typically has elevated roles).
- **Command injection via probe**: if an attacker compromises the instance, they can push arbitrary probes/commands to MID Servers, gaining RCE inside the customer network.
- **Outdated MID agents**: MID Servers that are not auto-updated may have known Java deserialization or XXE vulnerabilities.

```bash
# MID Server config file (on the MID host)
cat /opt/agent/config.xml | grep -i "mid.instance\|password\|url"
```

### 6. Widget and portal exploitation

Service Portal widgets use AngularJS (client) + server-side script (GlideRecord). Common flaws:

- Widget server scripts that query tables without enforcing ACLs (relying on widget-level access control that is bypassed by direct API calls)
- SSRF via widgets that fetch external URLs
- Client-side template injection in AngularJS `$scope` bindings (though CSP mitigates this on newer instances)

### 7. SSO misconfiguration

- SAML response replay if `NotOnOrAfter` is not enforced
- IdP misconfiguration allowing assertion spoofing
- Auto-provisioning creating high-privilege accounts from attacker-controlled IdP claims
- Guest user having implicit access to tables when SSO is the only auth gate

## Enumeration checklist

```bash
# 1. Version fingerprint
curl -s "https://TARGET.service-now.com/stats.do" | grep "Build tag"

# 2. Check if guest access is enabled
curl -s "https://TARGET.service-now.com/api/now/table/sys_properties?sysparm_query=name=glide.guest.default_roles&sysparm_limit=1"

# 3. List accessible tables (guest context)
curl -s "https://TARGET.service-now.com/api/now/table/sys_db_object?sysparm_fields=name,label&sysparm_limit=100"

# 4. Check for user enumeration
curl -s "https://TARGET.service-now.com/api/now/table/sys_user?sysparm_fields=user_name,email,name&sysparm_limit=5"

# 5. Check knowledge base (often contains internal procedures, creds)
curl -s "https://TARGET.service-now.com/api/now/table/kb_knowledge?sysparm_limit=5&sysparm_fields=short_description,text"
```

## Detection and defence

- **Harden ACLs**: audit all table ACLs — no table should allow unauthenticated read unless explicitly required; use the "Security Best Practices" app from the ServiceNow Store
- **Disable guest access**: set `glide.guest.default_roles` to empty; set `glide.rest.unauthenticated` to `false`
- **Patch aggressively**: ServiceNow releases family patches (Washington DC, Vancouver, etc.) — the ACL bypass CVEs require prompt patching
- **Audit script includes**: query `sys_script_include` for `client_callable=true` and review each for injection/data-leak risks
- **MID Server hardening**: encrypt `config.xml`, restrict network access, keep MID Servers on the latest auto-update channel
- **Monitor API access**: alert on high-volume `/api/now/table/` requests, especially to sensitive tables, from unexpected IPs
- **IP ACLs**: restrict instance access to corporate IP ranges where possible

## References

- [Assetnote — ServiceNow CVE-2024-4879 / CVE-2024-5217 chain](https://www.assetnote.io/resources/research/chaining-three-bugs-for-unauthenticated-rce-in-servicenow) — unauthenticated RCE chain
- [AppOmni — Misconfigured ServiceNow ACLs](https://appomni.com/ao-labs/servicenow-data-exposure/) — widespread data exposure research
- [MDSec — ServiceNow MID Server attacks](https://www.mdsec.co.uk/) — MID Server compromise paths
- [ServiceNow — Security Best Practices](https://docs.servicenow.com/bundle/washingtondc-platform-security/page/administer/security/concept/security-best-practices.html)

See also: [[broken-access-control]], [[application-logic-flaws]], [[backup-and-config-leakage]], [[command-injection]]
