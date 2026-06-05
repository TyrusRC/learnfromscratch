---
title: CDN trust-chain bypass
slug: cdn-trust-chain-bypass
aliases: [cdn-bypass, origin-bypass-via-cdn]
---

> **TL;DR:** CDNs (Cloudflare, Akamai, Fastly, Fronts at edge) sit in front of an origin to absorb DDoS, terminate TLS, filter via WAF, and cache content. If an attacker can reach the origin directly, every protection collapses: the WAF is bypassed, rate-limits disappear, and the origin's trust in CDN-injected headers (X-Forwarded-For, X-Real-IP, CF-Connecting-IP) can be turned into auth or IP-allow-list bypass. This note covers origin-IP discovery, header trust abuse, and cache/origin mismatch chains. Companion to [[waf-bypass-research-deep]], [[cache-poisoning-modern-chains]], and [[domain-fronting-and-cdn-abuse]].

## Why it matters

The CDN trust chain is the assumption that all traffic to the origin first passes through the edge. That assumption is broken constantly:

- Origin keeps a public IP (for legacy access, monitoring, SSH); attackers find it.
- Origin allow-lists CDN IP ranges but still trusts `X-Forwarded-For` from anyone.
- Cache key on the CDN differs from the parameters the origin uses, leading to [[cache-poisoning-modern-chains]] and [[cache-deception]].
- TLS cert pinning between edge and origin is often missing; once the IP is known, you connect directly with SNI of the target host.

For a bug-bounty hunter or red-teamer, reaching the origin behind a hardened CDN is often the difference between a "blocked by WAF" 403 and a full RCE. For a defender, it is the difference between "we have Cloudflare" and "we are actually protected".

## Classes / patterns

### Origin IP discovery

Sources to enumerate:

- **DNS history**: SecurityTrails, DNSDumpster, ViewDNS, Farsight DNSDB. Pre-CDN A records often leak the original origin IP. The org may have been on direct hosting before fronting with CDN; the old IP is still serving.
- **Subdomain leakage**: `mail.target.com`, `dev.target.com`, `staging.target.com`, `cpanel.target.com`, `direct.target.com` often skip the CDN. Brute-force with `amass`, `subfinder`, `puredns`. See [[expanding-attack-surface]].
- **SSL certificate transparency**: crt.sh, Censys, Cert Spotter. The origin's TLS cert (if it serves one directly) carries a SAN with the target hostname. Search Censys for `services.tls.certificates.leaf_data.names: "target.com"` and filter by IPs not in the CDN ASN.
- **Email headers**: bounce messages, password resets, "contact us" forms. The `Received:` chain often shows the origin's outbound IP, which is frequently the same host as the web app.
- **`.well-known` and favicon hash mismatch**: hash the favicon and search Shodan `http.favicon.hash:<murmur3>` excluding CDN ASNs. The origin returns the same favicon.
- **Censys / Shodan / FOFA / ZoomEye**: search by HTTP response body hash, `Server` header, unique strings ("powered by", company name in HTML), or HTTP/2 settings frame fingerprint.
- **GitHub / GitLab / pastebin leaks**: search for `target.com` near `prod` or `origin`, deployment manifests, Terraform plans, k8s `ingress.yaml`.
- **Misconfigured monitoring / status pages**: New Relic, Datadog, UptimeRobot may publicly expose origin hostnames.
- **HTTP/3 / QUIC / Alt-Svc**: some origins announce a non-CDN endpoint.
- **NSEC / NSEC3 walking** on misconfigured DNSSEC zones; see [[dnssec-misconfig-attacks]].
- **SPF / DMARC records**: `v=spf1 ip4:1.2.3.4 ...` often lists origin egress IPs.

### Reaching origin without CDN inspection

Once you have a candidate IP `1.2.3.4`:

```bash
curl -k --resolve target.com:443:1.2.3.4 https://target.com/
curl -k -H "Host: target.com" https://1.2.3.4/
```

