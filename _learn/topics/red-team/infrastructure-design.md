---
title: Infrastructure design
slug: infrastructure-design
---

> **TL;DR:** Separate phishing, payload-hosting, short-haul C2, long-haul C2, and exfil into independent tiers behind redirectors so blowing one stage doesn't blow the operation.

## What it is
Red-team infrastructure is the network-of-VMs-and-domains that supports the operation. Modern design treats each function as a tier: domain assets, hosting providers, redirector chains, team servers. Tiers are isolated so detection of one piece (say, phishing landing) doesn't reveal the C2 plane.

## Preconditions / where it applies
- An engagement with realistic OPSEC requirements (not a CTF lab)
- Time to age domains and warm up sender reputation
- A budget for VPS, domains, and an automation pipeline

## Technique
**Tier model.**
1. Phishing — sender domain + landing page. Disposable.
2. Payload host — stage-0 hosts the dropper. Categorise the domain, sign the binary, host on a CDN-fronted bucket.
3. Short-haul C2 — interactive beacons. HTTPS through a redirector to a team server.
4. Long-haul C2 — sleep-multiple-days persistence. Different domain, different transport (DNS or HTTPS through a different CDN).
5. Exfil — separate channel, never the C2 path. S3 bucket, ephemeral upload URL, or per-host pastebin-style endpoint.

**Redirectors.** Use lightweight nginx / Apache / socat on cheap VPS. Filter on User-Agent, URI, source country, IP allowlist before passing through to the team server. Drop anything that doesn't match the beacon profile to a decoy site.

```
# nginx redirector fragment
location /api/v1/sync {
  if ($http_user_agent !~ "MyAgent/4\\.") { return 302 https://example.com/; }
  proxy_pass http://teamserver-internal:8443;
}
location / { return 302 https://example.com/; }
```

**Domains.** Aged + categorised. Buy expired domains that already have benign reputation (`ExpiredDomains.net`). Submit them to category services (BlueCoat, McAfee, Cisco Talos) under a benign description. Validate with `urlscan.io` before going live.

**Hosting.** Mix providers — Azure, AWS, Vultr, Linode, DigitalOcean — to spread fingerprint and reduce one-takedown-kills-all risk. Cloud-front high-reputation CDNs (Cloudflare, Fastly) for high-trust egress when policy permits.

**Automation.** Terraform / Ansible to spin up the whole tier on demand, tear down on burn. Don't manually configure — repeatable infra is auditable and fast to rebuild.

**Domain fronting alternatives.** True host-header fronting is mostly dead at major CDNs since 2018-2019. Replacements: Azure Front Door rules, AWS API Gateway as edge, CloudFront with custom origin behaviours, dedicated SaaS endpoints behind a categorised domain.

## Detection and defence
- Newly-registered domain alerts via passive DNS
- TLS JA3 fingerprints — your redirector's web stack must match your impersonation target
- Reputation aggregators (SpamHaus, Talos) catch fresh ASNs and IP blocks
- Defenders should baseline outbound destinations per-host and alert on first-seen domains
- Threat intel pivoting: shared TLS certs, shared WHOIS, reused VPS provider = correlate operator across infra

## References
- [BC Security — Red Team Infra-as-Code](https://www.bc-security.org/post/the-current-state-of-red-team-infrastructure-as-code/) — IaC patterns
- [Red Team Infrastructure Wiki](https://github.com/bluscreenofjeff/Red-Team-Infrastructure-Wiki) — reference design
- [SpecterOps blog](https://posts.specterops.io/) — automation and Terraform examples
- [[c2-protocol-design]] [[c2-frameworks]] [[opsec-fundamentals]]
