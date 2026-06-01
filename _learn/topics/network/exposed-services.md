---
title: Exposed services triage
slug: exposed-services
---

> **TL;DR:** Once the scan finishes, you have a list of open ports — triage is the discipline of deciding which to investigate first by comparing observed surface against an expected baseline for the host's role.

## What it is
Exposed-services triage is the gap-analysis step between raw scan output and focused enumeration. For each open port you ask: is this service expected on a host of this role, is it the expected version, and does its exposure match the network segment's policy? Anything that fails one of those three checks is a high-priority candidate for deeper enumeration — it represents either a misconfiguration, shadow IT, or a forgotten host.

## Preconditions / where it applies
- A completed port scan with banner / version detection (see [[port-scanning]]).
- Knowledge of the host's intended role (web front-end, DB, DC, jump box) — inferred from DNS name, certificate SAN, or asset inventory.
- An internal-network engagement where you can compare hosts in the same subnet to derive a baseline empirically.

## Technique
1. **Cluster by role.** Group scan output by likely role using subnet, hostname pattern, and the dominant service set. A workstation subnet exposing 1433/tcp on one host is a 1-of-N anomaly worth a closer look.
2. **Diff against baseline.** For each cluster, identify the modal service set (e.g. SMB+RDP+WinRM for Windows servers). Hosts that add ports — old admin tools, dev databases, legacy management agents — bubble to the top.
3. **Tag versions against advisories.** Feed banners through `searchsploit`, vendor PSIRT pages, or `vulners` NSE. See [[known-cve-triage]] for the discipline of separating real CVEs from PoC noise.
4. **Flag policy violations.** Internal-only services reachable from a user segment (Redis, Elasticsearch, MongoDB, Jenkins, Docker API on 2375/tcp) are nearly always exploitable.
5. **Prioritise.** Rank by (likely impact) x (effort). Unauthenticated NoSQL on a DMZ-adjacent host beats a chained CVE on a hardened DC every time.

Useful one-liners:

```bash
# Cluster nmap XML by open-port set
nmap -iL hosts.txt -p- -sV -oA full
xsltproc nmap-xml-clusters.xsl full.xml | sort | uniq -c | sort -rn

# Pull TLS SANs across a subnet to derive role from cert
for ip in $(cat hosts.txt); do
  echo | openssl s_client -connect $ip:443 2>/dev/null \
    | openssl x509 -noout -ext subjectAltName 2>/dev/null \
    | grep DNS:
done
```

## Detection and defence
- The triage itself is invisible — it operates on scan results — but the upstream scanning is noisy. Defenders should alert on hosts with unusual outbound scan patterns.
- Defensive equivalent: maintain a port/service baseline per host role and alert on deviations (Wazuh, Tanium, or an internal Nmap CI job that diffs against a known-good snapshot).
- Block east-west traffic to management ports by default; require explicit allow-listing per service.
- Decommission discipline: forgotten dev/staging services on production VLANs are the most common finding here.

## References
- [Nmap — service and version detection](https://nmap.org/book/man-version-detection.html) — banner-to-product mapping that triage builds on.
- [HackTricks — pentesting methodology](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/pentesting-methodology.html) — the per-service deep dives this triage feeds into.
- [NIST SP 800-115 §3](https://csrc.nist.gov/publications/detail/sp/800-115/final) — formal framing for the discovery-to-vulnerability-mapping flow.