If it returns the application (not a "direct access forbidden" page), the origin is exposed. Replay payloads that the WAF blocked at the edge, harvest CSRF tokens, hit admin endpoints. See [[waf-bypass-research-deep]] for the kinds of payloads that suddenly start working.

### Header-trust abuse

Origin often runs Nginx/Apache/Traefik that trusts CDN-injected client-IP headers. Two failure modes:

- **Trust without source check**: any request to the origin IP with `X-Forwarded-For: 127.0.0.1` is treated as localhost. Combined with admin panels that allow-list `127.0.0.1`, this is instant authentication bypass.
- **Trust with CDN-IP allow-list, but no header strip**: requests via the real CDN edge can also spoof the upstream client IP because the CDN does not strip incoming `X-Forwarded-For`. The origin appends instead of replacing, so the leftmost value is attacker-controlled. Defeats IP-based rate limiting, geo-fencing, and audit logs.

Headers worth probing: `X-Forwarded-For`, `X-Real-IP`, `X-Originating-IP`, `X-Remote-IP`, `X-Client-IP`, `True-Client-IP`, `CF-Connecting-IP`, `Akamai-Client-IP`, `Fastly-Client-IP`, `Forwarded` (RFC 7239), `X-Forwarded-Host`, `X-Forwarded-Proto`. Combine with [[host-header-injection]].

### Cache / origin mismatch chains

If the CDN keys cache on `Host + path` but the origin renders different content based on `X-Forwarded-Host` or a query parameter the CDN ignores, you can poison the edge cache with attacker-controlled HTML served to every subsequent visitor. The canonical chain:

1. Identify an unkeyed input the origin reflects (header, parameter, cookie).
2. Confirm CDN caches the response (look for `Age`, `X-Cache: HIT`, `CF-Cache-Status: HIT`).
3. Poison via crafted request; observe normal users get the poisoned variant.

Detailed playbook in [[cache-poisoning-modern-chains]] and the older [[cache-poisoning]].

### Vendor-specific patterns

- **Cloudflare**: `CF-Connecting-IP` is the canonical client header; origins that trust `X-Forwarded-For` instead are spoofable. Cloudflare Workers add another rewrite layer; see [[cloudflare-workers-audit]] and [[cloudflare-tenant-attacks]] for SaaS-tenant cross-talk. Argo Tunnel / Cloudflared exposes origin only over the tunnel - good when configured, bad when both tunnel and public IP work.
- **Akamai**: `True-Client-IP` is the trusted header. Akamai's Ghost servers in Site Shield should be the only ingress; if origin firewall is open to the world, Site Shield is bypassable. Pragma debug headers (`Pragma: akamai-x-cache-on, akamai-x-get-true-cache-key`) leak cache key shape - useful for poisoning research.
- **Fastly**: VCL is attacker-readable when leaked via GitHub. Fastly uses `Fastly-Client-IP`. Surrogate keys and `Surrogate-Control` headers control purging; abusing them to refuse purge requests can extend poisoning windows. See research patterns in [[case-study-portswigger-top-10-pattern]].
- **AWS CloudFront + ALB**: `CloudFront-Viewer-*` headers and signed URLs. Origin Access Identity (OAI) / OAC restricts S3 origins; ALB origins are often left open. `X-Amz-Cf-Id` is informative.
- **Vercel / Netlify edge middleware**: middleware rewrites can be bypassed by hitting the underlying serverless function URL. See [[vercel-edge-and-middleware-audit]].

### Domain fronting and SNI mismatch

If the CDN routes by SNI but the origin by Host header (or vice versa), you can present SNI for `cdn-customer-A.com` while sending `Host: cdn-customer-B.com`. This is the basis of [[domain-fronting-and-cdn-abuse]]. Most major CDNs killed it for C2 use in 2018-2019, but residual primitives exist for SSRF gadgets and tenant isolation bypass.

## Defensive baseline

