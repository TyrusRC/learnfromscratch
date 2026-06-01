---
title: HTTP enumeration
slug: http-enum
---

> **TL;DR:** Vhost + path discovery, server/framework fingerprinting, and tuning your wordlist with status-code/content-length filters — the difference between finding `/admin` and finding the actual one mounted at `/internal/admin-v2`.

## What it is
HTTP enumeration covers everything between "there is a webserver on port 443" and "here is the attack surface." Three axes: which *hosts* the server answers for (vhosts via Host header / SNI), which *paths* exist (fuzzing wordlists vs sitemap/robots/JS reads), and *what's running* (server header, response idiosyncrasies, favicon hash, JS framework detection). The goal is a tight inventory of endpoints to feed into auth bypass, parameter discovery, and vuln-specific tests.

## Preconditions / where it applies
- Network reachability to the target on 80/443/8080/etc.
- For vhost discovery: knowledge of at least one domain pointing at the IP, or wildcard DNS.
- For internal enumeration: a pivot ([[ligolo-ng]], SOCKS proxy) and DNS resolution into the segment.

## Technique
1. Fingerprint the stack and capture all surface from the response.
2. Discover vhosts on the same IP.
3. Fuzz paths and parameters with feedback-driven filtering.

```bash
# Fingerprinting
whatweb https://target.tld
httpx -u https://target.tld -title -tech-detect -status-code -tls-grab -ip
nuclei -u https://target.tld -t http/technologies/
curl -sI https://target.tld && curl -sk https://target.tld/robots.txt
```

```bash
# Vhost discovery via Host-header fuzz
ffuf -w subs.txt -u https://target.tld/ -H "Host: FUZZ.target.tld" -fs 0 -mc all -ac
gobuster vhost -u https://target.tld -w subs.txt --append-domain
```

```bash
# Path fuzz with smart filters
ffuf -w raft-large-directories.txt -u https://target.tld/FUZZ \
     -fc 404,400 -ac -mc all -of json -o paths.json
feroxbuster -u https://target.tld -w common.txt -x php,aspx,js -C 404
katana -u https://target.tld -jc -kf all                       # crawl + JS endpoint extraction
```

Pull endpoints out of JS bundles (`linkfinder`, `katana -jc`), check `/.well-known/`, `/sitemap.xml`, `/swagger`, `/openapi.json`, `/graphql`, `/.git/HEAD`, `/.env`, `/server-status`. Favicon hash (`mmh3`) clusters look-alike apps with Shodan / Censys. Differential status codes + content-length give signal even when 200 OK is the default for unknown paths.

## Detection and defence
- WAF/IDS detects high-rate path fuzz; attackers slow-roll and rotate user agents / IPs.
- Reduce surface: serve unique 404s, disable directory listing, lock `/.git`, separate admin vhosts behind mTLS.
- Log Host-header anomalies, especially vhost-fuzz patterns (`FUZZ.*` and rapid header rotation).
- Related: [[dns-enum]], [[ligolo-ng]].

## References
- [HackTricks — Pentesting Web](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/index.html) — broad endpoint and fingerprint reference.
- [ProjectDiscovery — httpx, nuclei, katana](https://github.com/projectdiscovery) — modern HTTP recon toolkit.
- [ffuf documentation](https://github.com/ffuf/ffuf) — filter modes (`-fc`, `-fs`, `-ac`) that make fuzz output usable.
