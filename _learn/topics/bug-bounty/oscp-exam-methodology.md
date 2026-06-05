---
title: OSCP exam methodology and notetaking
slug: oscp-exam-methodology
aliases: [oscp-exam-methodology, oscp-notetaking]
---

{% raw %}

> **TL;DR:** The OSCP exam is 24 hours of hacking + 24 hours of writing. Most failures are time-management failures, not skill failures. This note is the playbook: pre-exam prep, hour-by-hour rhythm, when to rotate boxes, when to sleep, and the notetaking discipline that lets you write the report in 6 hours instead of 18. Companion to [[report-writing-for-pentesters]] and [[oscp-roadmap]].

## The shape of the exam (current at time of writing; re-check OffSec)

- **24 hours** to attack: 3 standalone machines + 1 AD set (3 machines chained).
- Points: standalone 20/host with partial credit for foothold-only; AD set 40 (all-or-nothing).
- **70 points** to pass, with bonus points possible from coursework and labs.
- **Another 24 hours** to write the report.
- One allowed Metasploit auto-exploit + one meterpreter post-module.
- No commercial tools (Burp Pro, Cobalt Strike), no AI assistants.

Pass = score ≥ 70 *and* report is acceptable. Re-read the official guide a week before — rules drift.

## Two weeks before

- [ ] Build your toolchain VM: Kali updated, `searchsploit --update`, `seclists`, mona, wordlists, your scripts dir (`~/scripts/`) with one-liners ready.
- [ ] Two clean snapshots of the VM.
- [ ] Print or PDF the cheat sheets you allow yourself: BOF skeleton, reverse-shell catalogue, LinPEAS/WinPEAS pointers, AD attack reference.
- [ ] Run a full mock exam (4 boxes from Proving Grounds Practice + OffSec AD lab clone) under exam rules. Time-box honestly.

## 48 hours before

- [ ] Snapshot Kali once more.
- [ ] Test the OpenVPN connection.
- [ ] Verify Webcam/ID requirements (proctoring) on the OffSec portal.
- [ ] Pre-write the report skeleton: cover page, methodology section, finding template ×5.
- [ ] Sleep regular hours. **Do not study the night before.** Skill consolidation needs sleep.

## Exam day kit

- A second device to read the proctor chat / official portal (so your Kali screen is fully for hacking).
- Water, snacks within reach. Real food at hour 6 and hour 14.
- A timer/clock visible at all times.
- Loud headphones if you have flatmates.

## Hour-by-hour rhythm

| Hour | Activity |
|---|---|
| 0 | Read every box's brief twice. Note any explicit constraints. |
| 0–1 | Start `nmap -sV -sC -p-` on every box in parallel. While they run, set up per-host folders. |
| 1–6 | Standalones — depth-first on whichever looks easiest. Foothold + privesc + flag + screenshots before moving on. |
| 6 | **Real food. 30-min walk if possible.** Energy decisions get bad after this point. |
| 7–14 | AD set — recon → foothold on first box → enumerate → lateral → DA. The AD set is all-or-nothing; you commit. |
| 14 | **Re-evaluate.** Count points so far. If < 60, panic-mode rotation: revisit the box you skipped, try the most-likely-low-hanging vector. |
| 14–18 | Push hardest on the boxes nearest the cut. |
| 18 | **Sleep 4 hours.** Set two alarms. Yes, really. A clear head from hour 22–24 beats a fried brain from hour 18–24. |
| 22–24 | Final passes, screenshot consolidation, sanity check. |

## When to rotate boxes

You are not stuck. You are *in a loop*. Rotate when:
- You've tried 3 different vectors on the same surface and none gave new information.
- You've spent > 90 minutes since the last new finding.
- You are reading the same nmap output for the third time.

Rotation rule: leave a sticky note ("try X, Y next") on the box you're parking and *fully switch context*. Five minutes away resets pattern-matching.

## When NOT to rotate

- You have a confirmed crash and the next step is bad chars or offset — that's grind work, not a stuck moment.
- You have credentials and are running through them on services — let the spray finish.
- You can hear yourself say "almost". Set a 20-minute timer first.

## Notetaking discipline

Per-host markdown file. Append-only. One section per command. **No back-editing while attacking.**

```markdown
# 10.10.10.5

## 09:14 — nmap -sV -sC -p-
[full output]

## 09:22 — gobuster /admin
Status 403 on /admin
Status 200 on /backup.zip ← interesting

## 09:25 — wget backup.zip
Got it. unzip → config.php
Found db creds: webapp / hunter2

## 09:31 — try web login
...
```

You will copy huge chunks of this into the report verbatim. Every screenshot is named `<host>-<step>-<what>.png` and dropped in the same folder.

## Screenshot discipline (the one you'll regret skipping)

Every screenshot must contain, in the same frame:
- The command you ran.
- Its output.
- The host you're on (`whoami` + `hostname` if it's a shell).
- Your attacker IP (`ip a | grep tun0` somewhere on screen).

If you take post-hoc screenshots from a recovered shell after the exam ends, OffSec may reject them.

## Common mid-exam mistakes

| Mistake | Cost | Fix |
|---|---|---|
| Diving deep on the first box for 5 hours | One box | Time-box: 2 hours then move |
| Skipping AD set because "too hard" | 40 points | AD set is the highest-value group; do it second |
| Using your one MSF on a box you could have done manually | One MSF allowance | Save MSF for a box you're stuck on at hour 18+ |
| Forgetting the listener before firing the exploit | One PoC attempt | Make "nc -lvnp" muscle memory |
| Killing the only shell you had with EXITFUNC=process | The shell | Always `EXITFUNC=thread` |
| Taking screenshots without `whoami` | Failed evidence | Build screenshots into the script |

## Mental model

Treat the exam as five small engagements glued together. Each box has a foothold step and a privesc step. If you separate "I haven't found the foothold" from "I have a shell but no root", you stop conflating two very different stuck states.

## Right after the exam

1. Don't pop champagne. Save and **back up** your notes folder + screenshots immediately.
2. Sleep.
3. Eat.
4. Write the report. Use [[report-writing-for-pentesters]].

## References
- [Official OSCP exam guide](https://help.offsec.com/hc/en-us/articles/360050293792)
- [Offsec — exam FAQ](https://help.offsec.com/hc/en-us/sections/360008126631)
- [TJ Null OSCP-like list](https://docs.google.com/spreadsheets/d/1dwSMIAPIam0PuRBkCiDI88pU3yzrqqHkDtBngUHNCw8/) — practice targets that mirror exam difficulty
- See also: [[oscp-roadmap]], [[report-writing-for-pentesters]], [[note-taking-while-hacking]]

{% endraw %}
