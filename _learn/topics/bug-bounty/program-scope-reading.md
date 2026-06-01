---
title: Program scope reading
slug: program-scope-reading
---

> **TL;DR:** Read the scope page like a contract — the asset list, the exclusions, the testing-allowed clauses, and especially what is implicitly in scope via wildcards.

## What it is
Every bounty program publishes a scope: in-scope assets, out-of-scope assets, allowed testing techniques, severity guidance, and disclosure rules. Sloppy reading is the single biggest cause of N/A reports, bans, and unpaid valid bugs. The scope page is both a permission slip and a hunting map — it tells you what to look at *and* gives away which surfaces the program already considers high-risk.

## Preconditions / where it applies
- Any in-platform or in-house program with a published policy
- New programs (read in full) and old programs that just updated (re-read the diff)
- Always before [[target-selection-heuristics]] and [[program-selection-tactics]]

## Technique
Walk every clause and translate it into hunter actions:
1. **Asset list.** Distinguish exact assets (`api.target.tld`) from wildcards (`*.target.tld`). Wildcards include any subdomain you can prove the program owns — drives [[reverse-whois]], [[certificate-transparency]], and [[acquisitions-recon]] expansion.
2. **Exclusions.** Often list "*.thirdparty-vendor.tld" — those are off-limits even if they technically resolve under the target. Marketing subdomains hosted on Marketo/Pardot are typically out of scope; do not waste time.
3. **Allowed testing.** Look for explicit permission for: automated scanning, brute force, social engineering (almost never), DDoS testing (almost never), credential stuffing. Default-deny everything not explicitly allowed.
4. **Severity guidance and payout table.** Maps to whether a finding is worth pursuing. SSRF that only hits internal-network metadata might be capped at Medium if the program documents that.
5. **Safe harbor / legal language.** Confirm the program uses ISO-29147-aligned safe-harbor (disclose.io text is a common template). Without it, you have no protection against a CFAA-style threat.
6. **Reporting requirements.** Some programs require: video PoC, fresh-account-only testing, no third-party tools, no sub-second rate. Violations are auto-N/A regardless of severity.
7. **Out-of-band attack surface.** Programs that list mobile apps but not the APIs they call almost always mean both — APIs are implicitly in scope through the app. Document the inference and confirm with triage before relying on it.
8. **Change-tracking.** Save the scope as text/diff today; check monthly. Newly-added assets are competitive — hunters who watch the diff get the first crack.

## Detection and defence
- Programs measure per-hunter "scope compliance" — out-of-scope reports degrade your reputation score
- For the defender: keep scope page versioned in a public commit log; ambiguity gets exploited both ways
- For the hunter: when in doubt, ask via the platform's "scope question" feature before testing — a 24h delay beats a permanent ban

## References
- [disclose.io safe-harbor templates](https://disclose.io/terms/) — modern scope/policy language
- [HackerOne policy guide](https://docs.hackerone.com/en/articles/8410870-disclosure-guidelines) — platform-side scope expectations
- [Bugcrowd VRT](https://bugcrowd.com/vulnerability-rating-taxonomy) — how scope severity maps to payouts
