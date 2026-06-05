---
title: OPC UA attacks
slug: opc-ua-attacks
aliases: [opcua-attacks, opc-unified-architecture-attacks]
---

> **TL;DR:** OPC UA (Unified Architecture, IEC 62541) is the modern successor to classic OPC (which was Windows DCOM-based). Designed with security from the start: TLS-equivalent transport security, X.509 certificate-based auth, signed/encrypted messages. Cross-platform, vendor-neutral, increasingly mandated. Attack surface centres on implementation bugs (parser CVEs in popular stacks), trust-store management failures, anonymous endpoints accidentally exposed, and the complexity of the protocol's address space model. Companion to [[modbus-attacks-deep]] and [[iec61850-attacks]].

## Why OPC UA matters

- **Industry 4.0 standard** for industrial-to-cloud connectivity.
- **Cross-platform** (Windows / Linux / RTOS) — runs everywhere.
- **Used in manufacturing, energy, oil/gas, transport**.
- **Replaces classic OPC** which had crippling DCOM security issues.
- **Designed with crypto** — but configuration nuance matters.

## Architecture

- **Servers** expose an address space of nodes (devices, variables, methods).
- **Clients** browse, read, write, subscribe.
- **Transport** — TCP (binary), HTTPS (XML/JSON), WebSocket variants.
- **Security policies**:
  - `None` (anonymous, no crypto).
  - `Basic128Rsa15` (deprecated).
  - `Basic256Sha256`.
  - `Aes128_Sha256_RsaOaep`.
  - `Aes256_Sha256_RsaPss`.

Modes: SignAndEncrypt, Sign, None.

## Class 1 — Anonymous / None endpoints

OPC UA servers expose multiple endpoints. If any endpoint allows `Security Policy: None` + `User Authentication: Anonymous`:
- Anyone reaching the server can browse and read/write nodes.

Configuration mistake; widely observed in older deployments.

Recon: `Shodan` for OPC UA, free OPC UA clients (UAExpert from Unified Automation) for browsing.

## Class 2 — Certificate trust store mismanagement

OPC UA requires mutual TLS-equivalent. Mistakes:
- **Auto-accept** unknown server certs (developer convenience left in production).
- **Self-signed accepted** without verification.
- **Trust store includes** vendor-default certs.
- **No revocation checking**.

Compromise the trust store → bypass mutual auth.

## Class 3 — Parser memory corruption

OPC UA binary encoding is custom; parsers are intricate. CVE history:
- **Buffer overflows** in StatusCode / message-header parsing.
- **Integer overflows** in array-length decoding.
- **Stack exhaustion** via deeply nested structures.

Disclosed bugs in open62541, Eclipse Milo, Prosys, Unified Automation, Siemens, ABB stacks.

Some have pre-auth RCE impact when endpoints accept anonymous.

## Class 4 — Crypto downgrade

Server may support multiple Security Policies. Client may pick weakest:
- If `Basic128Rsa15` (deprecated, RSA PKCS1 v1.5 padding vulnerable) accepted, certain attacks possible.

Audit policy list; disable weak.

## Class 5 — Address-space enumeration

Even with auth, anonymous-read of address space may be allowed:
- Reveal device structure.
- Reveal write-able nodes.
- Reveal vendor-specific extensions.

Useful intel for subsequent attacks.

## Class 6 — Methods / RPC abuse

OPC UA supports methods (RPC). Servers may expose:
- Restart device.
- Reset configuration.
- Download firmware.

If method-call auth is weaker than read auth, escalation path.

## Class 7 — Subscription / publication flood

Clients can subscribe to many nodes. Resource-exhaustion DoS by:
- Creating many subscriptions.
- Subscribing to high-rate nodes.

Server collapses under load.

## Class 8 — Vendor-specific extensions

OPC UA companion specifications (PackML, AutoID, etc.) and vendor extensions add specific attack surface. Audit vendor implementations of these.

## Class 9 — Embedded credentials / weak passwords

OPC UA also supports username/password auth as alternative to certs. Weak passwords + brute force = compromise.

## Common deployment mistakes

- **Default certs** left in trust store.
- **Anonymous endpoint** exposed for "diagnostics".
- **No certificate revocation**.
- **Mixed policy support** — strongest in spec, weakest in production.
- **Internet exposure** for cloud integration without VPN.

## Defensive baseline

- **Disable anonymous + None policy endpoints** in production.
- **Strong policy only** — `Aes256_Sha256_RsaPss` preferred.
- **Mutual cert auth**; rotate certs.
- **Trust store discipline** — only intended peers.
- **Update OPC UA stack firmware** on devices.
- **Network isolation** — OPC UA between OT-IT bridge, not exposed broadly.
- **Audit logs** for connections, browse, write operations.
- **Subscription quotas** per client.

## Detection

- Connection logs at OPC UA gateway.
- Write-operation logs to sensitive nodes.
- Connection from unrecognised certificate.
- Anomalous browse patterns.

## Workflow to study

1. Install open62541 or Eclipse Milo OPC UA stack.
2. Run a sample server and client.
3. Configure security policies; test connection scenarios.
4. Browse with UAExpert.
5. Read CVE history for major stacks.
6. Read OPC Foundation security analysis (multiple academic papers exist).

## Real-world incidents / research

- Multiple **CVE-tracked OPC UA stack vulnerabilities** in open62541, Eclipse Milo, vendor stacks.
- **Claroty Team82** has published OPC UA research.
- **DEF CON ICS Village** demonstrations.

## Standards / regulatory

- **IEC 62541** — the standard.
- **OPC Foundation security analysis** — periodic third-party review.
- **IEC 62443** — overall ICS/OT cybersecurity.
- **NIS2**, **NERC CIP**, **EU CRA** apply by sector.

## Related

- [[dnp3-attacks-deep]]
- [[modbus-attacks-deep]]
- [[iec61850-attacks]]
- [[profinet-ethercat-attacks]]
- [[ics-scada-protocols-attacks]]
- [[firmware-extraction]]

## References
- [OPC Foundation](https://opcfoundation.org/)
- [open62541](https://github.com/open62541/open62541)
- [Eclipse Milo](https://github.com/eclipse/milo)
- [Claroty Team82 research](https://claroty.com/team82)
- [Tenable.OT research](https://www.tenable.com/research)
- See also: [[modbus-attacks-deep]], [[iec61850-attacks]], [[dnp3-attacks-deep]], [[ics-scada-protocols-attacks]]
