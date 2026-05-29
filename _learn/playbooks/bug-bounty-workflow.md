---
title: "Bug-bounty workflow"
slug: bug-bounty-workflow
aliases: [bug-bounty-flow, bb-program-to-report]
mermaid: true
---

> **TL;DR.** Bug bounty is a pipeline, not a search. This playbook
> takes you from program-list to paid report, with the decision
> points where most hunters lose hours.

## End-to-end flow

```mermaid
flowchart TD
    A[Open program list — HackerOne / Bugcrowd / Intigriti / YesWeHack / private] --> B{Picking the right target}
    B --> C[Read scope carefully — open program-scope-reading]
    C --> D{Mature or fresh?}
    D -- "mature, high payout" --> E[Need novel angle — recon or new feature]
    D -- "fresh / recently launched" --> F[Standard methodology works]
    E --> G[Step 2 — recon]
    F --> G
    G --> H[Step 3 — hunt]
    H --> I{Found bug?}
    I -- yes --> J[Step 4 — confirm + impact]
    I -- no --> K[Rotate target, document partials]
    J --> L[Step 5 — report]
    L --> M{Triaged?}
    M -- accepted --> N[Patch + bounty]
    M -- duplicate --> O[Take lesson — start over earlier in graph]
    M -- N/A --> P[Argue impact once; if rejected, accept]
```

## Step 1 — picking the right program

```mermaid
flowchart TD
    A[Available programs] --> B{What matches your skills?}
    B -- "Web app / API" --> C[Open web-application-security or api-security]
    B -- "Mobile" --> D[Open mobile-security]
    B -- "Smart contract" --> E[Open blockchain-security]
    B -- "Cloud / SaaS" --> F[Open cloud-red-team]
    C --> G{Payout vs. competition?}
    D --> G
    E --> G
    F --> G
    G -- "high payout, lots of hunters" --> H[Need recon or novel-tech angle]
    G -- "lower payout, less competition" --> I[Standard methodology pays]
    G -- "private invite" --> J[Less competition, often better signal-to-noise]
```

## Step 2 — recon

```mermaid
flowchart TD
    A[Scope confirmed] --> B{Scope shape?}
    B -- "*.target.com (vertical)" --> C[Open subdomain-enumeration + certificate-transparency]
    B -- "Multiple apex domains (horizontal)" --> D[Open acquisitions-recon + asn-enumeration + reverse-whois]
    B -- "Single host" --> E[Skip horizontal, go direct to content-discovery]
    C --> F[Run tools: subfinder + amass + httpx + nuclei + katana]
    D --> F
    E --> F
    F --> G[Diff against last scan; alert on new — see continuous-recon-automation]
    G --> H[For each new asset: fingerprint + JS-recon + content-discovery]
    H --> I{High-value asset?}
    I -- yes --> J[Step 3]
    I -- no --> K[Park for later, focus elsewhere]
```

## Step 3 — hunt

```mermaid
flowchart TD
    A[Picked asset] --> B[Walk the app as a real user — open getting-feel-for-target]
    B --> C[Map auth boundaries: anon vs user vs admin vs tenant]
    C --> D{Choose attack angle}
    D -- "Auth / AuthZ" --> E[Open broken-access-control / idor / bola / bfla]
    D -- "Input handling" --> F[Open web-triage playbook]
    D -- "Recon-found tech CVE" --> G[Open known-vuln-workflow]
    D -- "Logic / business flow" --> H[Open application-logic-flaws]
    D -- "Auth tokens (JWT / SAML / OAuth)" --> I[Open jwt / saml-attacks / oauth-token-theft]
    E --> J{Found anomaly?}
    F --> J
    G --> J
    H --> J
    I --> J
    J -- yes --> K[Confirm — Step 4]
    J -- no --> L[Expand attack surface — open expanding-attack-surface]
```

## Step 4 — confirm and demonstrate impact

```mermaid
flowchart TD
    A[Anomaly found] --> B[Reproduce in clean session]
    B --> C{Reproducible?}
    C -- "yes, consistent" --> D[Step 5 — write up]
    C -- "intermittent" --> E[Try to identify the variable — race, cache, region, account state]
    E --> F{Repro nailed?}
    F -- yes --> D
    F -- no --> G[Submit with caveats; mention non-determinism]
    D --> H{Impact obvious?}
    H -- yes --> I[Move to report]
    H -- "no — bug exists but impact is unclear" --> J[Open demonstrating-impact — chain or escalate]
    J --> K{Chained?}
    K -- yes --> I
    K -- no --> L[Decide: report as-is for info, or shelve]
```

## Step 5 — report

```mermaid
flowchart TD
    A[Ready to write] --> B[Open report-writing-step-by-step]
    B --> C[Title — descriptive, not 'XSS in app']
    C --> D[Summary — what + where + why bad in three sentences]
    D --> E[Severity — CVSS only if it adds clarity]
    E --> F[Reproduction — numbered, copy-pasteable, environment-stated]
    F --> G[Impact — concrete worst-case for the program]
    G --> H[Recommendation — short, non-prescriptive]
    H --> I[Validate — re-read as triager; cut anything that bloats]
    I --> J[Submit]
```

## After submission

```mermaid
flowchart TD
    A[Report submitted] --> B{Triage response}
    B -- "Triaged + valid" --> C[Wait for fix; respond to questions promptly]
    B -- "Duplicate" --> D[Open dupe-mental-model — note what got it dup'd, adjust]
    B -- "N/A — not applicable" --> E{Disagree?}
    E -- yes --> F[One polite, evidence-heavy argument]
    F --> G{Reversed?}
    G -- yes --> C
    G -- no --> H[Accept, move on]
    E -- no --> H
    B -- "Asking for more info" --> I[Provide cleanly — open disclosure-and-comms]
    I --> B
```

## Burnout / pipeline management

```mermaid
flowchart TD
    A[Three+ consecutive dry sessions] --> B[Rotate target]
    B --> C{Still dry across 2-3 targets?}
    C -- yes --> D[Step back — read disclosed reports, study a new bug class]
    C -- no --> E[Back to the hunt]
    D --> F[Pick a fresh program after 1-2 weeks]
```

## Anti-patterns

- Skipping scope reading and submitting an out-of-scope finding.
- Spamming low-impact reports for volume; reputation tanks fast.
- Chasing 0-days when basic auth-z testing pays better.
- Re-reading the same WAHH chapter instead of testing.
- Not keeping recon delta — you re-discover yesterday's subdomains
  every time.

## Where to go next

- Methodology depth → [[bug-bounty-methodology]].
- Specific bug class → [[web-triage]] picks the lane.
- Engagement-level mental model → [[bug-bounty-index|bug bounty
  topics]].
