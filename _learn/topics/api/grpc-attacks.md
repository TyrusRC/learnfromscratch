---
title: gRPC attacks
slug: grpc-attacks
---

> **TL;DR:** gRPC services frequently ship with reflection enabled, missing TLS, no per-method auth, and naive deserialisation. Reflection plus `grpcurl` turns most of them into a flat REST-like surface in minutes.

## What it is
gRPC is HTTP/2 + Protocol Buffers. Each "service" exposes "methods" with typed request and response messages. Security depends on TLS for transport, per-call interceptors for auth, and the developer remembering both. Common failure modes mirror REST (broken auth, broken authorisation, mass assignment) but discovery is harder because protobuf is binary — until reflection is enabled.

## Preconditions / where it applies
- A gRPC endpoint reachable over HTTP/2 (often port 50051, or `:443` with `Content-Type: application/grpc`)
- Reflection enabled (common in staging, frequently leaked to prod) or a `.proto` file leaked elsewhere
- Optional: gRPC-Web bridge in a browser app — easy to capture from devtools

## Technique
1. **Detect.** `nmap -p- --script http2-info`, or try `grpcurl -plaintext host:50051 list`. A non-error response means reflection is on.
2. **Enumerate services and methods.**

   ```bash
   grpcurl -plaintext target:50051 list
   grpcurl -plaintext target:50051 list pkg.UserService
   grpcurl -plaintext target:50051 describe pkg.UserService.GetUser
   ```

3. **Call without auth.** Many services check auth in a higher-level gateway and skip it on the gRPC server itself:

   ```bash
   grpcurl -plaintext -d '{"id":"1"}' target:50051 pkg.UserService.GetUser
   ```

4. **Authorisation testing.** Replay the same methods with a low-privilege token; treat as [[bola]] / [[bfla]] but over protobuf. Field-level [[mass-assignment]] applies — protobuf accepts unknown fields silently in many languages.
5. **Streaming abuse.** Server-streaming and bidi-streaming endpoints often lack rate limits because the gateway only sees one connection. Open a long stream and request iteration.
6. **TLS / mTLS.** If only TLS (not mTLS) is required, any client can connect. If reflection over TLS is disabled but the service still accepts unknown methods, brute-force method names from common service templates.
7. **gRPC-Web.** Capture the base64 envelope in browser devtools, decode to inspect protobuf, then replay with `grpcurl` over plain gRPC where possible.

## Detection and defence
- Disable reflection in production builds (`grpc.reflection.v1alpha` should not be in the registry)
- Enforce auth in a server-side interceptor, not only in the upstream gateway
- Mutual TLS between internal services; client cert identity feeds the authorisation policy
- Rate-limit per method and per stream message count, not just per connection
- Strip unknown fields on the server (`UnknownFields.SerializedSize == 0` check) to prevent silent over-posting

## References
- [HackTricks: gRPC-Web pentest](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/grpc-web-pentest.html) — discovery and replay
- [grpcurl](https://github.com/fullstorydev/grpcurl) — the standard client for testing
- [gRPC authentication guide](https://grpc.io/docs/guides/auth/) — what defenders should be configuring
