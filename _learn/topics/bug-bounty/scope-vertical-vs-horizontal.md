---
title: Vertical vs horizontal domain scope
slug: scope-vertical-vs-horizontal
---

> **TL;DR:** Vertical recon goes deeper into subdomains of one apex (`*.example.com`); horizontal recon goes wider across sibling apex domains, brands, and acquired entities. Identifying which axis the program permits decides which tools and pivots will pay off.

## What it is
Bug-bounty scope language usually falls into two shapes. "All subdomains of example.com" is vertical: one apex, unlimited depth. "All assets owned by ExampleCorp" is horizontal: an unknown number of apex domains spanning brands, subsidiaries, and acquisitions ([[acquisitions-recon]]). Mixing the two unintentionally leads to out-of-scope reports and wasted recon hours.

## Preconditions / where it applies
- Reading a new program's scope page
- Designing your recon pipeline for that program
- Planning where to compete (deep on a crowded apex vs wide on under-explored corporate tree)

## Technique
1. Parse the scope language carefully. Common phrasings:
   - "*.example.com" — strictly vertical, single apex
   - "*.example.com and example.com" — vertical including apex
   - "all properties owned and operated by ExampleCorp" — horizontal, plus vertical on each
   - "the following domains: example.com, example.net, exampleshop.com" — bounded horizontal, vertical on each
2. Vertical recon stack:
   - Passive: CT logs ([[certificate-transparency]]), DNS aggregators, subdomain databases
   - Active: brute-force subdomain wordlists, DNS permutation ([[subdomain-permutation]]), virtual host enumeration ([[vhost-enumeration]])
   - Service-layer: port scan known IPs (after resolution), JS bundle harvesting for internal hostnames
3. Horizontal recon stack:
   - Reverse-WHOIS by registrant org and email ([[reverse-whois]])
   - Favicon hash and analytics-tag pivots ([[analytics-tag-correlation]])
   - SEC filings / Crunchbase / press releases for subsidiaries ([[acquisitions-recon]])
   - ASN ranges owned by the org ([[asn-enumeration]])
   - Then vertical-recon each discovered apex
4. Validate ownership before testing on a horizontally-discovered apex. False positives are common — `examplecorp.io` may belong to a squatter, not the company. Look for:
   - Same WHOIS org + registrant email as the seed apex
   - Same SSL cert SANs or CT-log organization field
   - HTTP response includes target brand / employee names / unique copyright string
   - Linked from the company's official site
5. Plan effort allocation:
   - Crowded program with a small vertical scope → go horizontal to escape competition
   - Wildcard mega-program → vertical depth wins because the apex is already known and broad
6. Keep a per-program scope file in your notes (see [[note-taking-while-hacking]]) listing both axes plus explicit out-of-scope items; cross-check every submission against it.

## Detection and defence
- Program operators: write scope unambiguously. "All assets" is friendly to hunters but creates triage chaos when subsidiaries don't know they're in scope; explicit lists scale better
- Maintain an internal asset inventory keyed to the scope rules so triagers can verify a submitted host actually belongs to the org
- For hunters: out-of-scope reports cost reputation. Document ownership proof in every horizontal finding

## References
- [HackTricks — External Recon Methodology](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — vertical and horizontal workflows
- [Bug Bounty Bootcamp (Li)](https://nostarch.com/bug-bounty-bootcamp) — scope-driven recon planning
- [HackerOne — Scopes documentation](https://docs.hackerone.com/programs/scopes.html) — how scope is encoded on platform
