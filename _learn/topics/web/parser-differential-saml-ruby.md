---
title: SAML parser-differential auth bypass
slug: parser-differential-saml-ruby
---

> **TL;DR:** XML parser disagreement between signature verifier and attribute extractor — full SAML auth bypass (ruby-saml CVE-2024-45409, samlify CVE-2025-47949).

## What it is
SAML responses are XML documents that carry an enveloped XML signature over an `Assertion` element. A library that handles SAML must (1) verify the signature over the *exact* canonical bytes and (2) extract identity attributes from the *same* element. When step 1 and step 2 traverse the DOM differently — different namespace handling, different element selection, different canonicalisation — an attacker can stuff a benign signed assertion alongside a malicious unsigned one, the verifier sees "signed!" while the consumer reads the attacker's identity. Whole class is called XML Signature Wrapping (XSW); 2024-2025 produced two high-impact instances.

## Preconditions / where it applies
- SAML SP that accepts IdP responses (POST binding)
- Library that uses two different XML walkers for verify vs read (REXML + Nokogiri, libxml + DOM-Wrap, dual-parser stacks)
- Attacker knows or guesses a victim user's identifier (email / NameID) — assertions for them then become forgeable

## Technique
Baseline XSW: capture a legitimate signed response, then wrap or duplicate the signed `Assertion` so that the signature reference still validates against the original element while the SP consumer picks up the attacker's substituted element. Variants 1-8 differ in where the malicious assertion is positioned and what reference URI it carries.

CVE-2024-45409 (ruby-saml ≤ 1.17.0). ruby-saml used Nokogiri to verify the signature but REXML to read attributes. REXML's namespace handling treats elements with mismatched namespace prefixes as additional siblings; Nokogiri normalises them. Result: attacker submits a response containing the IdP's signed assertion plus a second assertion using a slightly different namespace declaration. Nokogiri verifies the legit assertion; REXML returns the attacker's. Patch tightens canonicalisation and rejects multi-assertion responses.

CVE-2025-47949 (samlify ≤ 2.10.0). samlify's DOM lookup for the signed reference matched by `ID` attribute case-insensitively while the canonical signature reference used the original case; combined with an unsigned wrapping assertion the SP returned attacker-controlled `NameID`.

Generic payload shape:

```xml
<samlp:Response>
  <ds:Signature> <ds:Reference URI="#legit"/> ... </ds:Signature>
  <saml:Assertion ID="evil"> <saml:Subject><saml:NameID>victim@target</saml:NameID></saml:Subject> ... </saml:Assertion>
  <saml:Assertion ID="legit"> <!-- original signed --> </saml:Assertion>
</samlp:Response>
```

Tooling: SAML Raider (Burp), `samlsig`, custom scripts using `xmlsec1` for canonical comparison. See [[saml-attacks]] for non-differential variants.

## Detection and defence
- Use *one* canonicalised, signed sub-tree and read identity attributes from that sub-tree only
- Reject responses with more than one `Assertion`, or with elements outside the signed scope
- Pin the library to a fixed-bug release; upgrade ruby-saml ≥ 1.18, samlify ≥ 2.10.1
- Compare verifier's element-selection XPath to consumer's — they must be identical
- Log SAML responses with multiple `Assertion` elements or with namespace anomalies as suspicious

## References
- [WorkOS — Common SAML security vulnerabilities](https://workos.com/guide/common-saml-security-vulnerabilities) — XSW overview
- [GitHub Security Advisory — ruby-saml CVE-2024-45409](https://github.com/SAML-Toolkits/ruby-saml/security/advisories/GHSA-jw9c-mfg7-9rx2) — patch notes
- [GitHub Security Advisory — samlify CVE-2025-47949](https://github.com/tngan/samlify/security/advisories) — fix details
