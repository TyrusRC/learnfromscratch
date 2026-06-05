---
title: Building a research home lab
slug: building-a-research-home-lab
aliases: [home-lab-research, security-research-lab, lab-environment-setup]
---

> **TL;DR:** A productive security home lab is built around your **research goals**, not abstract completeness. Web hunters need a VPS + Burp + a few synthetic vuln-app containers. AD researchers need a small AD forest with ADCS / Entra Connect. Exploit-dev practitioners need a debug-friendly Windows VM + WinDbg + symbols. Cloud researchers need throwaway AWS / GCP / Azure accounts with billing alarms. Build the slice you'll use; expand later. Companion to [[ctf-to-bug-bounty-transition]] and [[keeping-up-with-research-feeds]].

## Why a home lab

- **Reproducibility** — you can spin up the same compromised state repeatedly.
- **Isolation** — exploit dev / malware research without endangering production.
- **Speed** — local iteration beats waiting on cloud resources.
- **Cost control** — local VMs cost only electricity once hardware is paid.
- **Learning** — configuring the lab is itself education.

## Hardware baseline

For most research:
- **CPU**: 8+ cores, virtualisation-friendly (AMD-V / VT-x).
- **RAM**: 64 GB+. Less is workable but limits concurrent VMs.
- **Storage**: 1 TB+ NVMe for VM images, fast IO.
- **GPU**: not required unless ML/AI research; one with decent CUDA helps for hash cracking ([[password-cracking-toolkit]]).
- **Network**: separate physical NIC or VLAN for lab vs home.

Many practitioners run on a workstation; some use a dedicated mini-server (Intel NUC, Beelink, used SuperMicro) for a static lab.

Alternative: cloud-only lab. Use AWS / GCP / Azure spot instances + S3 for snapshots. Cheaper to start, more expensive long-term.

## Hypervisor / virtualisation

Pick one and learn it deeply:
- **Proxmox** — open-source; great for headless lab.
- **VMware ESXi** — free tier dropped; alternatives now preferred.
- **VirtualBox** — workstation use.
- **KVM / libvirt** — Linux native.
- **Hyper-V** — Windows host.
- **QEMU** for emulating non-x86 ([[firmware-emulation-firmadyne-qemu]]).

For containerised research: **Docker** + **docker-compose** + **Kubernetes (kind / k3s)** local cluster.

## Lab patterns by research area

### Web app / API hunting

- Burp Suite Pro on workstation.
- Synthetic vuln apps: OWASP Juice Shop, WebGoat, DVWA, bWAPP — for technique practice.
- **Modern stacks**: clone a real open-source SaaS (Cal.com, Rocket.Chat, Mattermost) for realistic testing.
- Disposable VM with Burp + tools (ffuf, sqlmap, nuclei) for client-side isolation.

### Mobile

- Android emulator (Android Studio / Genymotion).
- Rooted physical device for production-app research.
- Frida + objection installed.
- Decompilers (jadx, apktool, ghidra) on host.
- iOS: jailbroken older iPhone for research (find a used iPhone X / 11 — best price/value).

### Active Directory

- Small forest: 2 DCs + 1 ADCS + 2 member servers + 1 workstation.
- Tools: BloodHound, Rubeus, Certipy on Kali.
- Vulnerable templates / configurations pre-installed (GOAD, Vulnerable AD).
- Snapshot-restore script to reset after each lab session.

GOAD (Game of Active Directory) is the standard pre-built lab — saves weeks of setup.

### Exploit dev / RE

- Windows 10 / 11 + Visual Studio Build Tools + WinDbg Preview.
- Symbol cache configured.
- HEVD installed for kernel practice ([[hevd-stack-overflow-walkthrough]]).
- WSL2 for Linux pwn practice + pwntools.
- macOS VM (or physical) for macOS research.

### Cloud research

