---
title: Automated fuzzer-driven discovery
slug: automated-fuzzer-vuln-discovery
---

> **TL;DR:** Run nuclei, ffuf, dirsearch, and custom scripts continuously across your asset graph and alert only on diff. Volume + diffing is how you catch the n-day window before duplicates flood in.

## What it is
Automated discovery is the bottom layer of a bug-bounty pipeline — high-volume, low-precision scans that surface "something changed" or "something matches a known signature." It doesn't replace manual hunting; it produces leads that manual hunting then triages. Paired with [[continuous-recon-automation]], it's how solo hunters cover programs at corporate-pentest scale.

## Preconditions / where it applies
- You have an asset graph maintained by continuous recon (live hosts, ports, tech stack, last-seen)
- Programs that allow automated scanning (most do; some explicitly forbid scanner traffic — read the rules)
- Templates / wordlists tuned to the target stack (Ruby on Rails program ≠ generic PHP wordlist)

## Technique
1. Layer the pipeline. Each layer narrows what the next sees.

```
subdomains -> httpx (live) -> tech fingerprint -> nuclei (signatures)
                                              \-> ffuf (content)
                                              \-> custom scripts (param mining)
```

2. Nuclei for known signatures and misconfigs. Group templates by tag and severity; don't blast every template at every host:

```
nuclei -l live.txt -tags exposure,cve,misconfig -severity high,critical \
       -rate-limit 50 -o nuclei.out -json
```

3. Content discovery against routes that actually exist — feed `httpx` output into `ffuf` with a wordlist sized to the tech stack ([[wordlist-fuzzing-tactics]]):

```
ffuf -w wordlist.txt -u https://FUZZ.target.tld/ -mc 200,301,401,403 -ac
```

4. Custom probes for things off-the-shelf scanners miss — leaked `.git/HEAD`, `swagger.json`, `.env.bak`, GraphQL introspection on `/graphql`. Wrap them in a single shell function and run nightly.
5. Diff, don't alert on raw output. Persist last-run results per host; alert only when the response hash, status, or content-length changes. This kills 99% of noise.

```
# pseudo: hash response, compare to yesterday's
sha256(body) != yesterday(host) -> push to triage queue
```

6. Triage queue is the human surface. Each lead gets ~30 seconds — reject duplicates, false-positives, out-of-scope; promote real candidates to manual hunting.

## Detection and defence
- WAFs will rate-limit you; rotate source IPs (cloud egress, residential proxies) within rules of engagement
- Defenders see scanner UAs (`Nuclei/...`, `ffuf/...`) and template fingerprints in WAF logs — change UA if you want to stay quiet, but quiet ≠ allowed
- Blue team should run the same nuclei templates internally on a schedule and fix matches before bounty hunters report them
- Audit log volume spikes per minute correlated with subdomain enumeration patterns are a reliable scanner signal

## References
- [Nuclei templates repo](https://github.com/projectdiscovery/nuclei-templates) — community signatures, browse by tag
- [ProjectDiscovery blog — automation patterns](https://blog.projectdiscovery.io/) — pipeline examples
- [HackTricks — Pentesting Methodology](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/pentesting-methodology.html) — where automation fits
