---
title: Asset graphing
slug: asset-graphing
---

> **TL;DR:** Model the target as a graph (apex → subdomain → IP → ASN → port → tech → vendor); store it, then alert on the diff between scans — change is the bug signal.

## What it is
Asset graphing is the practice of treating recon output as a typed graph rather than a flat list of hostnames. Nodes are apex domains, subdomains, IPs, ASNs, certificates, JS bundles, tech stacks, and third-party vendors. Edges are relationships — `RESOLVES_TO`, `OWNED_BY`, `CNAMES_TO`, `RUNS`, `LOADS`. Once the graph exists you can query it ("show every host running nginx 1.18 that appeared in the last 7 days") and, more importantly, you can diff today's graph against yesterday's. The diff is the alerting surface.

## Preconditions / where it applies
- A wildcard scope big enough that mental tracking breaks down (hundreds+ of subdomains)
- A scheduled recon pipeline ([[continuous-recon-automation]], [[automation-and-rinse-repeat]])
- Storage you control — a flat JSON / SQLite file is fine to start; Neo4j or DuckDB once it grows

## Technique
1. Normalise every recon tool's output into a single record format. A minimal node:
   ```json
   {"type":"host","value":"api.target.tld","src":"crtsh","ts":1717200000,
    "edges":[{"to":"203.0.113.10","rel":"resolves_to"},
             {"to":"AS13335","rel":"hosted_by"}]}
   ```
2. Run the recon plumbing — [[certificate-transparency]], [[subdomain-enumeration]], [[asn-enumeration]], httpx, nuclei tech detection — and append every observation as nodes/edges. Tag each with the source tool and timestamp so you can prove provenance later.
3. Compute a content hash per asset (host + open ports + tech + page title + favicon hash + JS bundle hash). The hash is the diff key.
4. On every run, compute `new = today \ yesterday`, `gone = yesterday \ today`, `changed = same key, different hash`. Push the diff into Slack/Discord/email — never the full list. New host that hosts a `jenkins` favicon is a 30-second triage to first impact.
5. Useful queries once graphed: "subdomains pointing to a cloud provider IP we don't own → potential takeover," "hosts where the JS bundle changed in the last 24h → re-run [[js-endpoint-extraction]]," "newly-seen ASN → was there an acquisition?"

## Detection and defence
- For the target: monitor your own attack surface the same way (asset-inventory products like Censys ASM, Detectify, Bishop Fox CAST do this commercially)
- DNS/cert-issuance anomalies that surface in your graph also surface in CT-log monitors the defender runs — staging hosts with corporate certs are noisy
- For the hunter: keep raw scan artefacts for at least one diff cycle so you can prove "this host did not exist yesterday" when reporting takeovers or staging exposures

## References
- [Project Discovery — uncover & asset workflows](https://docs.projectdiscovery.io/) — toolchain that fits a graph-shaped pipeline
- [HackTricks asset discovery](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — the wider asset-graph mental model
- [OWASP Amass user guide](https://github.com/owasp-amass/amass/blob/master/doc/user_guide.md) — built around a typed graph of recon findings
