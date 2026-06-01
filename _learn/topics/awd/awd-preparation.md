---
title: AWD preparation
slug: awd-preparation
---

> **TL;DR:** Pre-stage the boring plumbing — flag submitter, traffic capture, file integrity, exploit harness — so the first ten minutes of the game are spent on bugs, not bash.

## What it is
AWD competitions are won in the first hour, and that hour is mostly engineering, not exploitation. Preparation means arriving with a toolkit that turns "I have a working exploit against one team" into "flags from every team, every round, automatically" within minutes. See [[awd-overview]] for context.

## Preconditions / where it applies
- Rules and scoring API are usually published 24-72h before the event — read them, the submission format changes per event
- You control your own box as root; you do not control rivals' boxes
- Your team needs a shared chat, a shared repo, and ideally a shared submission server so one person's exploit feeds the whole team

## Technique
A working kit usually includes:

1. **Flag submitter daemon.** Reads flags from a queue (file, Redis, or stdin), dedups, batches, and POSTs to the gamebot honouring rate limits.

   ```python
   while True:
       batch = q.get_nowait_batch(100)
       r = requests.put(SUBMIT_URL, json=batch, headers={"X-Team-Token": TOK})
       log_results(r.json())
       time.sleep(TICK)
   ```
2. **Exploit harness.** A loop that imports each `sploit_<service>.py`, fans out across teams concurrently with `asyncio` or `concurrent.futures`, captures stdout flags and pushes to the submitter.
3. **Traffic capture from minute zero.** `tcpdump -i game0 -G 60 -w 'cap-%H%M.pcap'` rotating every minute, plus an out-of-band copy to a teammate's box — see [[awd-traffic-analysis]].
4. **File-integrity baseline.** Snapshot `/var/www`, `/srv`, `/opt/<service>` immediately: `tar czf /root/baseline.tgz /opt/service && find /opt/service -type f -exec sha256sum {} \; > /root/baseline.sha256`. Re-run hourly and diff.
5. **Patch staging dir.** Keep an unmodified copy of every service so you can `diff -ur` and produce minimal patches — see [[awd-patching]].
6. **Process and port watchdog.** Cron every 30s: alert if `ss -lntp` loses an expected port or gains an unexpected one (sign of backdoor or persistence).
7. **Credential rotation script.** Change every default password and SSH key in the first minute: DB users, admin panels, Redis, SSH for service accounts.

Have all of this in a private git repo before the event, cloned to every team member's machine.

## Detection and defence
- The integrity baseline IS your detection layer — diff catches dropped webshells and modified binaries
- Log everything: bash history (`HISTTIMEFORMAT`), service logs to a remote rsyslog, full pcaps off-box
- A pre-written rollback (`tar xzf /root/baseline.tgz -C /`) is the panic button when a rival owns root

## References
- [ENOWARS team toolbox](https://github.com/enowars) — reference framework with submitter and checker stubs
- [FAUST CTF gameserver docs](https://2023.faustctf.net/information/rules/) — sample submission API
- [Saarsec team repos](https://github.com/saarsec) — example A/D exploit harnesses from a top team
- [HackTricks Linux hardening](https://book.hacktricks.wiki/en/linux-hardening/checklist-linux-privilege-escalation.html) — quick hardening checks relevant to defence