- Separate AWS / GCP / Azure accounts per research domain.
- **Billing alarms** at $20 / $50 / $100 thresholds.
- IAM throwaway users; never reuse credentials across labs.
- Terraform / Pulumi scripts to spin up vulnerable environments quickly.
- `stratus-red-team` for attack emulation; `Atomic Red Team`; `kube-hunter` for K8s.

### IoT / firmware

- USB-to-UART adapters (CP2102, FT232H, Bus Pirate).
- Logic analyser (Saleae Logic 8 — pricey but useful).
- SPI flash programmer.
- Solder station + soldering practice on cheap boards first.
- A bench of cheap routers / cameras to dissect.

### AI / LLM red teaming

- Local LLM (Ollama with various models) for offline testing.
- API access to commercial models (OpenAI, Anthropic, Google) — budget for tokens.
- MCP server local development.
- Sandboxed environment for agentic experiments.

## Networking

- **Pfsense / OPNsense** router VM for control.
- **VLANs** separating lab segments from your home.
- **WireGuard** for remote lab access.
- **Internet egress allowed**, ingress strictly blocked (lab not internet-reachable).
- **VPN for cloud-research target accounts** — egress IP allowlists.

## Tooling baseline

On a Kali / Parrot / dedicated VM:
- Burp Suite Pro (yearly fee — worth it).
- nmap, masscan, ffuf, nuclei, amass, subfinder, httpx.
- sqlmap, ghauri.
- pwntools, gef, gdb-multiarch.
- WinDbg Preview, IDA Free or Ghidra.
- Frida, objection.
- Foundry / Hardhat for blockchain.

Sync tooling state via dotfiles + Ansible / Nix.

## OPSEC for your lab

- **Don't mirror production** — never replicate real customer data, real keys.
- **Sanitise screenshots** before posting.
- **Don't blog about a still-open bug** until disclosed.
- **Air-gap or isolate** any actual sample malware (don't run unknown binaries on hypervisor that has access to your home network).
- **Encrypt at rest** — your lab disk contains research and credentials.

## Cost considerations

Rough monthly budget:
- **Power** (50–100 W idle workstation): ~$5–20.
- **VPS** (Hetzner / Vultr / DigitalOcean for cloud lab + public C2 lab): ~$10–50.
- **Subscriptions** (Burp, JetBrains, Ghidra/IDA): $50–500/year amortised.
- **Cloud research accounts**: variable, controlled by billing alarms.

Lab investment pays back in productivity. Don't economise too aggressively on RAM or disk.

## What to skip initially

- **Enterprise-grade hardware** — used SuperMicro at $500 is great; don't build a $5k server until you've proven you'll use it.
- **Every tool license** — start with free; pay when you outgrow.
- **A complete AD multi-forest replica** — start with single-domain.
- **Custom domain / DNS infrastructure** — use `lab.local` initially.

## Reset / snapshot discipline

Every research VM should have:
- A **clean baseline snapshot** before any compromise.
- A **research snapshot** during work.
- A **post-mortem snapshot** before destruction.

Without snapshots, you spend more time rebuilding than researching.

## Workflow to study

1. Start with one VM (Kali) on your workstation.
2. Add a Windows VM, set up snapshots.
3. Stand up GOAD on top of that.
4. Add a cloud account with billing alarms.
5. Iterate.

## Related

- [[ctf-to-bug-bounty-transition]]
- [[oscp-roadmap]]
- [[osep-roadmap]]
- [[oswe-roadmap]]
- [[osee-roadmap]]
- [[keeping-up-with-research-feeds]]
- [[firmware-emulation-firmadyne-qemu]]
- [[responsible-disclosure-across-jurisdictions]]

## References
- [GOAD (Game of Active Directory)](https://github.com/Orange-Cyberdefense/GOAD)
- [Proxmox VE](https://www.proxmox.com/)
- [Stratus Red Team](https://stratus-red-team.cloud/)
- [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team)
- [Vulhub — vulnerable Docker images](https://github.com/vulhub/vulhub)
- See also: [[ctf-to-bug-bounty-transition]], [[keeping-up-with-research-feeds]], [[firmware-emulation-firmadyne-qemu]]
