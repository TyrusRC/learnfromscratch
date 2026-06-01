---
title: SOAP attacks
slug: soap-attacks
---

> **TL;DR:** SOAP services advertise themselves via WSDL, parse XML aggressively (XXE), and often layer WS-Security signatures that can be wrapped or stripped. Treat the WSDL as a free attack-surface map.

## What it is
SOAP wraps RPC calls in a SOAP envelope (`<soap:Envelope><soap:Body>...`) over HTTP, MQ, or JMS. Services publish a WSDL describing every operation and message schema. Common weaknesses: WSDL exposure to anonymous callers, XXE in the parser, XPath/SQL/command injection in operation parameters, WS-Security signature wrapping (XSW relatives — see [[saml-xsw-attacks]]), and authentication via plaintext UsernameToken.

## Preconditions / where it applies
- A SOAP endpoint and its WSDL (`?wsdl`, `.wsdl`, `/services/`, `/axis2/services/listServices`)
- An XML parser configured with external entity resolution enabled (older JAXP, libxml2 with defaults)
- Legacy enterprise stacks: Apache Axis/Axis2, Apache CXF, .NET WCF, Java JAX-WS, IBM WebSphere

## Technique
1. **Find WSDLs.** Brute common locations, scan with `wsdler` (Burp) or pull from `?wsdl`. Map operations, parameters, and bindings.
2. **Generate request templates** with `SoapUI`, `wsdl2java`, `zeep` (Python), or `Burp Wsdler`. Try every operation with low/no auth.
3. **XXE via SOAP envelope:**

   ```xml
   <?xml version="1.0"?>
   <!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
   <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
     <soap:Body><tns:lookup><name>&xxe;</name></tns:lookup></soap:Body>
   </soap:Envelope>
   ```

   Out-of-band variants for blind XXE pull a remote DTD that exfiltrates files via parameter entities.

4. **Injection in operation parameters.** Treat each WSDL parameter as a fuzzable input — SQL, XPath, command, LDAP. SOAP services often skip the input filtering present on REST tier.
5. **WS-Security abuse.** Endpoints requiring signed headers may still accept stripped or wrapped signatures:
   - Remove `<wsse:Security>` and resend — some servers fall through to "no auth required"
   - XSW variants apply: move the signed `<Timestamp>` or `<Body>` while the verifier checks signature on one element and the consumer reads another
   - UsernameToken with `Type="...PasswordText"` ships the password in cleartext over SOAP — replay it, or test for weak passwords
6. **SAML inside SOAP.** Many enterprise SOAP services accept SAML assertions in `<wsse:Security>`; XSW techniques transfer directly ([[saml-xsw-attacks]]).
7. **WSDL scanning tools.** `wsdler`, `wsScanner`, `soapui-pro` discover and replay; pair with manual review of every parameter.

## Detection and defence
- Disable external entities at the parser (`XMLConstants.FEATURE_SECURE_PROCESSING`, `setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)`, equivalent per stack)
- Restrict WSDL access (mTLS or auth) — internal services should not publish full operation lists to the internet
- Enforce WS-Security policy at a gateway with strict schema validation before reaching application logic
- Reject SOAP requests with unexpected headers (`<wsse:Security>` when none expected, multiple `<Timestamp>` elements)
- Treat SOAP services like any API: log per-operation auth decisions; alert on bursts of WSDL retrieval

## References
- [OWASP WSTG: web services testing](https://owasp.org/www-project-web-security-testing-guide/) — testing methodology backbone
- [HackTricks: web API pentesting](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/web-api-pentesting.html) — WSDL discovery and XXE
- [PayloadsAllTheThings: XXE](https://github.com/swisskyrepo/PayloadsAllTheThings/tree/master/XXE%20Injection) — payload corpus for SOAP envelopes
