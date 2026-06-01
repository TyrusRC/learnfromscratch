---
title: SAML XML Signature Wrapping (XSW)
slug: saml-xsw-attacks
---

> **TL;DR:** Move the signed assertion inside the SAML response so the signature still verifies, then inject an unsigned attacker-controlled assertion that the application actually consumes. Eight canonical variants cover the common parser/validator splits.

## What it is
XML Signature can sign a specific element by ID. Many SAML stacks validate the signature on one element and then have the business logic read attributes from a different element by name. If the document can hold both the original signed assertion (somewhere harmless) and a forged unsigned assertion (where the consumer looks), the signature still verifies but authentication runs on attacker-controlled data. Documented as eight XSW variants by the Ruhr-Uni-Bochum team.

## Preconditions / where it applies
- A SAML SP (Service Provider) that accepts a signed AuthnResponse or Assertion
- Validator and consumer are separate code paths (common in Java JAX-WS, .NET WIF, many SSO SDKs)
- No schema validation, no canonical-element-id pinning, no "only one assertion" check

## Technique
1. Capture a legitimate signed SAML response (Burp + SAML Raider, or the network tab during SSO).
2. For each of XSW1-XSW8, transform the document:
   - **XSW1/2.** Wrap the signed Response/Assertion as a child or sibling of an injected Response/Assertion containing forged attributes.
   - **XSW3/4.** Move the signed Assertion under an injected Assertion, swap their order.
   - **XSW5/6.** Forged Assertion at top; signed Assertion buried inside Extensions or Object element with `Reference URI` still pointing to its ID.
   - **XSW7/8.** Use schema extension points (`<Extensions>`, `<Object>`) to hide the legit signed element while presenting the forged one to the consumer.
3. Forge attributes (NameID, Role, Email) in the visible-to-consumer assertion.
4. Re-base64 and POST the manipulated response to the ACS URL.

```xml
<samlp:Response>
  <saml:Assertion ID="forged">
    <saml:Subject><saml:NameID>victim@target</saml:NameID></saml:Subject>
    <saml:AttributeStatement>...</saml:AttributeStatement>
  </saml:Assertion>
  <samlp:Extensions>
    <saml:Assertion ID="signed-original">
      <ds:Signature>...</ds:Signature>
    </saml:Assertion>
  </samlp:Extensions>
</samlp:Response>
```

5. Burp's **SAML Raider** automates all eight variants. Iterate; many SPs only break on a subset.

## Detection and defence
- Validate the signature on the exact element the consumer will read — pass the element reference between validator and consumer, never re-look-up by ID
- Reject responses containing more than one Response/Assertion
- Enforce strict schema validation before signature processing
- Pin acceptable assertion locations (`Response/Assertion[1]` only); reject anything in Extensions or Object containers
- Library guidance: use vetted SAML libraries (`pysaml2`, `simplesamlphp`, `OpenSAML`) configured with `wantAssertionsSigned=true` and disable XML signature wrapping mitigations only after testing
- Log: identical NameID arriving via differently structured responses, multiple assertions per response, signed elements buried inside Extensions

## References
- [Somorovsky et al., "On Breaking SAML"](https://www.usenix.org/conference/usenixsecurity12/technical-sessions/presentation/somorovsky) — original XSW paper with all eight variants
- [SAML Raider](https://github.com/CompassSecurity/SAMLRaider) — Burp extension automating XSW
- [HackTricks: SAML attacks](https://book.hacktricks.wiki/en/pentesting-web/saml-attacks/index.html) — variant cheatsheet and defences
