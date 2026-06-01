---
title: AWD leading vs trailing
slug: awd-leading-trailing
---

> **TL;DR:** "Leading" teams race to be the first to land an exploit each round and accept that rivals will copy them; "trailing" teams deliberately wait, replay captured traffic, and free-ride the leaders' research — both are valid, but require very different tooling and discipline.

## What it is
In Attack/Defense events every exploit fired across the wire is observable to the victim and often to neighbours that mirror traffic. The strategic split is whether you want to be the source of new exploits (leading) or a fast follower that lifts payloads from PCAPs and rebroadcasts them with minimal modification (trailing). Most strong teams blend both modes depending on the round and the service. See [[awd-overview]] for round mechanics and [[awd-flag-strategy]] for scheduling.

## Preconditions / where it applies
- Multi-team A/D event where traffic to your box is available (most events provide PCAPs or tcpdump access)
- A submitter pipeline already wired up — see [[awd-preparation]]
- Enough operator headcount to split "exploit dev" from "PCAP triage" roles

## Technique
Pick a mode per service, per round.

```bash
# Trailing: extract HTTP request bodies from rolling capture, replay against
# every other team with the path/host rewritten
tshark -r round12.pcap -Y 'http.request' -T fields \
  -e http.host -e http.request.method -e http.request.uri \
  -e http.file_data > requests.tsv

python3 replay.py --teams teams.txt --template captured.req
```

Leading playbook:
1. Drop the exploit early in the tick so your flag-submit lands before the gamebot rate-limits
2. **Anonymise**: route through a SOCKS proxy on a teammate's box, randomise `User-Agent`, pad query strings — slows down trailers but does not stop them
3. **Backdoor `/flag` reads**: after first success, plant a persistence hook (extra row, writable file, modified handler) so future rounds harvest without re-exploiting
4. **Log-poison**: emit decoy requests that *look* like the exploit but submit a fake flag, so naive replayers waste their submission quota and get penalised by the gamebot

Trailing playbook:
1. Tail tcpdump on your own vulnerable service the moment scoring opens
2. Diff successful attacker traffic against checker traffic — checker requests are usually constant per round, anything else is an exploit
3. Strip team-specific tokens, parametrise host, replay against the other N-2 teams
4. Re-encode the payload before resending so the original leader cannot use a WAF signature on their own exploit to identify you

Mixed: lead on a service you wrote the exploit for, trail on services owned by other teams' specialists.

## Detection and defence
- Detect trailers on your own box: a request identical to one you sent moments ago but with a different source IP is a replay — rotate payload encoding next tick
- Watch flag-submit endpoints for duplicate flags: gamebot logs show who submitted first, useful for post-game analysis
- Defensive: TLS to the checker only (where rules allow), per-request nonces in your patched service so replayed exploits fail silently
- Decoy flags in poisoned logs must look real (correct regex, correct length) to actually waste a trailer's submission budget

## References
- [DEF CON CTF finals writeups](https://github.com/o-o-overflow/dc2023f-public) — examples of replay-heavy rounds
- [FAUST CTF infrastructure](https://2023.faustctf.net/) — public PCAP availability rules
- [Saarsec writeups](https://github.com/saarsec) — replay-detection tooling
- [ENOWARS reference](https://github.com/enowars) — checker vs attacker traffic model

See also: [[awd-overview]], [[awd-flag-strategy]], [[awd-traffic-analysis]], [[awd-patching]].
