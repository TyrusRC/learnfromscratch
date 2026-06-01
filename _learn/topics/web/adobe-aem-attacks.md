---
title: Adobe AEM attacks
slug: adobe-aem-attacks
---

> **TL;DR:** Adobe Experience Manager (AEM / CQ5) ships with a Sling-based servlet stack and a JCR repository; misconfigured Dispatcher rules and default servlets leak content, credentials, and code execution via querybuilder, GET-extension tricks, and CRX package uploads.

## What it is
AEM exposes the JCR repository through Apache Sling. Every resource is reachable by URL with selectors, extensions, and suffixes that map to servlets (e.g. `.json`, `.xml`, `.infinity.json`, `.querybuilder.json`). The Dispatcher (an Apache/IIS module) is the only thing between the public and the publish/author instances — if its allowlist is too loose, the default servlets are reachable and leak the entire content tree or accept admin package uploads.

## Preconditions / where it applies
- Public AEM publish or author instance (look for `/etc/clientlibs/`, `/libs/`, `etc.clientlibs`, `<meta name="generator" content="Adobe Experience Manager">`).
- Dispatcher rules that do not strip selectors / extensions or do not deny `/system/`, `/bin/`, `/crx/`, `/etc.clientlibs/granite/`.
- Default credentials still present on author: `admin:admin`, `replication:replication`, `author:author`.

## Technique
Fingerprint version via `/libs/granite/core/content/login.html` or `/libs/cq/core/content/welcome.html`. Then probe the canonical default-servlet bypasses — Sling tries to resolve every URL until it hits a renderer, so suffix and extension tricks reach the same resource.

```http
GET /content/dam.json?p.limit=-1 HTTP/1.1
GET /content/we-retail.infinity.json HTTP/1.1
GET /bin/querybuilder.json?path=/home/users&p.limit=-1&p.hits=full HTTP/1.1
GET /etc/groovyconsole.html HTTP/1.1
```

Selector/extension obfuscation to bypass Dispatcher filters that only check the path suffix:

```
/content/dam.html/a.json
/content/dam.css.html?wcmmode=disabled
/content/dam.json;%0aa.css
/content/dam.feed.html
```

On author with auth, the CRX package manager (`/crx/packmgr/service.jsp`) accepts arbitrary ZIPs that drop OSGi bundles or JSP into the repo — a fully crafted package landing a JSP under `/apps/system/install/` yields RCE on the next request. Groovy Console (`/etc/groovyconsole.html`) and the AEM Forms FormServer (CVE-2024-26467 family) are common direct-RCE pivots when reachable.

## Detection and defence
- Dispatcher: explicit allowlist of paths and extensions; deny `.json`, `.infinity`, `.tidy`, `.querybuilder`, `.feed`, `.form` on publish; strip selectors.
- Disable WebDAV (`/crx/repository`) on publish; rotate `admin`, `replication`, `anonymous` accounts.
- Monitor Sling request logs for unusual extensions and for `p.limit=-1` queries against `querybuilder.json`.
- Apply the Adobe Security Bulletins quarterly; AEM has a long tail of disclosure CVEs (2018-3811, 2022-30683, 2023-26368, 2024-20720).

See also [[ssrf]], [[file-upload]], [[information-disclosure]].

## References
- [AEM Dispatcher Security Checklist](https://experienceleague.adobe.com/docs/experience-manager-dispatcher/using/configuring/security-checklist.html) — official hardening list
- [HackTricks – AEM](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/aem-adobe-experience-cloud.html) — request tricks and default endpoints
- [0ang3el – Hunting for AEM bugs](https://speakerdeck.com/0ang3el/hunting-for-bugs-in-aem-webapps) — selector/extension bypass catalogue
