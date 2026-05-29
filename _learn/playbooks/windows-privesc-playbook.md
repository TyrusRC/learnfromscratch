---
title: "Windows privesc decision tree"
slug: windows-privesc-playbook
aliases: [windows-privesc-flow, winpeas-now-what]
mermaid: true
---

> **TL;DR.** You have a Windows shell. This playbook turns the
> usually-overwhelming winPEAS / Seatbelt output into a sequenced
> decision tree, with the modern token / service / installer paths
> ordered by likelihood.

## Step 1 — orient

```mermaid
flowchart TD
    A[Shell on Windows host] --> B[whoami /all; systeminfo; net user; net localgroup]
    B --> C{Domain-joined?}
    C -- yes --> D[Note domain; AD playbook is also relevant]
    C -- no --> E[Local-only escalation]
    D --> F[Run winPEAS / Seatbelt / PrivescCheck]
    E --> F
```

## Step 2 — token / privilege checks

```mermaid
flowchart TD
    A[Look at whoami /priv output] --> B{Which privileges are enabled?}
    B -- "SeImpersonate or SeAssignPrimaryToken" --> C[Open token-impersonation — Potato family]
    B -- "SeBackup or SeRestore" --> D[Read SAM / SYSTEM / SECURITY hives; dump offline]
    B -- "SeDebug" --> E[Inject into SYSTEM process via Mimikatz / Frida]
    B -- "SeTakeOwnership" --> F[Take ownership of a privileged file / service binary]
    B -- "SeManageVolume" --> G[Set ACL on volume-protected files]
    B -- "None usable" --> H[Step 3 — service / installer paths]
```

## Step 3 — services and installers

```mermaid
flowchart TD
    A[No useful token privs] --> B{Any of these true?}
    B -- "Unquoted service path with writable parent dir" --> C[Open unquoted-service-paths]
    B -- "Service binary or its DLL writable by your user" --> D[Open weak-service-permissions]
    B -- "Service config ACL grants you SERVICE_CHANGE_CONFIG" --> E[sc config + sc start = SYSTEM]
    B -- "AlwaysInstallElevated set in registry" --> F[Open always-install-elevated]
    B -- "MSI installer respawns / auto-repair" --> G[DLL hijack on installer path]
    B -- "Auto-elevate binary with hijackable DLL" --> H[Open dll-hijacking-privesc]
    B -- "Scheduled task with weak ACL" --> I[Modify task action / script]
    B -- "Service binary on a path you can plant DLLs in" --> J[Phantom DLL hijack]
    B -- "None" --> K[Step 4 — credentials / UAC / kernel]
```

## Step 4 — credentials and UAC

```mermaid
flowchart TD
    A[No service path] --> B{Look for stored credentials}
    B -- "cmdkey /list returns entries" --> C[runas /savecred with discovered identity]
    B -- "Group Policy Preferences cpassword in SYSVOL" --> D[Decrypt — instant domain creds]
    B -- "Unattend.xml / sysprep.inf on disk" --> E[Plaintext creds]
    B -- "Browser / mail / KeePass DBs readable" --> F[Open dpapi-secrets]
    B -- "Registry contains LSA / autologin secrets" --> G[Open lsa-secrets]
    B -- "Your user is in Administrators, just behind UAC" --> H[Open user-account-control — bypass]
```

## Step 5 — kernel and unpatched CVEs

```mermaid
flowchart TD
    A[All Step 1-4 paths fail] --> B[Check exact build via systeminfo / wmic qfe]
    B --> C{Patches missing for known privesc CVE?}
    C -- yes --> D[Verify exploit reliability vs target build in lab]
    D --> E{Reliable?}
    E -- yes --> F[Run]
    E -- no --> G[Don't risk it — pivot instead]
    C -- no --> H[Step 6 — lateral pivot, accept the foothold]
```

## Step 6 — pivot, don't escalate

```mermaid
flowchart TD
    A[Escalation stuck] --> B{What does the current user reach?}
    B -- "Adjacent hosts via SMB / WinRM" --> C[Open lateral-movement-playbook]
    B -- "Saved cloud / Azure CLI / AWS CLI tokens" --> D[Open cloud-foothold-playbook]
    B -- "Internal web app the user can authenticate to" --> E[Open web-triage]
    B -- "Domain-user privileges in AD" --> F[Open ad-attack-path-playbook]
```

## Where to go next

- Got SYSTEM → [[credential-dumping]] (LSASS, SAM, DPAPI, NTDS via
  Backup priv).
- Got SYSTEM in AD → straight to [[ad-attack-path-playbook]] step
  "from local admin to DA".
- Stuck → consider whether the box is worth more time vs lateral
  pivot.

## Detection-aware notes

- LSASS dumping via comsvcs / direct read is the loudest signal you
  can emit on a modern EDR — defer if the engagement has detection
  goals; see [[edr-hooks-and-unhooking]].
- Loading nimble UAC bypasses on hosts with WDAG enabled is wasted
  effort; check `wmic os get OSArchitecture, BuildNumber` first.
