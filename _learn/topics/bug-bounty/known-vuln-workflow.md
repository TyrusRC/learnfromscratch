---
title: Known-vulnerability workflow
slug: known-vuln-workflow
---

> **TL;DR:** Fingerprint the tech and exact version, search CVE / Exploit-DB / GitHub / vendor advisories, adapt the public PoC, verify against the target — fastest reliable path from "what does this run?" to "here is impact".

## What it is
The disciplined workflow for finding and weaponising public vulnerabilities against a specific target. It is the foundation of [[n-day-rapid-exploitation]] but applies any time fingerprinting reveals a versioned product. Done well, it converts external-facing tech version strings into reproducible bugs without writing new exploit code.

## Preconditions / where it applies
- A target host with identifiable software (banner, headers, JS bundle, favicon hash, login page)
- Program scope that permits exploitation of disclosed CVEs (most do; double-check [[program-scope-reading]])
- Access to public references (NVD, vendor advisories, GitHub) — no paid feeds required

## Technique
1. **Fingerprint precisely.** Tech + version, not just tech. Stack the evidence:
   - HTTP headers (`Server`, `X-Powered-By`, `X-Generator`)
   - Favicon mmh3 hash via httpx
   - HTML meta `generator` tag
   - Specific JS bundle filenames
   - Login page revisions / image hashes
   See [[tech-stack-fingerprinting]] for the toolkit.
2. **Map version to CVEs.** Query in this order — each filters out noise from the previous:
   - NVD CPE search: `cpe:2.3:a:vendor:product:VERSION:*`
   - Vendor security advisory / changelog (the canonical source — vendor blog often has more detail than NVD)
   - GitHub Security Advisories (GHSA) and Dependabot alerts repo
   - Exploit-DB, packetstorm, sploitus
3. **Pick a candidate.** Prefer authenticated-first CVEs only if you already have creds; otherwise unauth pre-auth bugs. Rank by: severity, public PoC availability, complexity, and whether a Metasploit/nuclei template exists.
4. **Read the advisory and PoC together.** Confirm prerequisites (specific config, enabled module, exposed admin path). Many public PoCs work only against a narrow build — checking before you fire saves bans.
5. **Verify safely.** Start with a non-destructive probe — a version-check via the bug's primary primitive (e.g., SSRF that reads a public file, RCE that runs `id`). Never run destructive payloads on production. Capture request/response artefacts for the report.
6. **Adapt to the target.** Most PoCs need path or parameter changes — endpoint moved, CSRF token added, prefix renamed. Read source diffs in the vendor commit that fixed the CVE — they show the exact code path.
7. Document in your notes ([[note-taking-while-hacking]]) for re-use across programs that share the same stack.

## Detection and defence
- Public CVE exploitation is the most-instrumented attacker behaviour — EDR, WAF, and IDS vendors push signatures within hours of disclosure
- Defenders should subscribe to vendor advisories for everything in their SBOM and patch on a 7-day SLA for critical CVEs
- For the hunter: assume the target has IDS for known-CVE patterns; alter encoding, path casing, and User-Agent to slip past trivial signatures while keeping the PoC intact

## References
- [NVD CVE search](https://nvd.nist.gov/vuln/search) — authoritative CVE/CPE index
- [Exploit-DB](https://www.exploit-db.com/) — public PoC repository
- [GitHub Security Advisories](https://github.com/advisories) — modern open-source CVE feed with patch links
