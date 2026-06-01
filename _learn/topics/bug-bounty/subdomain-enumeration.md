---
title: Subdomain enumeration
slug: subdomain-enumeration
---

> **TL;DR:** Combine passive sources (CT, third-party DBs, search engines) with active DNS brute force and permutation, dedupe, then prune to alive hosts — the canonical recon spine.

## What it is
Subdomain enumeration finds every hostname under a target apex. Wider attack surface means more endpoints to probe, more forgotten services to find, and more chances a developer left a Jenkins exposed. No single technique is complete — passive misses internal-only brute candidates, active misses anything that requires CT log knowledge — so the discipline is layering and deduping.

## Preconditions / where it applies
- A target apex (or list of apexes from [[reverse-whois]] / [[acquisitions-recon]])
- A solid DNS resolver list (trickest/resolvers, public + private) so active brute does not collapse on rate-limited 8.8.8.8
- An hour of compute for a normal target; longer for `*.amazonaws.com`-style giants

## Technique
A four-stage pipeline:

1. **Passive sources.** Free, scope-friendly, zero traffic to target.
   ```
   subfinder -d target.tld -all -silent > passive.txt
   amass enum -passive -d target.tld -o amass.txt
   ```
   Sources include [[certificate-transparency]] logs, Project Sonar, VirusTotal, AlienVault OTX, search engines, Wayback. Add [[google-dorking]] and [[github-recon]] outputs.

2. **Active brute force.** DNS brute against curated wordlists. Use a fast resolver pool and a known-good list:
   ```
   puredns bruteforce all.txt target.tld -r resolvers.txt -w brute.txt
   ```
   Wordlist sources: `assetnote/wordlists`, `n0kovo_subdomains`, `commonspeak2`. Layer small (best.txt, ~5k) before large (all.txt, ~10M).

3. **Permutation.** Generate candidates from known subdomains and re-resolve. Catches `api-staging`, `api2`, `dev-api`, naming conventions specific to the target. See [[subdomain-permutation]].
   ```
   alterx -l found.txt | puredns resolve -r resolvers.txt -w perm.txt
   ```

4. **Dedupe + alive-prune.** Sort, unique, then probe with httpx for HTTP services. CNAME-chain resolution is essential for [[cloud-asset-recon]] takeover detection.
   ```
   sort -u passive.txt brute.txt perm.txt | dnsx -resp -silent | httpx -silent -title -tech-detect -o live.json
   ```

5. **Validate scope** against the program ([[program-scope-reading]]) before treating any subdomain as in-scope, especially anything resolving to a third-party PaaS.

Loop the entire pipeline on a schedule ([[continuous-recon-automation]]) and alert only on new entries.

## Detection and defence
- Passive sources leave no target-side signal; active brute spikes authoritative DNS query volume (target's NS will see it)
- Defenders should monitor authoritative DNS for `NXDOMAIN` floods, audit zone exposure, and avoid predictable internal-naming conventions
- For the hunter: brute against the target's own authoritative NS rather than recursors is often faster but also more visible — balance per program

## References
- [projectdiscovery/subfinder](https://github.com/projectdiscovery/subfinder) — best-in-class passive enumerator
- [d3mondev/puredns](https://github.com/d3mondev/puredns) — DNS brute with built-in wildcard handling
- [HackTricks subdomain enumeration](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — broader recon flow
