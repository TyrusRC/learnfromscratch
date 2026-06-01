---
title: Wordlist fuzzing tactics
slug: wordlist-fuzzing-tactics
---

> **TL;DR:** Pick wordlists by tech-stack fingerprint, filter by content-length and response-hash to fight false positives, recurse on 200/403 directories only, and rotate user-agent + source IP when a WAF starts dropping you. Wordlist choice does more than wordlist size.

## What it is
A wordlist is the search space for content discovery. The right list at the right depth surfaces real endpoints fast; the wrong list pumps thousands of useless requests and trains the WAF to block you. Tactics make the difference between "I ran ffuf and got nothing" and "I found `/api/internal/v2/admin/users` in 4 minutes."

## Preconditions / where it applies
- Active probing allowed by program rules
- Tech stack identified ([[tech-stack-fingerprinting]]) so you can match list to framework
- Baseline established — what does a known-bad path return ([[content-discovery]])

## Technique
1. Match wordlist to stack:
   - Java / Spring → `WEB-INF`, `META-INF`, `actuator/*`, `*.do`, `*.jsp`
   - Node / Express → `package.json`, `node_modules`, `.env`, `routes/`
   - PHP / WordPress → `wp-admin`, `wp-content`, `xmlrpc.php`, `*.php`
   - Python / Django → `admin/`, `static/admin`, `__debug__/`
   - .NET → `Trace.axd`, `elmah.axd`, `bin/`, `App_Code/`
   - Generic → SecLists `Discovery/Web-Content/raft-*`, `directory-list-2.3-*`
2. Layer the lists. Start small, escalate:
   - Layer 1: 1k common paths (`raft-small-words.txt`)
   - Layer 2: stack-specific list against directories found in L1
   - Layer 3: parameter mining on found endpoints
3. Filter aggressively to keep signal high:

```
ffuf -w wordlist.txt -u https://target.tld/FUZZ \
     -mc all -fc 404 -ac \
     -fs 1234       # filter by exact body size when baseline known
     -fr 'Not Found' # filter by regex in response
```

`-ac` auto-calibrates against a fake path so soft-404s get filtered.
4. Recurse selectively. Auto-recurse on every 200 explodes traffic. Manual recurse on directories that smell like apps:

```
# initial pass returns /admin/ as 403 -> recurse with admin-specific list
ffuf -w admin-paths.txt -u https://target.tld/admin/FUZZ -recursion-depth 2
```

5. WAF evasion within program rules:
   - Rotate `User-Agent` per batch (`-H "User-Agent: ..."` with multiple values)
   - Add benign headers (`Accept`, `Accept-Language`) so requests look browser-ish
   - Slow the rate (`-rate 20`) — WAFs threshold on RPS
   - Source-IP rotation via cloud egress or rotating SOCKS (only if allowed)
6. Mine for parameters once you have endpoints:

```
# common parameter list against a known endpoint
ffuf -w params.txt -u https://target.tld/api/profile?FUZZ=test -fs 1234
```

7. Extension fuzzing for source-leak. Append `.bak`, `.old`, `.swp`, `~`, `.orig`, `.zip` to known paths to catch leaked source archives.

## Detection and defence
- WAF: rate-limit per source, alert on 4xx burst patterns characteristic of wordlist scans (high path entropy, low session reuse)
- Customise 404 pages to return identical body+headers for missing files whether the parent directory exists or not (kills soft-404 detection)
- Block known sensitive patterns at the edge (`*.bak`, `*.swp`, `.git/`, `.env`)
- For hunters: keep a personal "tactics" wordlist per program — paths that worked on similar stacks compound across targets

## References
- [SecLists](https://github.com/danielmiessler/SecLists) — canonical wordlist collection
- [ffuf docs](https://github.com/ffuf/ffuf) — filtering, matching, recursion modes
- [Assetnote wordlists](https://wordlists.assetnote.io/) — curated by tech stack
- [HackTricks — Content discovery](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/index.html) — flags and filter patterns
