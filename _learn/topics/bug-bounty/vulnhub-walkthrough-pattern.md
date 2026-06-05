---
title: VulnHub walkthrough pattern
slug: vulnhub-walkthrough-pattern
aliases: [vulnhub-method, vulnhub-boxes]
---

> **TL;DR:** VulnHub is the oldest free-to-download vulnerable-VM hub. Boxes are creator-contributed, varying quality. Solving pattern follows [[htb-machine-walkthrough-methodology]] but with VulnHub-specific quirks: offline / local network, weird hostname / IP assignment, sometimes CTF-style vs realistic, age-of-OS variance. Companion to [[oscp-style-box-attack-pattern]] and [[building-a-research-home-lab]].

## Why VulnHub still matters

- **Free** — no subscription.
- **Offline-friendly** — boxes downloaded locally; no internet required.
- **Large archive** — 700+ boxes spanning 2010–2024.
- **Many OSCP-prep boxes** — TJnull's list incorporates VulnHub heavily.
- **Beginner-friendly** — Kioptrix, basic-pentesting series.

## Quirks vs HTB

- **Local network**: configure VirtualBox / VMware host-only or NAT network.
- **IP discovery**: `arp-scan` or `netdiscover` to find the VM IP.
- **Old OSes**: many VMs run Ubuntu 14.04 / CentOS 6 — kernel exploits work.
- **CTF-style**: some have flag1, flag2, flag3 with riddles.
- **Realistic**: others mimic real systems.

## Recommended progression

### Beginner

- **Basic Pentesting 1, 2** — first taste.
- **Kioptrix 1, 2, 3, 4** — classic series, low complexity.
- **Stapler** — multi-vector.
- **FristiLeaks** — easy web.

### OSCP-prep (TJnull list)

- **Brainpan series**.
- **Mr. Robot**.
- **VulnOSv2**.
- **SolidState**.
- **DC series (DC-1 through DC-9)**.
- **Lord of the Root**.

### Beyond

- **HackInOS**.
- **The Ether: EvilScience**.
- **Multi-machine networks** (CyberSecLabs alternatives).

## Setup

1. Download VM (ova / vmware).
2. Import into VirtualBox / VMware.
3. Network: host-only or NAT network.
4. Snapshot before solving (revert if you brick).
5. Discover IP: `sudo arp-scan -l` or `netdiscover -r 192.168.x.0/24`.

## Solving pattern

Same as HTB:

1. nmap full TCP + UDP.
2. Per-service enumeration.
3. Web deep-dive.
4. Vector identification.
5. Foothold.
6. Privesc.

But:
- **Web more common**: VulnHub leans web-vulnerable.
- **Kernel exploits more common**: old OSes.
- **Default credentials common**: especially admin / admin.
- **Comments in HTML / robots.txt** often hint.
- **Hidden directories** with custom wordlists sometimes.

## Specific tips

- **Check `/etc/hosts`** updates if hostname-routing matters.
- **Mount NFS shares** if exposed (no_root_squash often misconfigured).
- **Read CMS sources** if a CMS visible (WordPress wp-config.php, Joomla configuration.php).
- **Find SUID binaries** — old VMs often have custom SUID.
- **Look for backup files** (`.bak`, `.old`, `.swp`).

## Differences from HTB

| Aspect | HTB | VulnHub |
|--------|-----|---------|
| Network | Hosted, instant | Local, you set up |
| Difficulty | Curated tiers | Wildly variable |
| Active community | Yes (Discord) | Less |
| Hints / writeups for active | Limited | All retired; writeups freely available |
| Subscription | Free + paid | Free |
| Modern OS | Yes | Often legacy |

## Common pitfalls

- **VM doesn't get IP**: bridged network instead of NAT/host-only.
- **Outdated boxes**: some 2012-era boxes have broken setup; check VulnHub comments.
- **Box-specific tricks**: some require physical-disk reset (rare).

## Workflow to study

1. Read TJnull's OSCP prep list for VulnHub recommendations.
2. Solve 5 easy boxes (Kioptrix 1, 2, Basic Pentesting 1).
3. Solve 10 OSCP-prep-tier boxes.
4. Write your own writeup for each — even if it duplicates existing ones.

## After VulnHub

Progression:
- **HTB** for modern pen-test simulation.
- **OSCP labs** if pursuing certification.
- **Pro Labs / multi-machine** ([[building-a-research-home-lab]] for AD lab).
- **Real bug-bounty** ([[ctf-to-bug-bounty-transition]]).

## Related

- [[htb-machine-walkthrough-methodology]]
- [[oscp-style-box-attack-pattern]]
- [[pwn-college-walkthrough-methodology]]
- [[ctf-jeopardy-pwn-strategy]]
- [[oscp-roadmap]]
- [[building-a-research-home-lab]]
- [[testing-methodology-checklists]]

## References
- [VulnHub](https://www.vulnhub.com/)
- [TJnull — OSCP-style box list](https://docs.google.com/spreadsheets/d/1dwSMIAPIam0PuRBkCiDI88pU3yzrqqHkDtBngUHNCw8/)
- [IppSec — VulnHub videos](https://www.youtube.com/@ippsec)
- [g0blin walkthroughs](https://www.g0blin.co.uk/)
- See also: [[htb-machine-walkthrough-methodology]], [[oscp-roadmap]], [[building-a-research-home-lab]]
