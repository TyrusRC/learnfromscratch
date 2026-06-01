---
title: RPC attacks (JSON-RPC / XML-RPC)
slug: rpc-attacks
---

> **TL;DR:** JSON-RPC and XML-RPC expose a single endpoint that dispatches by method name. Enumerate methods, look for undocumented ones, batch to bypass rate limits, and abuse type-coercion across language boundaries.

## What it is
JSON-RPC 2.0 sends `{"jsonrpc":"2.0","method":"foo","params":[...],"id":1}` to one URL; XML-RPC wraps `<methodCall><methodName>foo</methodName>...</methodCall>`. The transport is uniform but the backend dispatches dynamically, so the security model collapses to "whatever the method handler checks". Common bugs: methods missing auth checks, type confusion between strong-typed clients and weak-typed servers, and batching that lets one request invoke many methods at once.

## Preconditions / where it applies
- Any endpoint that accepts JSON-RPC or XML-RPC — common in blockchain nodes, WordPress (`xmlrpc.php`), CMS admin RPCs, and legacy internal services
- For batching bypass: server supports the batch form (most do)
- For method enumeration: introspection method present (`system.listMethods`, `rpc.discover`)

## Technique
**Enumerate methods.**

```bash
# XML-RPC
curl -s https://target/xmlrpc.php -d '<methodCall><methodName>system.listMethods</methodName></methodCall>'

# JSON-RPC (OpenRPC discovery)
curl -s https://target/rpc -d '{"jsonrpc":"2.0","method":"rpc.discover","id":1}'
```

If introspection is disabled, brute-force common names (`admin.*`, `system.*`, `user.*`, `eth_*`, `personal_*`, `debug_*`) from method-name wordlists.

**Test auth per method.** Auth middleware often checks the path, not the method body. A `POST /rpc` with `Authorization: Bearer T` may be auth-checked, but the `method: "admin.deleteUser"` inside it may not be. Replay every method with a low-privilege token.

**Batching.**

```json
[
  {"jsonrpc":"2.0","method":"login","params":["u","p1"],"id":1},
  {"jsonrpc":"2.0","method":"login","params":["u","p2"],"id":2},
  {"jsonrpc":"2.0","method":"login","params":["u","p3"],"id":3}
]
```

Rate-limit middleware counts HTTP requests; batch packs 1000 calls into one request. WordPress `system.multicall` is the canonical example and is still abused for brute force.

**Type confusion.** JSON-RPC servers in dynamic languages accept `params` as array or object; sending `{"id": 1}` vs `{"id": "1"}` may pivot the query into integer or string SQL paths. XML-RPC has explicit types (`<int>`, `<string>`, `<base64>`, `<dateTime.iso8601>`) — mismatching them against handler expectations can crash parsers or trigger XXE in old libraries.

**XXE in XML-RPC.** Old PHP/Java XML-RPC libraries enable external entities by default — inject a DOCTYPE to read files or SSRF (see [[soap-attacks]] for the XML-side primitive).

**Ethereum / blockchain RPC.** Look for `eth_sendTransaction`, `personal_unlockAccount`, `debug_traceTransaction`, `admin_*` methods exposed without auth on `:8545` or `:8546`. Historic and ongoing source of stolen wallets.

## Detection and defence
- Disable introspection in production
- Apply auth and authorisation in the method handler, not only at the transport layer
- Strip batching support if not required; if required, count batch size against the rate limit
- Disable XML external entities (`libxml_disable_entity_loader(true)`, equivalent in each language)
- Allowlist methods at the gateway — never `*`
- Network-restrict node RPC ports; never expose Ethereum-style RPCs to the internet

## References
- [JSON-RPC 2.0 spec](https://www.jsonrpc.org/specification) — protocol reference
- [XML-RPC spec](https://xmlrpc.com/spec.md) — protocol reference
- [HackTricks: XML-RPC](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/xml-rpc.html) — WordPress pingback / multicall abuse