- Restrict origin firewall to CDN IP ranges (Cloudflare publishes `cf-ips`, Akamai publishes Site Shield maps, Fastly publishes IP lists). Pull them dynamically.
- Authenticate edge-to-origin with mTLS or a shared secret header (`X-Auth-Shared-Secret`) the origin enforces; do not rely on IP alone.
- Strip and overwrite `X-Forwarded-For` and equivalent client-IP headers at the edge; never append blindly.
- Use Cloudflare Argo Tunnel, AWS PrivateLink, or Akamai Site Shield + ETP so the origin has no public IPv4/IPv6 listener.
- Rotate origin IPs after any CDN cutover so historical DNS does not point to the live host.
- Use unique TLS certs at origin (private CA, or cert without target hostname SAN) so Censys searches cannot pivot.
- Normalise cache keys: include every header that influences response generation, or strip influence at the edge. See [[cache-poisoning-modern-chains]].
- Subdomain hygiene: do not leave `direct.`, `origin.`, `cpanel.`, `mail.` records pointing at the origin.
- Monitor for direct-IP HTTP requests bypassing the edge: SIEM rule on origin web logs where `Host` is target hostname but TLS SNI is the IP or missing.

## Workflow to study

1. Pick a target known to use Cloudflare or Akamai (HackerOne scope, your own lab via [[building-a-research-home-lab]]).
2. Inventory all subdomains via [[expanding-attack-surface]] techniques.
3. Pull DNS history (SecurityTrails free tier), CT logs (crt.sh), favicon hash (Shodan).
4. Score candidate origin IPs by:
   - Returns target HTML on `curl --resolve`.
   - TLS cert SAN includes target hostname.
   - ASN is not the CDN.
5. For each confirmed origin, probe header-trust: send `X-Forwarded-For: 127.0.0.1` direct and observe behaviour vs through edge.
6. Compare WAF behaviour: send a benign-looking but WAF-blocked payload (large `Content-Length`, unicode in path) through edge vs direct.
7. If cacheable, attempt [[cache-poisoning]] using unkeyed headers identified by [Param Miner](https://portswigger.net/bappstore/17d2949a985c4b7ca092728dba871943).
8. Document the chain end-to-end for [[report-writing-for-pentesters]]; impact framing must show that the CDN protections are not protecting anything: see [[demonstrating-impact]].
9. Cross-reference with [[case-study-orange-tsai-research-pattern]] for header-and-cache combo tradecraft.

## Related

- [[waf-bypass-research-deep]]
- [[waf-bypass-advanced-techniques]]
- [[waf-bypass]]
- [[cache-poisoning-modern-chains]]
- [[cache-poisoning]]
- [[cache-deception]]
- [[http-smuggling-modern-variants]]
- [[http-request-smuggling]]
- [[host-header-injection]]
- [[ssrf]]
- [[domain-fronting-and-cdn-abuse]]
- [[cloudflare-tenant-attacks]]
- [[cloudflare-workers-audit]]
- [[vercel-edge-and-middleware-audit]]
- [[dnssec-misconfig-attacks]]
- [[bgp-hijack-attacks]]
- [[expanding-attack-surface]]
- [[case-study-orange-tsai-research-pattern]]
- [[case-study-portswigger-top-10-pattern]]

## References

- [Cloudflare: Restoring original visitor IPs](https://developers.cloudflare.com/support/troubleshooting/restoring-visitor-ips/restoring-original-visitor-ips/)
- [Akamai: True-Client-IP header documentation](https://techdocs.akamai.com/property-mgr/docs/true-client-ip-header)
- [Fastly: Cache and origin shielding](https://www.fastly.com/documentation/guides/concepts/shielding/)
- [PortSwigger: Practical Web Cache Poisoning (James Kettle)](https://portswigger.net/research/practical-web-cache-poisoning)
- [CloudFlair: research project for finding origin servers behind Cloudflare](https://github.com/christophetd/CloudFlair)
- [Detectify Labs: Hunting for origin servers behind CDNs](https://web.archive.org/web/2024/https://labs.detectify.com/2019/07/31/bypassing-cloudflare-waf-with-the-origin-server-ip-address/)
