---
title: Guide
icon: fas fa-compass
order: 2
permalink: /guide/
toc: true
---

> **TL;DR.** Offensive security is too big to master. This hub is a
> second brain: paths give you order, atomic topic notes give you
> queryable depth, and references point at the deeper sources. Pick
> one path, accept you'll forget 50% of what you read, and keep
> showing up.

## Who this is for

- **Novices** building their first mental model — you need a single
  ordered route, not 200 tabs.
- **Mid-career** practitioners sliding into a new domain — you already
  know how to learn; you need a map.
- **Experienced operators** using a personal hub as a queryable
  second brain — the goal isn't memory, it's fast lookup.

You don't need to be all three. You'll switch modes per topic.

## The honest reality

The surface area is enormous:

- **Web** alone has dozens of bug classes, each with its own bypass
  literature.
- **Active Directory** adds Kerberos, ACLs, AD CS (ESC1–ESC16+),
  trusts.
- **Cloud** multiplies by three providers plus Kubernetes plus the
  identity layer underneath.
- **Exploit dev**, **mobile**, **AI red team**, **smart contracts**,
  **forensics**, **crypto** — each is its own discipline.

Experienced operators are **T-shaped**: deep in one or two areas,
broad enough to recognise patterns in the rest. Nobody is uniformly
deep across the whole stack. Stop apologising for not being.

The skill you build over time is **fast retrieval** — knowing the
right page to open, the right person to ask, the right CVE search
query — not raw memorisation.

## How this hub is organised

Three levels:

1. **[[paths-index|Learning paths]]** — ordered, multi-stage routes
   through a domain. Each path is `prereqs → stage 1 → stage 2 →
   stage 3 → milestone`.
2. **[[topics-index|Topic categories]]** — one folder per domain
   (web, network, AD, cloud, AI, …), each containing **atomic
   notes** (one technique per file).
3. **[[references|References]]** + **[[tools|Tools]]** — every
   stub points at an authoritative external page (HackTricks, ired,
   PortSwigger, OWASP, research blogs).

The notes use Obsidian-style `[[wikilinks]]`. A page that's a
real note renders as a clickable link. A page that hasn't been
written yet renders as a <span class="wikilink wikilink-broken">dashed
red span</span> — that's a deliberate TODO marker, not an error.

