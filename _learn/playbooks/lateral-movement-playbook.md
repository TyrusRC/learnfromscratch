---
title: "Lateral movement decisions"
slug: lateral-movement-playbook
aliases: [lateral-movement-flow, pick-the-pivot]
mermaid: true
---

> **TL;DR.** You have credentials, a hash, a ticket, or a session.
> The wrong lateral primitive gets you caught. This playbook picks
> the lowest-noise primitive your material and target allow.

## What's in your hand?

```mermaid
flowchart TD
    A[Hold something — what?] --> B{Material type}
    B -- "Plaintext password" --> C[Most options — branch on target port / EDR]
    B -- "NT hash" --> D[Open pass-the-hash + overpass-the-hash]
    B -- "AES key" --> E[Overpass-the-hash with AES — see overpass-the-hash]
    B -- "TGT (.ccache / .kirbi)" --> F[Open pass-the-ticket]
    B -- "Service ticket TGS" --> G[Pass-the-ticket for that service only]
    B -- "Cert + key (PFX)" --> H[PKINIT auth as the cert subject]
    B -- "Session cookie / token" --> I[Token-impersonation if local, replay if remote API]
```

## Pick by target port

```mermaid
flowchart TD
    A[Have credentials / hash] --> B{Which ports open on target?}
    B -- "445 SMB only" --> C[psexec / smbexec — see smb-exec]
    B -- "445 + 135 RPC" --> D[wmiexec or dcomexec — see wmi-exec / dcom-exec]
    B -- "5985 / 5986 WinRM" --> E[evil-winrm — see winrm-exec; quietest option]
    B -- "3389 RDP" --> F[xfreerdp / mstsc — clean-up logs after]
    B -- "22 SSH" --> G[Linux target — see ssh-execution]
    B -- "Only 80 / 443" --> H[Pivot via the app — open web-triage]
```

## Pick by detection budget

```mermaid
flowchart TD
    A[Decided which port] --> B{EDR posture}
    B -- "Heavy EDR with behavioural detection" --> C[Prefer WinRM, scheduled task on existing service, or DCOM ShellWindows]
    B -- "Sysmon + central SIEM" --> D[Use built-in protocols, avoid LOLBins flagged in red-team blue-team reports]
    B -- "No detection / lab" --> E[Anything works — psexec is fine]
    B -- "Unknown" --> F[Assume some EDR; default to lowest-noise option]
```

## Decision: SMB-exec family

```mermaid
flowchart TD
    A[Pick SMB lateral primitive] --> B{Need persistence on target?}
    B -- yes --> C[psexec — creates / starts a service, easy to spot]
    B -- "no, just one-shot" --> D[smbexec or wmiexec — no service, less noise]
    D --> E{Need stdout back?}
    E -- yes --> F[wmiexec — handles stdout cleanly]
    E -- no --> G[smbexec or atexec — quieter still]
```

## Decision: Kerberos (use a ticket / hash)

```mermaid
flowchart TD
    A[Have ticket or AES key] --> B{Need to forge?}
    B -- "Forging a service ticket" --> C[Open silver-tickets]
    B -- "Forging a TGT" --> D[Open golden-tickets — domain persistence]
    B -- "Reusing legitimately issued tickets" --> E[Open pass-the-ticket]
    B -- "Request TGS for a SPN" --> F[Standard kinit / Rubeus asktgs]
```

## Decision: pivot through compromised host

```mermaid
flowchart TD
    A[Target not reachable from your host] --> B{Compromised host has outbound?}
    B -- yes --> C[Set up SOCKS / port-forward — see chisel / ligolo-ng]
    B -- "no outbound (locked-down)" --> D[Use the existing C2 channel as transport]
    C --> E[Run lateral tooling through proxychains / built-in client]
    D --> E
```

## Hash-to-DA shortcut tree

```mermaid
flowchart TD
    A[Have a useful NT hash] --> B{Whose hash?}
    B -- "Local admin reused across hosts" --> C[Spray hash across subnet — open pass-the-hash]
    B -- "Domain user" --> D[Overpass-the-hash → use TGT — open overpass-the-hash]
    B -- "Computer account" --> E[Use for RBCD / S4U / certificate request]
    B -- "krbtgt" --> F[Golden ticket — open golden-tickets]
    B -- "Service account with SPN" --> G[Silver ticket for that service — open silver-tickets]
```

## After arrival

```mermaid
flowchart TD
    A[Landed on new host] --> B[Mark owned in BloodHound]
    B --> C[Re-run windows-privesc-playbook]
    C --> D{Did we just unlock new edges?}
    D -- yes --> E[Re-query BloodHound]
    D -- no --> F[Continue current path]
    E --> G[Pick best edge — see ad-attack-path-playbook]
```

## Anti-patterns

- Hammering the same host with five lateral tools in a row — first
  succeeded tool is what defenders see; pick one.
- Using local-admin password sprays in 2026 environments with LAPS
  enabled (waste of time and noisy).
- Running Mimikatz on a host you intend to leave clean — dump LSASS
  remotely from your beacon instead.
- Forgetting to revoke / clean up scheduled tasks / service stubs
  you created.

## Where to go next

- Each lateral primitive has a topic note — open it for syntax.
- Got DA → [[ad-attack-path-playbook]] for persistence and forest
  reach.
- Got cloud token instead → [[cloud-foothold-playbook]].
