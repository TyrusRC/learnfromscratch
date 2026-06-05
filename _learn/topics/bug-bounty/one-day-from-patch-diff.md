---
title: 1-day from patch diff — methodology
slug: one-day-from-patch-diff
aliases: [one-day-exploit-development, patch-diff-to-exploit, 1day-workflow]
---

> **TL;DR:** A 1-day is an exploit you write *after* a patch ships but *before* most operators have applied it. The workflow: pull both versions of the patched binary or source, diff, isolate the changed function, identify the pre-condition the patch enforces, build the inverse as your trigger. Median target time-to-exploit for a well-known product: 24 hours from patch drop. Companion to [[reading-public-pocs-effectively]] and [[patched-binary-diffing-for-vulnid]].

## Why 1-day matters

- For **red team**: most enterprises take 30+ days to patch. A 1-day is functional on prod for a month.
- For **bug bounty**: variant hunting on freshly-patched code finds the bypass the vendor's patch missed.
- For **research**: 1-day work is your training before 0-day. The bug is *known to exist* — you don't waste cycles chasing a false trail.
- For **CTI / threat-intel**: knowing how easy a 1-day is informs vulnerability prioritisation.

## Source-code product workflow

If the patched code is open source (Linux kernel, OpenSSL, nginx, Spring, Rails, Drupal):

1. **Get the advisory** — note CVE, affected versions, fix commit SHA.
2. **Clone the repo** locally; check out the fix commit.
3. **`git show <fix-commit>`** — read the diff. Often 5–30 lines.
4. **Read the function before and after**. The diff usually adds a check, sanitises input, or changes an offset.
5. **Frame the bug**: pre-condition the patch enforces = the violation your trigger needs.
6. **Find the entry point** — work backwards from the changed function to a user-controlled input. `git log -p -G "vulnerable_function"` helps trace callers.
7. **Build minimal trigger** — send the input that violates the new check.
8. **Stage to impact** — DoS / info-leak / RCE depending on the primitive.

## Closed-source product workflow

For Cisco / Fortinet / Ivanti / Palo / Citrix / Atlassian (binaries or obfuscated server-side code):

1. **Get the patched and unpatched builds**.
   - For appliances: extract firmware ([[firmware-extraction]]) or pull from the vendor download portal.
   - For Windows: WSUS, Microsoft Update Catalog (msdl.microsoft.com), or extract from the patched ISO.
2. **Locate the changed binaries**. Diff file sizes / hashes; the vendor often patches dozens of files but only one is the fix.
3. **BinDiff / Diaphora** the candidate binaries. See [[patched-binary-diffing-for-vulnid]].
4. **Examine flagged functions**. The patch usually adds:
   - A bounds check.
   - A new auth check (privilege / role / session).
   - An input length/format validator.
   - A logging call (sometimes the diff is non-security but still informative).
5. **Trace upward** to the request handler. For HTTP-fronted appliances, the handler is in a CGI binary or shared library.
6. **Build the request that exercises the unchecked path**.

## Common patch shapes and what they imply

| Patch shape | Implied bug class |
|-------------|--------------------|
| Added `strncpy` instead of `strcpy` | Stack/heap buffer overflow |
| Added length check before memcpy | Integer overflow → heap corruption |
| Added auth check at top of handler | Pre-auth privileged action |
| Added input sanitisation (regex / allowlist) | Injection (XSS / SSTI / command / SQL / path) |
| Changed array index calculation | OOB read/write |
| Added free() and NULL = | UAF or double-free |
| Changed lock acquisition order | Race / TOCTOU |
| Removed `eval` / dynamic call | Code injection |

When you see the shape, you immediately know what trigger to construct.

## The "look at the silent diff" trick

Vendors often quietly patch *adjacent* code in the same commit. Those silent diffs are bonus CVEs. Examples:

- A patch for one path-traversal variant sometimes fixes a second variant with no advisory.
- A heap overflow patch sometimes also touches a sibling parser the vendor never disclosed.

Read every changed file in the commit, not just the one the CVE references. Variant hunting earns you a second CVE and often a bigger bounty.

## Speed benchmarks

If you can complete the loop in:

- **< 4 hours** for an open-source CVE — you're a competent 1-day developer.
- **< 24 hours** for a closed-source appliance CVE — you're at red-team operator pace.
- **< 1 week** for a kernel CVE with PoC writeup — competitive.

Pwn2Own and Pwn2Own-tier teams routinely beat these. The skill is mostly **familiarity with the product surface**, not exploit cleverness — you read the product's source / binaries before the patch drops.

## Pre-positioning

Operators who turn out 1-days fast pre-position:

- **Build a target lab** in advance for the products you care about (multiple versions in VMs).
- **Mirror vendor release pages** so you have N-1 and N for diffing the moment N drops.
- **Subscribe to vendor security advisory RSS** — get the email before Twitter does.
- **Maintain a working dev environment** for the product's stack so you can rebuild and trace immediately.

Time spent here is amortised across every future 1-day you'll write for that product.

## Anti-patterns

- **Skipping the patch read** — guessing from the advisory text alone. Wastes hours; advisory is intentionally vague.
- **Trying to write a "universal" PoC** before you have *any* PoC. Get one version working first.
- **Assuming the public PoC is correct** when it appears later. Vendors and journalists publish wrong PoCs all the time. Trust the diff.
- **Tweeting screenshots** of a working exploit on production. You'll burn the technique.

## Tools

- **BinDiff** / **Diaphora** — binary diffing.
- **Ghidra** / **IDA Pro** with version-tracking — diff at the function level.
- **`git log -p --follow`** — track changes across refactors.
- **`grep -r`** — fast string search across two source trees.
- **`patchdiff2` / `radiff2`** — lightweight diffing.

## References
- [Project Zero — patch-gap and 1-day analyses](https://googleprojectzero.blogspot.com/)
- [watchTowr — 1-day appliance writeups](https://labs.watchtowr.com/)
- [BinDiff](https://www.zynamics.com/bindiff.html)
- [Diaphora](https://github.com/joxeankoret/diaphora)
- See also: [[reading-public-pocs-effectively]], [[patched-binary-diffing-for-vulnid]], [[n-day-rapid-exploitation]], [[porting-public-exploits]]
