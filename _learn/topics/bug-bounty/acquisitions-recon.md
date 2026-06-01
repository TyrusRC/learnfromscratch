---
title: Acquisitions recon
slug: acquisitions-recon
---

> **TL;DR:** Mine corporate filings, press releases, and funding databases to discover sibling brands and acquired companies that frequently inherit the parent's bug-bounty scope.

## What it is
Large programs that say "any asset owned or operated by $COMPANY" implicitly include every subsidiary the legal entity controls. Most hunters stop at the apex domain and never enumerate the corporate tree. Acquisitions recon flips that — you map M&A history to product names to apex domains, then run normal subdomain workflows on each.

## Preconditions / where it applies
- Program scope explicitly includes "subsidiaries", "acquired companies", or a wildcard on `*.parent.tld` plus owned brands
- Parent is a public company, a well-funded private one, or a serial acquirer (fintech, big tech, ad-tech)
- You have time to invest in horizontal recon before competing on the crowded primary domain

## Technique
1. Build a corporate tree from primary sources before searching domains.

```
# US-listed parents — pull Exhibit 21 (subsidiaries) from the latest 10-K
https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK=<cik>&type=10-K
```

2. Cross-reference with funding / M&A databases:
   - Crunchbase `/acquisitions` tab on the parent
   - `https://www.cbinsights.com/`, `https://pitchbook.com/` (paid, but free tier surfaces names)
   - Wikipedia infobox + "List of mergers and acquisitions by X" pages
3. For each subsidiary name, find its primary domain:
   - Google `"<sub> acquired by <parent>"` and `<sub> site:linkedin.com/company`
   - Reverse-WHOIS lookups on the parent's known org name and registrant email (see [[reverse-whois]])
   - Favicon / analytics-tag pivots from the parent (see [[analytics-tag-correlation]])
4. Push each apex through your normal pipeline — CT logs, ASN, perm wordlists ([[certificate-transparency]], [[asn-enumeration]], [[subdomain-permutation]]).
5. Tag every host with the subsidiary it belongs to. When you find a bug on `legacy-startup.com`, the report needs to prove ownership — link the SEC filing or press release in the repro.

```
# whoxy reverse-whois by org (free credits)
curl "https://api.whoxy.com/?key=$K&reverse=whois&company=ParentCorp"
```

## Detection and defence
- Parent security teams rarely have an asset inventory that covers post-acquisition infra; the acquired brand's old CI / staging is the soft underbelly
- Defenders should subscribe their VDP to a feed of newly registered / transferred domains under the corporate org and force every M&A integration through a security review
- Watch for hunters submitting bugs on hosts the team doesn't recognise — that's a sign your asset inventory is stale

## References
- [SEC EDGAR full-text search](https://efts.sec.gov/LATEST/search-index?q=%22subsidiaries%22&forms=10-K) — Exhibit 21 lists every subsidiary
- [HackTricks — External Recon Methodology](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — acquisitions + reverse-whois pivots
- [zseano methodology](https://www.bugbountyhunter.com/methodology/) — horizontal scope expansion in practice
