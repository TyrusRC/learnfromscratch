---
title: API security
slug: api-security
aliases: [api-pentesting]
---

> APIs are usually the soft underbelly of an app. Most real-world
> high-impact bugs in the last few years live at the API layer.

## Prereqs

- [[web-application-security]] stage 1.
- Comfort with [Postman](https://www.postman.com/) or `curl` /
  [`httpie`](https://httpie.io/).

## Stage 1 — fundamentals

- REST basics: verbs, resources, status codes, content types.
- OpenAPI / Swagger spec reading and abuse:
  [[swagger-discovery]].
- GraphQL primer:
  <https://graphql.org/learn/>.
- Auth flows: [[jwt]], [[oauth-flows]], [[api-keys]].
- OWASP API Security Top 10 (current edition):
  <https://owasp.org/API-Security/>.

## Stage 2 — intermediate

- [[bola]] (Broken Object Level Authorization).
- [[bfla]] (Broken Function Level Authorization).
- [[mass-assignment]] · [[rate-limit-bypass]].
- [[graphql-attacks]] — introspection, aliasing, batching, depth /
  complexity DoS.
- gRPC / protobuf surface: [[grpc-attacks]].
- Tooling: [[burp-suite|Burp]] + [GraphQL
  Voyager](https://graphql-kit.com/graphql-voyager/),
  [`ffuf`](https://github.com/ffuf/ffuf),
  [`kiterunner`](https://github.com/assetnote/kiterunner).

## Stage 3 — advanced

- API gateway and WAF bypasses.
- JWT cryptographic attacks beyond `none` /
  alg-confusion: [[jwt-key-confusion]], [[jwt-jku-jwk-injection]].
- Multi-tenant SaaS — cross-tenant data access patterns.
- Webhook abuse and SSRF via outbound API calls
  ([[ssrf-to-cloud]]).
- Read [*Hacking APIs* (Corey Ball)] cover to cover.

## When you're "done"

- You can spec an unknown API in <30 min from traffic alone.
- You instinctively probe every ID parameter for [[bola]] and every
  state transition for [[bfla]].
- You can articulate the difference between authentication, session, and
  authorisation flaws and which one a given API mishandles.
