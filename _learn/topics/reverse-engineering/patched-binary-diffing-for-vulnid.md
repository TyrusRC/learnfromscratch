---
title: Patched-binary diffing for vulnerability identification
slug: patched-binary-diffing-for-vulnid
aliases: [patch-diffing, bindiff, n-day-diffing]
---

{% raw %}

> **TL;DR:** Vendors fix bugs and ship updated binaries. The diff between unpatched and patched code points at the bug. BinDiff and Diaphora compare two binaries function-by-function, ranking changes; you focus on the highest-changed security-relevant functions and decompile both sides. This is the bread-and-butter workflow for n-day discovery. Companion to [[decompiler-driven-source-review]] and [[known-cve-triage]].

## When this is the right move

- A vendor released a security update; the advisory hints but doesn't disclose the bug.
- An unsupported product still gets you targets; the patched version exists somewhere.
- You're looking for "silently-fixed" bugs (no advisory, but a diff in a routine update).
- You're verifying that a public PoC actually exploits the bug the advisory claims.

## The corpus

Get two builds of the same binary that differ only across the patch you care about:
- Old/Unpatched (vulnerable).
- New/Patched (fix in).

Sources:
- Microsoft Update Catalog (Windows updates as MSU/CAB).
- Vendor download centre archive.
- Package mirrors and snapshot archives (debian-snapshot, archive.org).
- Distro source repos for cross-checking.

## The tooling

| Tool | Strength |
|---|---|
| **BinDiff** | Industry standard, IDA plug-in, sound CFG-based diff |
| **Diaphora** | Open-source, deeper symbolic comparison, scripted via IDA Python |
| **Ghidra BSim** | Built-in Ghidra equivalent, scale to many binaries |
| **rizdiff** (rizin) | CLI / scripting friendly |
| **Kdiff3 / meld on decompiler text** | Hand-rolled when tooling fights |

Workflow: run BinDiff between old and new, generate the report, open old in IDA + new in IDA, jump to ranked diffs.

## What BinDiff scores

For each matched function pair, BinDiff gives:
- **Similarity** [0.0..1.0] — how alike the CFGs are.
- **Confidence** [0.0..1.0] — how sure BinDiff is of the match.
- **Change types** — basic-block count delta, instruction delta, edge delta.

You sort by "similarity ascending" (most different) within "confidence high" (correctly matched). That's your candidate list.

## Triage the candidate list

Pre-filter:
- Drop functions with cosmetic-only diffs (logging strings, version constants).
- Drop functions where the diff is a recompilation artefact (different register allocation, inlining shift).
- Keep functions where:
  - A new bounds check appears.
  - An integer comparison changed (signed → unsigned).
  - A memcpy/strcpy call disappeared / was replaced with `_s` variant.
  - A new validation branch was added before a memory operation.
  - A new locking primitive (mutex acquire/release) was added.

## A worked example

You see in the diff for `parse_packet`:

```c
// old
size = *(int *)(buf + 4);
memcpy(dst, buf + 8, size);

// new
size = *(int *)(buf + 4);
if (size > 0 && size <= sizeof(dst))         // NEW check
    memcpy(dst, buf + 8, size);
```

The added bound check tells you the old code is a stack BOF where `size` is attacker-controlled. From here:
1. Identify reachability: what callers pass user-input `buf` to `parse_packet`?
2. Determine pre-auth / post-auth.
3. Identify any compensating control (e.g. an outer-loop check).
4. Write a PoC.

## Microsoft update specifics

`.msu` → `extract` → `.cab` → `expand` → individual `.dll` / `.sys` files.

```cmd
expand -F:* update.msu C:\out\
expand -F:* C:\out\Windows10.0-KB123456-x64.cab C:\out\extracted\
```

For Windows kernel diffs (often the highest-impact), set up paired symbol servers (`SYMSRV*...*\\winsymbols`) so both binaries get PDB symbols.

## Open-source (Linux) advantage

For Linux packages you can get the source diff directly — but binary diffing is still useful when:
- A backported fix to an old branch is undocumented.
- The compiler optimisation changed behaviour the source change didn't intend.
- The shipped binary doesn't match the published source (vendor patch on top).

## Common pitfalls

- **Compiler upgrade between versions** — every function looks "different"; raise the similarity threshold and look for *structural* changes (new branches).
- **Wholesale refactor** — vendor cleanup pass moves code around; BinDiff matches functions by hash and fails; fall back to Diaphora's "pseudocode similarity".
- **Dead-code removal disguised as a fix** — sometimes a function shrinks because dead code was removed; not a bug fix.
- **The fix is in a *caller*** — the diff in `parse_packet` shows no change, but the caller now validates length before calling. Look up the call tree.

## After you find the bug

- Confirm with dynamic analysis: set a breakpoint on the unpatched version, deliver input, hit the bug, observe corruption.
- Write the PoC against the unpatched version.
- Re-test against the patched version to confirm the fix is correct (vendors sometimes patch the symptom, not the bug).
- Note any *other* sinks that share the parameter — a second variant the vendor missed is a 0-day on top of an n-day.

## Reporting

For coordinated disclosure of an n-day variant found via patch diffing, the vendor wants:
- Original CVE the patch addresses.
- Pseudo-code of the patched function before and after.
- Repro for the variant (new sink, new code path).
- Suggested fix (often, "same check applied here").

## References
- [BinDiff documentation](https://www.zynamics.com/bindiff/manual/)
- [Diaphora](https://github.com/joxeankoret/diaphora)
- [Ghidra BSim](https://github.com/NationalSecurityAgency/ghidra/tree/master/Ghidra/Features/BSim)
- [Project Zero — patch diffing case studies](https://googleprojectzero.blogspot.com/)
- See also: [[decompiler-driven-source-review]], [[known-cve-triage]], [[n-day-rapid-exploitation]], [[crash-triage]]

{% endraw %}
