---
title: Keeping up with research — a feed pipeline
slug: keeping-up-with-research-feeds
aliases: [research-feeds, security-news-pipeline, infosec-rss]
---

> **TL;DR:** A serious practitioner spends 30 minutes a day on intake — not on Twitter, but on a curated feed of RSS, mailing lists, GitHub releases, advisory portals, and a small list of researcher blogs. The pipeline filters noise; the daily slot triages signal into "read now / weaponise this week / skim later / archive". Build it once, prune monthly.

## The intake stack

Four layers, in this order of signal density:

1. **Vendor security advisories** — the ground truth. Microsoft MSRC, Cisco PSIRT, Fortinet PSIRT, RedHat, Ubuntu, Debian, Apache. RSS / mailing list.
2. **CVE feeds** — NVD JSON feed, GitHub Security Advisories, CISA KEV.
3. **Researcher blogs** — 20–40 RSS feeds of people you've vetted (see list below). Avoid the firehose.
4. **Social** — Twitter / Bluesky / Mastodon for *signals* you'll then chase in the above. Treat as discovery, not consumption.

Skip everything else. News aggregators (Bleeping, The Hacker News, etc.) are downstream of the above with worse timing.

## A starter feed list

Researcher / org blogs worth tracking:

- **Project Zero** (Google) — root cause + exploit chains.
- **MSRC** — Microsoft advisories.
- **Project Discovery blog** — Nuclei templates + n-day analysis.
- **watchTowr Labs** — appliance n-day.
- **AssetNote** — variant hunting + appliance vulnerabilities.
- **Synacktiv** — Pwn2Own writeups.
- **Horizon3.ai** — n-day / appliance writeups, attacker mindset.
- **Orange Tsai (devco.re, blog.orange.tw)** — request smuggling, framework bugs, SSRF.
- **PortSwigger Research** — annual top-10 web research.
- **Snyk Security Labs** — JavaScript / supply chain.
- **GitHub Security Lab** — code-audit-quality writeups.
- **JFrog Security Research** — package ecosystem supply chain.
- **Ret2 Systems**, **Hex-Rays blog** — RE / fuzzing.
- **Trail of Bits** — appsec, blockchain, ML.
- **Cisco Talos**, **Mandiant**, **Volexity** — APT TTPs and zero-day in-the-wild.
- **ZDI (Zero Day Initiative)** blog + Pwn2Own writeups.
- **NCC Group**, **Doyensec**, **Include Security** — applied research.
- **Specter Ops** — AD / identity / Bloodhound.
- **dirkjanm.io** — AD CS / cross-tenant / Entra.
- **Bohops**, **Outflank**, **MDSec** — Windows tradecraft.

CTI / vulnerability-trend signal:

- **CISA KEV** — known exploited.
- **Volexity / Mandiant blogs** — what's actually being used by APTs.
- **inthewild.io** — community-curated KEV equivalent.

CTF / pwn signal:

- **Real World CTF** writeups.
- **DEFCON CTF** finalists' team blogs.
- **pwn.college** lectures (good for foundations).

The list is intentionally short. Add only after you read someone's archive and find at least three pieces worth keeping.

## RSS over social

RSS is unilaterally better than Twitter for intake:

- No algorithm.
- Reverse chronological.
- Read-when-you-want, not read-now-or-miss.
- Easy to mute / unsubscribe noisy sources.

Use FreshRSS, Miniflux, NetNewsWire, or Feedbin. Mirror in an offline reader if you read on a phone.

For sites without RSS, build a feed from a `git log` (GitHub releases), a regex over a vendor advisory page, or a `gh search` query.

## Twitter / Bluesky as discovery only

- Follow ~50 researchers, no more.
- Use lists ("0day-people", "appsec", "cloud") to switch contexts.
- Don't read the home feed; read the lists.
- When someone tweets an interesting thing, **don't reply, don't quote-tweet — open the linked blog and read it cold**, then decide if you want to follow.
- Mute keywords: politics, generic "AI" hype, vendor marketing.

If reading Twitter feels like work, your follow list is bad. Prune.

## The daily 30-minute triage

Pick a slot. Same time every day. Open your feed reader and triage:

- **Read now** — direct relevance to a current target or class you're studying.
- **Weaponise this week** — n-day with public PoC, on a product in your scope. Move to your TODO.
- **Skim later** — interesting but not actionable; save with a tag.
- **Archive** — read the headline only; you now know it exists. Move on.

After triage, *close the reader*. Don't drift into reading-everything mode; that's how the day disappears.

## CVE / advisory specifics

The most useful feeds for n-day work:

- **NVD JSON feeds** — `nvd.nist.gov/vuln/data-feeds`. Granular and machine-readable.
- **GitHub Security Advisories** — `github.com/advisories`. Has a useful RSS and a graphql API.
- **CISA KEV catalog** — `cisa.gov/known-exploited-vulnerabilities-catalog`. RSS available.
- **EPSS** — exploit-prediction scoring system. Useful as a prioritisation tiebreak.
- **Vulnerability-Lookup**, **inthewild.io** — community KEV-equivalents.

A small script that posts new KEV entries to a personal channel is high ROI.

## Reading research papers

For academic / longer work:

- **USENIX Security** / **Black Hat** / **DEF CON** / **CCS** / **NDSS** / **S&P** — flagship venues.
- **arXiv.cs.CR** — preprints (filter; lots of noise).
- **Pwn2Own contest reports** — short, dense, recent.

You don't need to read every paper. Read every *abstract* in a venue's archive once a year and pull a few full reads.

## Track the meta — bug-class trends

Once a quarter, look back at your triage notes and ask:

- Which **classes** appeared most this quarter? (Often a new framework's bug pattern goes industry-wide for a quarter.)
- Which **products** had recurring patches? (Repeat-CVE products are often un-derstudied.)
- Which **researchers** had the highest hit rate?

This shifts your study plan ahead of the curve.

## Anti-patterns

- **Subscribing to 200 feeds**. You'll skim none well. Prune to 40.
- **Reading every comment thread**. The comments add nothing the post doesn't.
- **Bookmarking without revisiting**. Either move to TODO or archive — don't accumulate "read later" without a review slot.
- **Doomscrolling at end-of-day**. You can't act on it; you just deplete tomorrow's focus.

## Tools

- **FreshRSS / Miniflux** — self-hosted RSS.
- **NetNewsWire / Feedbin / Reeder** — clients.
- **`gh api`** — programmatic advisory queries.
- **CVE-Search / vulncheck** — local CVE database.
- **`watchtowr alerts`** — community curated.

## References
- [Project Zero blog](https://googleprojectzero.blogspot.com/)
- [CISA KEV](https://www.cisa.gov/known-exploited-vulnerabilities-catalog)
- [PortSwigger Research](https://portswigger.net/research)
- [GitHub Advisory Database](https://github.com/advisories)
- See also: [[reading-public-pocs-effectively]], [[one-day-from-patch-diff]], [[recent-cve-class-overview]], [[known-vuln-workflow]]
