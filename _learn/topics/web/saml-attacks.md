---
title: SAML attacks
slug: saml-attacks
---

> **TL;DR:** XML signature wrapping, comment injection, IdP confusion, replay across SPs.

## What it is
SAML 2.0 is a federation protocol where an Identity Provider issues an XML `<Response>` containing a signed `<Assertion>` about a user, which the Service Provider consumes. The XML signature is positional — it covers specific elements identified by `Reference URI`. Bugs come from XML parsing/signing mismatches, weak comparison, and audience/recipient confusion.

## Preconditions / where it applies
- SP consumes SAML responses (POST binding to `/SAML2/POST/SSO` or similar)
- Verification pipeline parses XML twice (once to extract signature target, once to read claims), with possible inconsistency
- IdP metadata configured with a public key the attacker can sign or forge against

## Technique
1. **XML Signature Wrapping (XSW)** — duplicate the signed `<Assertion>` element. Signature verifier finds the signed copy (by id) and validates it; claims reader walks the document and reads the **other**, attacker-modified copy. Eight canonical XSW variants per Mainka et al.; tools: SAML Raider (Burp extension).
   ```xml
   <Response>
     <Assertion ID="A1"> <!-- attacker, NameID=admin --> ... </Assertion>
     <Assertion ID="A2"> <!-- original signed copy --> <Signature .../> </Assertion>
   </Response>
   ```
2. **Comment / null-byte injection in NameID** — `<NameID>admin<!--comment-->@evil</NameID>`. Some parsers concatenate text nodes ignoring comments, others stop at comment. Signature validates against `admin<!--comment-->@evil` text, app reads `admin`. Classic Duo / OneLogin 2018 bug.
3. **`xmlns` / canonicalisation differences** — exclusive-c14n vs inclusive; namespace context manipulation changes the signed bytes' meaning to the consumer.
4. **`xsi:type` confusion** — modify schema type so the parser interprets a node differently.
5. **`Recipient` / `Destination` / `AudienceRestriction` not validated** — replay a victim's signed assertion to a different SP. Or strip the AudienceRestriction entirely (some libs ignore missing fields).
6. **`NotBefore` / `NotOnOrAfter` not enforced** — replay old assertions.
7. **Unsigned response, signed assertion** — attacker rewraps a signed assertion inside a fresh, unsigned `<Response>` they construct; SP checks only assertion signature.
8. **Untrusted IdP** — SP loads IdP metadata from a URL; replace the cert via [[ssrf]] or DNS hijack and sign with attacker key.
9. **Algorithm downgrade** — force `xmldsig#rsa-sha1` or `xmldsig#dsa-sha1` even when stronger is supported; sometimes `none` accepted.
10. **Parser differential** — REXML vs Nokogiri vs libxml — see [[parser-differential-saml-ruby]] for the 2024 Ruby case study.

## Detection and defence
- Use a SAML library that validates signature **before** any XPath/DOM access, and re-validates that the signed element is the one being read.
- Strictly validate `Issuer`, `Destination`, `Recipient`, `AudienceRestriction`, `InResponseTo`, `NotBefore`, `NotOnOrAfter`.
- Disable SHA-1 and `none`; require RSA-SHA256 minimum.
- Pin IdP cert in SP config; never auto-fetch metadata over plain HTTP; verify metadata signature.
- Reject responses with multiple `<Assertion>` elements.
- Logs: `Issuer` not in allowlist, signature alg downgrade, repeated `InResponseTo`.
- Related: [[parser-differential-saml-ruby]], [[sso-attacks]], [[oauth-flows]], [[jwt]], [[xxe]].

## References
- [HackTricks — SAML attacks](https://book.hacktricks.wiki/en/pentesting-web/saml-attacks/index.html) — XSW catalog
- [Mainka et al. — On breaking SAML](https://www.usenix.org/system/files/conference/usenixsecurity12/sec12-final91.pdf) — XSW theory
- [Duo — SAML response signing flaws](https://duo.com/blog/duo-finds-saml-vulnerabilities-affecting-multiple-implementations) — 2018 comment-injection class
