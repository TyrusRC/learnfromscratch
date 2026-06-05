---
title: Bug bounty — topics
slug: bug-bounty-index
aliases: [bug-bounty-topics]
---

Methodology, recon, and process notes. See [[bug-bounty-methodology]]
for path ordering.

## Mindset and target selection
- [[hacker-mindset-questioning]]
- [[program-scope-reading]] · [[scope-vertical-vs-horizontal]]
- [[target-selection-heuristics]] · [[program-selection-tactics]]
- [[asset-graphing]]

## Recon — passive and active
- [[subdomain-enumeration]] · [[content-discovery]]
- [[js-recon]] · [[js-endpoint-extraction]]
- [[github-recon]] · [[third-party-recon]]
- [[google-dorking]] · [[certificate-transparency]]
- [[acquisitions-recon]] · [[asn-enumeration]] · [[reverse-whois]]
- [[vhost-enumeration]] · [[subdomain-permutation]]
- [[endpoint-spidering]] · [[wordlist-fuzzing-tactics]]
- [[analytics-tag-correlation]] · [[cloud-asset-recon]]
- [[tech-stack-fingerprinting]]
- [[cidr-enumeration]] · [[recon-data-services]]

## Tooling
- [[burp-suite-toolkit]]

## Methodology workflow
- [[getting-feel-for-target]] (step 1)
- [[expanding-attack-surface]] (step 2)
- [[automation-and-rinse-repeat]] (step 3)
- [[common-issues-to-start-with]]
- [[note-taking-while-hacking]]
- [[continuous-recon-automation]]

## Execution patterns
- [[known-vuln-workflow]] — tech → CVE → PoC → exploit.
- [[n-day-rapid-exploitation]] — race the patch window.
- [[one-day-from-patch-diff]] — patch-diff to 1-day.
- [[reading-public-pocs-effectively]] — mining public PoCs.
- [[login-page-attacks]] · [[account-takeover-patterns]]
- [[automated-fuzzer-vuln-discovery]]
- [[testing-methodology-checklists]]
- [[demonstrating-impact]]

## Keeping current
- [[keeping-up-with-research-feeds]] — RSS / advisory / blog pipeline
- [[h1-disclosed-report-reading-method]] — H1 hacktivity mining

## Practitioner pipeline
- [[ctf-to-bug-bounty-transition]] — moving from CTF to bounty
- [[building-a-research-home-lab]] — lab setup by research area
- [[responsible-disclosure-across-jurisdictions]] — legal landscape

## Lab / CTF / certification walkthroughs
- [[htb-machine-walkthrough-methodology]]
- [[pwn-college-walkthrough-methodology]]
- [[oscp-style-box-attack-pattern]]
- [[vulnhub-walkthrough-pattern]]
- [[ctf-jeopardy-pwn-strategy]]

## Conference research summaries
- [[blackhat-2024-2025-research-roundup]]
- [[defcon-2024-2025-research-roundup]]
- [[usenix-ndss-research-summary]]
- [[portswigger-top-10-by-year]]

## Case studies — public disclosures
- [[case-study-h1-top-disclosed-2024-2025]] — recent H1 patterns
- [[case-study-orange-tsai-research-pattern]] — Devcore / Orange Tsai method
- [[case-study-portswigger-top-10-pattern]] — PortSwigger annual method
- [[case-study-google-vrp-writeup-patterns]] — Google VRP patterns

## Process and meta
- [[report-writing]] · [[report-writing-step-by-step]]
- [[disclosure-and-comms]]
- [[dupe-mental-model]]
- [[burnout-and-pipeline]]

## Certification exam methodology
- [[oscp-exam-methodology]]

## Modern bug-bounty patterns
- [[account-takeover-modern-chains]]
- [[third-party-saas-misconfig-patterns]]

## Per-bounty-type methodology
- [[mobile-bug-bounty-methodology]]
- [[api-bug-bounty-workflow]]
- [[web3-bug-bounty-methodology]]
- [[cloud-bug-bounty-methodology]]
- [[ai-llm-bug-bounty-methodology]]
- [[hardware-iot-bug-bounty-programs]]
- [[ics-ot-bug-bounty-programs]]
- [[embedded-firmware-bug-bounty-methodology]]

## Platform deep dives
- [[hackerone-platform-deep]]
- [[bugcrowd-platform-deep]]
- [[intigriti-yeswehack-european-platforms]]
- [[code4rena-sherlock-cantina-web3]]
- [[huntr-dev-and-oss-bounty]]

## Process and operations
- [[cvss-scoring-practitioner]]
- [[bounty-triage-from-hunters-view]]
- [[pre-disclosure-embargo-and-cve-coordination]]
- [[collaborative-bug-bounty-hunting]]
- [[live-hacking-event-playbook]]

## Income and career
- [[bug-bounty-income-tax-international]]
- [[bug-bounty-as-career-track]]
- [[bug-bounty-platform-payouts-and-currency]]
