---
title: Case study — PortSwigger's annual top-10 research pattern
slug: case-study-portswigger-top-10-pattern
aliases: [portswigger-research-pattern, kettle-research-pattern]
---

> **TL;DR:** PortSwigger Research (largely James Kettle and colleagues) publishes an annual "Top 10 web hacking techniques" list and produces multiple of the entries themselves. Their pattern: take a *semantic* property of HTTP that most people treat as given (request boundaries, cache keys, connection state) and find inputs that make the property fail. The bugs end up shaping the next year of testing tools. Companion to [[case-study-orange-tsai-research-pattern]] and [[cache-poisoning-modern-chains]].

## Why study the pattern

PortSwigger's work tends to:
- Produce new bug *classes*, not bug instances.
- Land in Burp Suite as a new feature within months.
- Set the agenda for the bug bounty class for a year.

If you read the past five years of their research end to end, you'll see the same shape repeatedly. Studying the shape means you can produce class-creating research yourself.

## The pattern

### Pick an HTTP property "everyone knows" is true

Examples:
- Each HTTP request lives in its own connection (it does not, with keep-alive and HTTP/2).
- The cache key uniquely identifies a response (it doesn't if backends differ on keys).
- A request's boundary is unambiguous given `Content-Length` (it isn't with multiple LB hops).
- A WebSocket upgrade is a one-shot handshake (it has timing characteristics that leak state).

### Find the implementations that disagree on the property

Identical to the [[case-study-orange-tsai-research-pattern]] step. The disagreement is the bug seed.

### Build the testing primitive *first*, the exploit *second*

Kettle's pattern is to *first* build a way to *measure* the property — a tool, a Burp extension, an open-source utility — then find targets that fail the measurement.

Examples:
- **Smuggler** / Burp's HTTP Request Smuggler — built before the public smuggling research dropped.
- **Param Miner** — built to detect cache key normalisation bugs.
- **Turbo Intruder** — single-connection high-throughput sender, enables single-packet races.

The tool enables the research; the research enables more tool features.

### Publish reproducibly

PortSwigger posts always include:
- An exact reproduction recipe.
- A list of vulnerable products tested.
- The defence and detection.
- A new Burp feature so readers can hunt the same class.

The *replicability* is what gives the research industry-wide impact.

## Worked example shape — Web cache poisoning

1. Property: "Cache key is canonical URL."
2. Disagreement: many CDNs and origins normalise URL differently, or include some headers (e.g., `X-Forwarded-Host`, `X-Forwarded-Proto`) in the request but not the cache key.
3. Primitive: send a request with an unkeyed header that influences the response; subsequent unrelated requests get the poisoned response.
4. Tool: Param Miner brute-forces headers to find which influence the response without being in the cache key.

After the talk, every cache deployment globally had to be audited.

See [[cache-poisoning]] and [[cache-poisoning-modern-chains]].

## Worked example shape — HTTP request smuggling

1. Property: "`Content-Length` and `Transfer-Encoding` agree on boundary."
2. Disagreement: some front-ends prefer `CL`, others `TE`; some implement chunked differently.
3. Primitive: craft a request where front-end and back-end disagree → smuggle a second request into the next victim's connection.
4. Tool: HTTP Request Smuggler in Burp.

See [[http-request-smuggling]] and [[http-smuggling-modern-variants]].

## Worked example shape — Single-packet race

1. Property: "Two requests can be sent close together but not at the *same instant*."
2. Disagreement: HTTP/2 frames allow two requests to arrive in a single TCP packet.
3. Primitive: race conditions that needed sub-microsecond timing become reliable.
4. Tool: Turbo Intruder single-packet attack mode.

See [[race-conditions]].

## Worked example shape — Browser-powered desync (BPD)

1. Property: "Browser only ever talks to its origin via correct HTTP requests."
2. Disagreement: with desync primitives, attacker can make a browser fetch produce a malformed request landing on a victim's connection.
3. Primitive: client-side smuggling exploitable purely via a malicious page visit.
4. Tool: HTTP Request Smuggler extended to BPD.

## The "this shouldn't work" filter

The bugs come from inputs the researcher believed *shouldn't* work but tried anyway. The class-discovering move is checking the assumption empirically. Examples:

- "Surely you can't put two `Content-Length` headers." (You can. Front-ends will pick one, back-ends the other.)
- "Surely HTTP/2 doesn't have header continuations." (It does, with subtle quirks.)
- "Surely a body in a GET is ignored." (Sometimes parsed.)

The skill is *consciously listing your assumptions* and testing each one.

## How to copy the method

1. Pick an area of HTTP / a protocol you use daily.
2. List every assumption you have about it. ("Headers are case-insensitive." "GET has no body." "There's one root document per response.")
3. For each assumption, find the implementations that potentially diverge.
4. Build a measurement tool.
5. Test across products.
6. Publish.

Even if you don't produce class-discovering research, the audit produces dozens of small bugs along the way.

## What's hard

- Hard to scope your time without a deadline. Open-ended research is unfunded by default.
- Hard to *measure* something cleanly across many products without false positives.
- Hard to convince program owners "this is a bug" when the class is novel.

Worth it: a single class-defining publication tends to shape your career.

## Reading list

- "HTTP Desync Attacks" (USENIX Security 2019 / Black Hat 2019).
- "Practical Web Cache Poisoning" (2018).
- "Smashing the State Machine" — race conditions.
- "Browser-Powered Desync Attacks" (2022).
- PortSwigger Top 10 annual posts (every December).

## References
- [PortSwigger Research](https://portswigger.net/research)
- [Top 10 web hacking techniques (annual)](https://portswigger.net/research/top-10-web-hacking-techniques-of-2024)
- [Burp Suite extensions for the research](https://portswigger.net/bappstore)
- See also: [[case-study-orange-tsai-research-pattern]], [[http-smuggling-modern-variants]], [[cache-poisoning-modern-chains]], [[race-conditions]]
