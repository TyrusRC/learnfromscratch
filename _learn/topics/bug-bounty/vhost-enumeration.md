---
title: VHost enumeration
slug: vhost-enumeration
---

> **TL;DR:** When one IP serves many sites, the chosen Host header decides which one — brute the Host with ffuf and watch for unique response sizes or status codes to find hidden virtual hosts.

## What it is
HTTP virtual hosting maps multiple hostnames to the same IP and port; the server's reverse proxy uses the `Host` header (or SNI for TLS) to pick a backend. Internal admin panels, staging copies of production, and tenant-specific instances are routinely deployed as separate vhosts on the same edge that publicly hosts the marketing site. Standard subdomain enumeration ([[subdomain-enumeration]]) misses these because their DNS records are private — only the `Host` brute reveals them.

## Preconditions / where it applies
- One or more target IPs that serve HTTP/HTTPS
- A baseline response (size, status, title) for an "unknown host" request — that is your filter
- Useful after DNS subdomain enumeration plateaus or against bastion / shared edge IPs

## Technique
1. **Establish a baseline.** Hit the IP with a bogus Host and record the response length and status:
   ```
   curl -sk -o /dev/null -w "%{http_code} %{size_download}\n" \
     -H "Host: nonexistent.invalid" https://1.2.3.4/
   ```
2. **Brute the Host header.** ffuf is the workhorse. Filter out responses that match the baseline.
   ```
   ffuf -u https://1.2.3.4/ -H "Host: FUZZ.target.tld" \
     -w wordlist.txt -fs 1234 -mc all -ac
   ```
   `-fs 1234` filters the baseline size; `-ac` auto-calibrates; swap to `-fc 404` if status differs.
3. **Try multiple base apexes.** Internal hosts may not be under the public apex — try `*.target-corp.internal`, `*.target.local`, common dev TLDs, the org's IT naming scheme. Pull names from leaked configs / GitHub for high-yield candidates.
4. **Walk SNI separately for HTTPS.** Some reverse proxies route on SNI before `Host`; mismatches between SNI and Host header sometimes reach a backend the proxy intended to hide. Test both:
   ```
   curl -k --resolve hidden.target.tld:443:1.2.3.4 https://hidden.target.tld/
   ```
5. **Pivot found vhosts.** Once a hidden host responds, run [[content-discovery]] and [[endpoint-spidering]] against it. Internal admin vhosts often skip the rate limits the public side enforces.
6. **Wordlist sources.** Reuse subdomain wordlists; append common internal prefixes (`admin`, `internal`, `corp`, `vpn`, `jenkins`, `git`, `monitoring`). Permutations from [[subdomain-permutation]] also work as vhost candidates.

## Detection and defence
- Defenders see a single source IP cycling through Host headers — easy to log and rate-limit at the edge
- Reverse proxies should return a fixed 404 (not the backend default) for unknown hosts so brute responses are indistinguishable
- For the hunter: throttle requests, randomise Host candidate order, and pause when the edge starts returning 503s — sustained scanning gets blocked

## References
- [ffuf documentation](https://github.com/ffuf/ffuf) — the standard Host-header fuzzer
- [HackTricks virtual host pentesting](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/index.html) — vhost discovery in the wider web flow
- [OWASP WSTG — Identify Application Entry Points](https://owasp.org/www-project-web-security-testing-guide/stable/4-Web_Application_Security_Testing/01-Information_Gathering/06-Identify_Application_Entry_Points) — entry-point mapping context
