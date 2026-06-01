---
title: Subdomain permutation
slug: subdomain-permutation
---

> **TL;DR:** Take known subdomains as seeds, mutate them into new plausible candidates (`gotator`, `altdns`, `dnsgen`, `regulator`), then resolve at scale. Catches subdomains that wordlist brute-force misses because they follow the org's internal naming conventions.

## What it is
Passive sources ([[certificate-transparency]]) give you a seed list. Wordlist brute-force gives you common patterns. Permutation fills the gap in between — generating candidates that look like the seeds (`dev-api-v2.target.tld`, `api-v3.target.tld`, `staging-api-v2.target.tld`) and resolving them. It's the highest-yield active-DNS technique for mature targets where common wordlists are already exhausted.

## Preconditions / where it applies
- You have a seed list of 20+ known subdomains from passive sources
- You can resolve at high QPS (parallel resolvers, public DNS, no aggressive rate-limiting at your end)
- Wildcard DNS detection in place (target may return any subdomain as valid; permutation against wildcards is useless without filtering)

## Technique
1. Build a clean seed set. Deduplicate, strip the apex, normalise case:

```
api.target.tld
api-v2.target.tld
dev.target.tld
dev-api.target.tld
staging-api.target.tld
```

2. Run permutation. Different tools use different mutation strategies:

```
# gotator — pattern-based, controllable depth
gotator -sub seeds.txt -perm common.txt -depth 1 -mindup > candidates.txt

# altdns — alteration patterns (add/replace/insert)
altdns -i seeds.txt -o candidates.txt -w altdns/words.txt

# regulator — learns patterns statistically from seeds (no wordlist)
python3 main.py -t target.tld -f seeds.txt -o candidates.txt
```

3. Resolve candidates in parallel. `puredns`, `massdns`, or `shuffledns` against a resolvers file:

```
puredns resolve candidates.txt -r resolvers.txt --wildcard-tests 10 \
        --wildcard-batch 100000 -w resolved.txt
```

4. Filter wildcards. Many CDNs return a default IP for any subdomain — `*.target.tld → 1.2.3.4`. Either drop everything resolving to a known wildcard IP or post-filter by HTTP response hash via `httpx`.
5. Repeat. The newly discovered subdomains become seeds for the next pass (cap at 2-3 iterations; returns diminish fast and traffic grows linearly).
6. Track in the asset graph ([[asset-graphing]]) and feed live hosts into [[content-discovery]] and [[tech-stack-fingerprinting]].

```
# minimal pipeline
seeds.txt -> gotator -> candidates.txt -> puredns -> resolved.txt
         \                                       \-> httpx -> live.txt
```

## Detection and defence
- Authoritative DNS sees enormous NXDOMAIN bursts; log and alert on QPS spikes from any single resolver
- Don't follow predictable naming conventions for sensitive subdomains — `admin-secret-app-v2` is permutable from `app-v2`
- Restrict access to internal-only subdomains by VPN / IP allowlist, not by hoping nobody guesses the name (security by obscurity)
- If you must expose dev / staging hostnames externally, randomise the suffix (UUID) so they don't appear in permutation output

## References
- [gotator](https://github.com/Josue87/gotator) — pattern-driven permutation generator
- [altdns](https://github.com/infosec-au/altdns) — alteration patterns
- [regulator](https://github.com/cramppet/regulator) — learns regex grammar from seeds
- [puredns](https://github.com/d3mondev/puredns) — high-speed resolver with wildcard handling
- [HackTricks — DNS bruteforce + permutations](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — workflow refs
