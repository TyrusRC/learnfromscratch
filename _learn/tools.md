---
title: Tools
slug: tools
aliases: [tooling, tool-index]
---

> Categorised tool index — one line per tool with a link. Notes on
> specific tool tradecraft live in their own pages under
> [[red-team-index]] or under the relevant topic.

## Web / API

- [Burp Suite](https://portswigger.net/burp) — the proxy.
- [Caido](https://caido.io/) — Rust-native modern proxy alternative.
- [ffuf](https://github.com/ffuf/ffuf) — content / parameter fuzzer.
- [Nuclei](https://github.com/projectdiscovery/nuclei) — template-based
  scanner.
- [httpx](https://github.com/projectdiscovery/httpx) — HTTP probe.
- [katana](https://github.com/projectdiscovery/katana) — crawler.
- [arjun](https://github.com/s0md3v/Arjun) — parameter discovery.
- [GraphQL Voyager](https://graphql-kit.com/graphql-voyager/) — schema
  viewer.
- [kiterunner](https://github.com/assetnote/kiterunner) — API endpoint
  discovery.

## Recon

- [Amass](https://github.com/owasp-amass/amass) — asset discovery.
- [Subfinder](https://github.com/projectdiscovery/subfinder) — passive
  subdomain enum.
- [Assetfinder](https://github.com/tomnomnom/assetfinder).
- [waybackurls](https://github.com/tomnomnom/waybackurls).
- [gau](https://github.com/lc/gau) — get-all-urls.
- [trufflehog](https://github.com/trufflesecurity/trufflehog) —
  secret scanning across git history.
- [gitleaks](https://github.com/gitleaks/gitleaks).

## Network

- [Nmap](https://nmap.org/) · [Masscan](https://github.com/robertdavidgraham/masscan).
- [RustScan](https://github.com/RustScan/RustScan).
- [Responder](https://github.com/lgandx/Responder) — LLMNR / NBT-NS /
  mDNS poisoner.
- [Impacket](https://github.com/fortra/impacket) — Python AD toolbox.
- [CrackMapExec / NetExec](https://github.com/Pennyw0rth/NetExec).
- [evil-winrm](https://github.com/Hackplayers/evil-winrm).

## AD / Windows post-ex

- [BloodHound CE](https://github.com/SpecterOps/BloodHound) ·
  [SharpHound](https://github.com/SpecterOps/SharpHound).
- [Certify](https://github.com/GhostPack/Certify) — AD CS abuse.
- [Rubeus](https://github.com/GhostPack/Rubeus) — Kerberos.
- [Mimikatz](https://github.com/gentilkiwi/mimikatz).
- [SharpView](https://github.com/tevora-threat/SharpView).
- [PowerView](https://github.com/PowerShellMafia/PowerSploit/blob/master/Recon/PowerView.ps1).

## Linux post-ex

- [LinPEAS / WinPEAS](https://github.com/peass-ng/PEASS-ng).
- [LinEnum](https://github.com/rebootuser/LinEnum).
- [pspy](https://github.com/DominicBreuker/pspy) — process snooping.
- [GTFOBins](https://gtfobins.github.io/).

## Exploit dev

- [WinDbg](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/).
- [x64dbg](https://x64dbg.com/).
- [IDA Free](https://hex-rays.com/ida-free/) ·
  [Ghidra](https://ghidra-sre.org/) ·
  [Binary Ninja](https://binary.ninja/).
- [mona.py](https://github.com/corelan/mona) — Immunity / WinDbg
  helper for exploit dev.
- [pwntools](https://github.com/Gallopsled/pwntools) — Linux CTF
  exploit dev.
- [Frida](https://frida.re/) · [radare2](https://rada.re/).

## Red team

- [Sliver](https://github.com/BishopFox/sliver) — open-source C2.
- [Mythic](https://github.com/its-a-feature/Mythic) — multi-agent C2
  framework.
- [Havoc](https://github.com/HavocFramework/Havoc).
- [Cobalt Strike](https://www.cobaltstrike.com/) (commercial, license
  required).
- [Brute Ratel](https://bruteratel.com/) (commercial).
- [Inceptor](https://github.com/klezVirus/inceptor) — payload
  template-er.
- [chisel](https://github.com/jpillora/chisel) · [ligolo-ng](https://github.com/nicocha30/ligolo-ng)
  — pivoting.

## Cloud

- [Pacu](https://github.com/RhinoSecurityLabs/pacu) — AWS exploitation
  framework.
- [ScoutSuite](https://github.com/nccgroup/ScoutSuite) — multi-cloud
  auditor.
- [Prowler](https://github.com/prowler-cloud/prowler) — AWS / Azure /
  GCP security assessment.
- [Stormspotter](https://github.com/Azure/Stormspotter) — Azure /
  Entra graph.
- [ROADtools / ROADrecon](https://github.com/dirkjanm/ROADtools) — Entra
  ID enumeration.
- [GCP IAM Privilege Escalation](https://github.com/RhinoSecurityLabs/GCP-IAM-Privilege-Escalation)
  — GCP method scripts.
- [kubectl-who-can](https://github.com/aquasecurity/kubectl-who-can) ·
  [peirates](https://github.com/inguardians/peirates) — K8s.

## AI red team

- [garak](https://github.com/leondz/garak) — LLM scanner.
- [PyRIT](https://github.com/Azure/PyRIT) — automated red-team prompts.
- [PromptInject](https://github.com/agencyenterprise/PromptInject).
- [llm-attacks (GCG suffixes)](https://github.com/llm-attacks/llm-attacks).
- [Awesome LLM Security](https://github.com/corca-ai/awesome-llm-security).
