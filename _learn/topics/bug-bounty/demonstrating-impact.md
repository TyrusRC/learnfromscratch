---
title: Demonstrating impact
slug: demonstrating-impact
---

> **TL;DR:** Impact is the gap between "this is technically a bug" and "this lets an attacker do X to Y users for $Z dollars." Triage pays for the second framing. Chain just enough to make it undeniable, then stop.

## What it is
Triagers see the same bug class hundreds of times. What separates a $500 medium from a $5k high isn't a different vulnerability — it's how clearly the report ties the technical primitive to a business outcome. Demonstrating impact is the discipline of building a proof-of-concept that makes severity self-evident.

## Preconditions / where it applies
- You have a working PoC of a vulnerability (parameter, endpoint, payload all confirmed)
- The program has a published reward range tied to severity / business impact, not just CVSS vector
- You haven't yet hit a hard rule (no PII access, no production data, no DoS)

## Technique
1. Map the primitive to a CIA triad outcome. For each finding, write one sentence per axis:
   - Confidentiality: "Attacker reads $WHAT_DATA belonging to $WHOM"
   - Integrity: "Attacker modifies $WHAT_STATE causing $CONSEQUENCE"
   - Availability: "Attacker denies service to $WHO at $SCALE"
2. Chain only enough to remove "so what?" objections. If reflected XSS on a login page lets you steal a session cookie, demoing one cookie steal proves account takeover; you don't need to actually drain a victim's funds. Stop at the proof.
3. Numbers beat adjectives. "Affects all 50M users" loses to "I verified the bypass works on accounts A, B, C from three different states and the endpoint has no rate limit, so the population is bounded only by the user table size." Quote response headers, screenshot enumeration counts, attach traffic captures.
4. Build a damage scenario in business terms. Map the technical bug to a concrete attacker goal the program's PM cares about:

```
Technical:  IDOR on /api/orders/<id>
Business:   Any logged-in user can read any other user's
            invoices, including shipping addresses (PII),
            line items (purchase history), and last-4 card.
            Sample: my account read orders belonging to 3
            unrelated test accounts — receipts attached.
```

5. Don't over-chain when it costs you. Submitting a clean SQLi at high severity and getting paid is better than spending 4 days on a full RCE chain and getting scooped by a duplicate. Calibrate to the [[dupe-mental-model]] — fresh bug? chain; old surface? submit fast.
6. Respect the rules. Reading 3 test accounts you created is impact proof; reading real customer PII is a policy violation and gets the report closed and you removed from the program.

## Detection and defence
- Programs that under-pay for "high" findings on real impact lose hunters; calibrate bounty ranges to the actual exposure not the CVSS calculator
- Triagers should reward chains that converted a "low" primitive into a "high" outcome — pay for the work, not just the bug class
- For hunters: keep an "impact catalogue" in your notes — past chains by bug class — so you can quickly suggest the strongest realistic outcome for each new finding

## References
- [HackerOne — Hacktivity report disclosures](https://hackerone.com/hacktivity) — read top-paying reports for impact framing
- [Bugcrowd VRT](https://bugcrowd.com/vulnerability-rating-taxonomy) — explicit severity-to-business-impact mapping
- [Real-World Bug Hunting (Yaworski)](https://nostarch.com/bughunting) — chapter-by-chapter impact examples