There's also a fourth layer for when you're mid-engagement and
**stuck**: **[[playbooks-index|Playbooks]]** — mermaid decision
trees that route from a real-world starting condition ("I scanned, now
what?", "I have a shell, how do I escalate?") to the right topic
note. Use them when you don't know what to look up.

## Where to start by level

### If you're new to offensive security

1. **Pick one path. Don't pick two.** Web pays the soonest:
   [[web-application-security]].
2. **Do stage 1 only.** Don't peek at stage 3 yet.
3. **Pair every reading with a lab.** [PortSwigger Web Security
   Academy](https://portswigger.net/web-security) is free and
   structured. Read a TL;DR here → finish 1-3 labs on the same
   topic.
4. **Watch your progress in broken wikilinks.** As you study a topic,
   fill the stub for it in your own words. The dashed-red span
   disappears when you're done.

### If you have the basics

1. **Pick a domain that pays your time.** Bug-bounty money lives in
   [[web-application-security]] + [[api-security]] +
   [[bug-bounty-methodology]]. Internal pentest careers live in
   [[network-pentesting]] + [[active-directory]]. Audit jobs live
   in [[code-auditing]].
2. **Finish stage 2 of one path.** Resist sampling.
3. **Start contributing back.** Pick a topic stub, study it for a
   week, write the full note. Future-you will thank you.

### If you're advanced

1. Use the hub as a **queryable index**, not a learning resource.
   Open it when you need the slug or the canonical reference.
2. **Adversarial recall practice:** open a topic's TL;DR cold, write
   the rest from memory in a scratch file, then diff. The diff is
   your study plan.
3. **Cross-pollinate:** read a path outside your wheelhouse end to
   end. The graph view in Obsidian shows you the links you didn't
   know existed.

## Learning patterns that actually work

### Atomic notes

> One technique per file. Title + TL;DR + outline + reference.

When notes are atomic you can link them, search them, and rewrite
single concepts without nuking adjacent context. This hub enforces
this — every stub is one technique. When you write content into a
stub, **keep it focused**. If you find yourself describing two
techniques, that's two notes.

### Spaced repetition for taxonomies

Some material is genuinely just a taxonomy you have to know:

- The OWASP Top 10 / Top 25 / API Top 10 / LLM Top 10.
- The AD CS ESC1–ESC16 matrix.
- Each cloud provider's IAM verbs of interest.
- Kerberos message types.

These survive flashcards (Anki / Mochi) better than re-reading.
Build a deck per taxonomy; review 10 minutes a day for two weeks.

### Learn by doing — labs over reading

Reading alone has terrible retention. Pair every topic with one of:

- A [PortSwigger Academy
  lab](https://portswigger.net/web-security/all-labs).
- An [HTB](https://www.hackthebox.com/) machine or Academy module.
- A [pwn.college](https://pwn.college/) challenge.
- A real bug-bounty target (with scope permission).

The hub points at the lab where one exists for the topic. If it
doesn't, build a vulnerable container for that technique yourself —
that exercise alone teaches more than the reading.

### Just-in-time for tools and CLI flags

Nobody memorises every Nmap flag, every Impacket script, every
`az` subcommand. Don't try. Bookmark the tool reference, build a
muscle for `--help` and `man`, and lean on shell history.

### Teach to consolidate

Writing a stub in your own words — explaining what it is,
preconditions, technique, defence — is the highest-retention
learning activity you can do short of teaching a human. **Filling
stubs is the study method**, not the side effect.

### Diff against your last reading

Two weeks after you study a topic, write the page from memory
again. What's gone is where you need spaced repetition or another
lab.

## Anti-patterns to avoid

- **Buying every book and cert at once.** You'll finish none.
- **Reading the *Web Application Hacker's Handbook* cover to cover
  before touching a target.** Half the bugs in it don't exist any
  more; you learn modern bugs by attacking modern apps.
- **Collecting tools you've never used.** A repo full of "useful"
  binaries with no muscle memory is worse than five tools you know
  cold.
- **Skipping fundamentals to chase advanced.** You cannot exploit
  kernel UAFs without understanding tokens. You cannot pop AD
  without understanding Kerberos. Earn it.
- **100 half-finished labs vs 10 finished ones.** Finish things.
- **Note-hoarding without retrieval practice.** Notes you never
  re-open aren't a second brain, they're a graveyard.

## How to contribute back

Every stub has the same template:

```markdown
---
title: <Title>
slug: <slug>
---

> **TL;DR:** <one sentence>

## What it is
## Preconditions / where it applies
## Technique
## Detection and defence
## References
```

Fill it in your own words after you've studied the technique. Lean
on the linked external source for depth — your atomic note exists
to consolidate *your* understanding, not replicate HackTricks.

One short paragraph per heading is plenty. A page that takes more
than five minutes to read is probably two pages.

When you update a TL;DR you found wrong, that's a real contribution
— stale opening lines mislead future-you.

## When to ignore the hub

- **In an active engagement** — read HackTricks live, the hub is for
  study and synthesis.
- **When picking up a new domain** — start with one good book and a
  lab environment; come back here for organisation later.
- **When stuck** — ask peers, post in a community Discord, write the
  question down to revisit. Don't drown in self-study.

## Realistic timelines

Rough order of magnitude, assuming consistent weekly effort:

- **Web app foundations** (apprentice tier through stage 1): 3–6 months.
- **Comfortable web app pentester / bug-hunter**: 12–18 months.
- **Comfortable internal AD operator**: 18–24 months.
- **Cloud-aware red teamer across one provider**: 12–18 months on
  top of network basics.
- **User-mode Windows exploit dev practitioner**: 12–24 months *if*
  you have systems background; longer otherwise.
- **Kernel / advanced exploit dev practitioner**: years.

You will forget half of what you read. The forgetting is normal.
The pattern that wins is **periodic re-engagement with a real
target**, not heroic study sprints.

## Final advice

- **Specialise first, generalise after.** Pick one domain, get
  competent, then sample.
- **Practitioner > collector.** The person who's finished one bug
  bounty disclosure beats the person who's read three books.
- **Write your own notes.** Even when the canonical writeup exists,
  the act of writing it yourself is what makes it yours.
- **Show up consistently.** Two hours a week for a year beats
  twelve hours one Saturday in March.
- **No one can master all of this.** Knowing that lets you focus.

Now go pick a path: [[paths-index|Learning paths]].
