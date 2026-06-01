---
title: AWD flag strategy
slug: awd-flag-strategy
---

> **TL;DR:** Maximise flag yield per round with parallel exploits, persistent footholds that survive rivals' patches, and submission pacing that avoids gamebot rate limits or anti-cheat detection.

## What it is
Scoring in A/D is per-round and zero-sum: a flag is only worth points during its tick window, and most events cap or detect bursty submission. Flag strategy is the meta-layer above individual exploits — deciding which bugs to fire, against whom, how often, and how to keep flag flow steady when rivals start patching. See [[awd-overview]] for scoring mechanics.

## Preconditions / where it applies
- You have at least one working exploit, ideally several — own ones plus replayed traffic from [[awd-traffic-analysis]]
- A submitter daemon and an exploit harness are already running — see [[awd-preparation]]
- The game has multiple services so you can diversify when one bug gets patched globally

## Technique
1. **Per-tick scheduling.** Most events rotate flags every 60-300 seconds. Fire each exploit once per tick per team — more is wasted, less leaves flags on the table. A cron-style scheduler keyed to the tick boundary works well:

   ```python
   while True:
       tick_start = next_tick()
       sleep_until(tick_start + 5)  # let checker write flags first
       run_all_sploits_parallel()
   ```
2. **Submission pacing.** Batch flags, dedupe, and submit just under the per-round cap. Random jitter on a sub-second timer avoids gamebot anomaly flags that punish "robot" submissions.
3. **Persistence that survives patches.** If a team patches the bug, you lose flags from that team next round — unless you dropped a foothold. Common in-scope forms: a writable file the service still reads, an extra row in the DB, an overridden environment variable, a cron entry the patch did not remove. The persistence must read the freshly-written flag, not a stale one.
4. **Diversify across services.** One bug usually gets patched fleet-wide within an hour as teams replay each other. Always have a second service half-exploited in the background.
5. **Stealth payloads.** Encode or fragment payloads so [[awd-traffic-analysis]] cannot lift your exploit verbatim. Examples: chunked transfer-encoded HTTP bodies, hex-escaped SQL, base64-wrapped command injection. Rotate the encoding every few ticks.
6. **Defence in the same loop.** Submitting flags also tells you who is exploiting whom — when your own flags appear stolen, prioritise patching that service in your own box.

## Detection and defence
- Gamebot scoreboard deltas show which services are leaking — a sudden drop tied to one service is a global patch event, switch exploit priority
- Watch your own logs for replayed versions of your exploits — that is the signal to rotate encoding
- Keep submission logs: which flag came from which team via which exploit, so post-game analysis ties scoring to bugs

## References
- [FAUST CTF rules](https://2023.faustctf.net/information/rules/) — example tick model and submission caps
- [ENOWARS framework](https://github.com/enowars) — open implementation showing flag rotation and validation
- [Saarsec team repos](https://github.com/saarsec) — top-team writeups discussing persistence and pacing
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings) — payload obfuscation patterns useful for stealth
