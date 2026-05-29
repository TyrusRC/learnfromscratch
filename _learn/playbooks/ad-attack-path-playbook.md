---
title: "Active Directory attack path"
slug: ad-attack-path-playbook
aliases: [ad-playbook, foothold-to-da]
mermaid: true
---

> **TL;DR.** You have a domain-user foothold. This is the canonical
> "domain user → Domain Admin" decision tree. Most internal pentests
> and most AD-themed CTFs walk this graph.

## Top-level path

```mermaid
flowchart TD
    A[Domain user shell or creds] --> B[Run SharpHound / BloodHound CE collection]
    B --> C[Open BloodHound; mark owned principal]
    C --> D[Run pre-baked queries: 'Shortest paths to Domain Admins', 'Shortest paths from owned']
    D --> E{Direct path shown?}
    E -- yes --> F[Walk the path — each edge has a topic note]
    E -- no --> G[Manual primitives, see below]
    F --> H[Reached DA / DC sync]
    G --> H
```

## Pre-creds primitives (you have a username but no password)

```mermaid
flowchart TD
    A[Username list, no creds] --> B{Pre-auth check}
    B -- "Got AS-REP" --> C[Open asreproast — crack offline]
    B -- "All require pre-auth" --> D[Password spray slowly — see password-spraying]
    D --> E{Got a password?}
    E -- yes --> F[Validate scope — proceed to next stage]
    E -- no --> G[Move on; revisit with new wordlists]
    C --> F
```

## SPN / kerberoasting

```mermaid
flowchart TD
    A[Any domain user] --> B[GetUserSPNs / Rubeus kerberoast]
    B --> C{Got service tickets?}
    C -- yes --> D[hashcat -m 13100 — try wordlist + rules + masks]
    D --> E{Cracked?}
    E -- yes --> F[Now have service-account creds — often privileged]
    E -- no --> G[Move on]
```

## ACL abuse (BloodHound-visible)

```mermaid
flowchart TD
    A[Owned principal has outbound ACL edge] --> B{Which edge?}
    B -- "GenericAll / GenericWrite on user" --> C[Open shadow-credentials — easy PKINIT takeover]
    B -- "GenericAll / GenericWrite on computer" --> D[RBCD attack — see resource-based-constrained-delegation]
    B -- "ForceChangePassword on user" --> E[net user / Set-DomainUserPassword — open acl-abuse]
    B -- "AddMembers on group" --> F[Add yourself; replay BloodHound]
    B -- "WriteDACL on object" --> G[Grant yourself GenericAll; chain again]
    B -- "WriteOwner on object" --> H[Take ownership, then WriteDACL]
    B -- "GenericWrite on GPO linked to OU" --> I[Open gpo-abuse]
```

## AD CS — the certificate path (very common)

```mermaid
flowchart TD
    A[Any authenticated user] --> B[Certipy find / Certify find — enumerate templates]
    B --> C{Any vulnerable template?}
    C -- "ESC1: client auth + ENROLLEE_SUPPLIES_SUBJECT" --> D[Request cert as DA — see adcs-attacks]
    C -- "ESC2 / ESC3 / ESC4 etc" --> E[Per-class flow in adcs-attacks]
    C -- "ESC8: web enrollment + NTLM relay" --> F[Open ms-rpc-abuse — coerce, relay to /certsrv]
    C -- "ESC14 / ESC15 / ESC16" --> G[Per-edge: open adcs-esc14-altsecidentities / -esc15-ekuwu / -esc16-securityext-disabled]
    C -- "None" --> H[Skip ADCS branch]
    D --> I[PKINIT + UnPAC-the-Hash = NTLM hash of target]
```

## Delegation abuse

```mermaid
flowchart TD
    A[Account has delegation attributes] --> B{Type?}
    B -- "Unconstrained on host" --> C[Open unconstrained-delegation — pair with PrinterBug coercion]
    B -- "Constrained (msDS-AllowedToDelegateTo)" --> D[Open constrained-delegation — S4U2Self + S4U2Proxy]
    B -- "RBCD (msDS-AllowedToActOnBehalfOfOtherIdentity writable)" --> E[Open resource-based-constrained-delegation]
```

## Coerced auth (no creds for the target, just network reachability)

```mermaid
flowchart TD
    A[Need a target machine to auth to you] --> B{Which trigger?}
    B -- "PrinterBug" --> C[Open ms-rpc-abuse]
    B -- "PetitPotam (EFS)" --> C
    B -- "DFSCoerce" --> C
    B -- "Other MS-RPC" --> C
    C --> D{Pair with what?}
    D -- "Relay to LDAP (signing off)" --> E[Set RBCD on target → impersonate]
    D -- "Relay to AD CS web enrollment" --> F[Request cert as machine account]
    D -- "Relay to SMB (signing off)" --> G[Execute as relayed account]
    D -- "Inbound to a host with unconstrained delegation" --> H[Capture TGT — pop DA]
```

## Reaching DA / DCSync

```mermaid
flowchart TD
    A[Compromised privileged principal] --> B{Replication rights?}
    B -- yes --> C[Open dcsync — pull krbtgt + everyone]
    B -- no but DA --> D[Run DCSync as DA]
    C --> E[Open golden-tickets — domain persistence]
    D --> E
    E --> F{Cross-domain / forest goal?}
    F -- yes --> G[Open child-to-forest-root]
    F -- no --> H[Document, persist, exit]
```

## Persistence (only when in scope)

```mermaid
flowchart TD
    A[Have DA] --> B[Open ad-persistence]
    B --> C{Risk budget?}
    C -- "low noise" --> D[Shadow Credentials on selected high-priv accounts]
    C -- "medium" --> E[AdminSDHolder ACL backdoor]
    C -- "high" --> F[Skeleton Key / DCShadow]
```

## Where to go next

- DA achieved → goal of most internal engagements; document and clean
  up per scope rules.
- DA in child, want forest → [[child-to-forest-root]].
- Want low-noise variant → [[ad-recon-low-noise]] +
  [[opsec-fundamentals]].
- Want to chain to cloud (Entra hybrid) →
  [[entra-connect-exploitation-2025]] →
  [[cloud-foothold-playbook]].

## Anti-patterns

- Running default SharpHound options on monitored environments
  (`-c All` is loud — use `-c Group,LocalGroup,Session,Trusts` or
  similar for opsec).
- Spraying passwords without checking the lockout policy first.
- Running Mimikatz unencoded on a host with Defender enabled in 2026.
