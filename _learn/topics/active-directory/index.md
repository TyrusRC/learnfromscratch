---
title: Active Directory — topics
slug: active-directory-index
aliases: [ad-topics, ad-index]
---

AD attack primitives. See [[active-directory]] for ordering.

## Enumeration
- [[bloodhound]] · [[sharphound]]
- [[ldap-enumeration]] · [[adidnsdump]]

## Kerberos
- [[ntlm]] · [[kerberos]]
- [[asreproast]] · [[kerberoasting]]
- [[unconstrained-delegation]] · [[constrained-delegation]]
- [[resource-based-constrained-delegation]]
- [[silver-tickets]] · [[golden-tickets]]
- [[s4u2self-abuse]] · [[roastinthemiddle]]

## ACL / object abuse
- [[acl-abuse]] · [[gpo-abuse]] · [[shadow-credentials]]
- [[adminsdholder-abuse]] · [[machine-account-quota-abuse]]
- [[dmsa-badsuccessor]]

## Credential primitives
- [[dcsync]] · [[dpapi-secrets]] · [[lsa-secrets]]
- [[gmsa-decryption]]

## Relay and coercion
- [[ntlm-relay-ws2025-mitigations]]
- [[printer-bug-spoolsample]] · [[petitpotam-coercion]]
- [[dfscoerce]] · [[shadowcoerce]]
- [[winreg-relay-2024]]

## AD CS
- [[adcs-attacks]] — ESC1–ESC12 baseline.
- [[adcs-esc13-oid-group-linked]]
- [[adcs-esc14-altsecidentities]]
- [[adcs-esc15-ekuwu]]
- [[adcs-esc16-securityext-disabled]]

## Advanced
- [[child-to-forest-root]] · [[cross-forest-trust-abuse]]
- [[ms-rpc-abuse]] · [[ad-persistence]]
- [[mssql-trusted-links]] · [[mssql-xp-cmdshell-impersonation-chains]]
- [[sidhistory-injection]]
