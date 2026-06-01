---
title: "Hacker mindset: question everything"
slug: hacker-mindset-questioning
---

> **TL;DR:** Treat every input, parameter, header, cookie, redirect, and silent UI affordance as a potential bug. Payload lists run out; trained curiosity scales.

## What it is
The technical skills of bug hunting can be taught from a checklist. The differentiator at scale is a posture toward applications — assuming nothing about why a developer made a choice, asking "what if I send something other than what they expect?" at every interaction. This is the meta-skill that makes the rest of [[testing-methodology-checklists]] effective rather than mechanical.

## Preconditions / where it applies
- Any active testing pass — recon, mapping, exploitation, post-exploitation
- Especially valuable on mature targets where automation has been duped to death; only curiosity finds the next layer
- Pairs with [[note-taking-while-hacking]] — questions you don't write down don't get answered

## Technique
1. For each request/response pair, hold a running list of micro-questions:
   - What happens if this parameter is empty? Negative? Huge? An array? An object?
   - What if I change the verb? Add a duplicate header? Send the same header twice with different values?
   - Why is this cookie named `_legacy_id`? What was the non-legacy id?
   - The UI hides this button on a free plan — what if I send the request anyway?
2. Read the response with the same posture. A header you've never seen (`X-Internal-Request-Id`, `X-Powered-By: corp-gateway-v3`) is a thread to pull. A field in JSON that the UI never displays is a hint about server-side state.
3. When something works, ask why it shouldn't have, and where else that "shouldn't have worked" applies. SSRF blocked on URL parameter? Try same parameter via JSON body, via header, via filename in a multipart upload.
4. Track silent affordances. A form field that exists in the HTML but is hidden with CSS is a feature the developer wanted disabled but kept reachable. A 200 response on a request the UI never sends is a route they deprecated but didn't remove.
5. Adversarial reading of marketing copy. "We auto-detect file type from content" → upload bypass candidate. "We let admins impersonate any user for support" → IDOR or privilege escalation candidate.
6. Calibrate against the [[dupe-mental-model]]. The first 50 questions are the obvious ones every hunter asks — push to question 51+ where the dupes thin out.

## Detection and defence
- Defenders should review their own apps with the same posture before shipping — what hidden affordances did we leave reachable? What does the response leak that the UI doesn't show?
- Run regular threat-modelling sessions where a team-mate plays adversary against a recent feature; the goal is generating questions, not answers
- For hunters: keep a "questions answered" log per target — when you check off the curiosity list, you've earned the right to move on without dupe-anxiety

## References
- [HackerOne — Hacker mindset blog tag](https://www.hackerone.com/blog) — hunter philosophy posts
- [Bug Bounty Bootcamp (Li)](https://nostarch.com/bug-bounty-bootcamp) — chapter on developing curiosity
- [PortSwigger Research](https://portswigger.net/research) — example writeups built from a single curious question
