---
title: "Linux privesc decision tree"
slug: linux-privesc-playbook
aliases: [linux-privesc-flow, linpeas-now-what]
mermaid: true
---

> **TL;DR.** You have a Linux shell. This playbook turns the
> usually-overwhelming linpeas / lse output into a sequenced decision
> tree.

## Step 1 — orient

```mermaid
flowchart TD
    A[Shell as low-priv user] --> B[whoami; id; hostname; uname -a]
    B --> C[Read /etc/os-release; sudo -V]
    C --> D{Container or VM?}
    D -- container --> E[Open container-escape-techniques branch below]
    D -- VM / bare metal --> F[Standard enumeration]
    F --> G[Run linpeas.sh / lse.sh; tee output for review]
```

## Step 2 — easy wins first

```mermaid
flowchart TD
    A[Enum results in hand] --> B{Any of these true?}
    B -- "sudo -l shows ANY entry" --> C[Open sudo-misconfig]
    B -- "SUID binaries with GTFOBins entry" --> D[Open suid-sgid-binaries]
    B -- "Writable /etc/passwd or /etc/shadow" --> E[Open writable-passwd-shadow — instant root]
    B -- "User in 'docker' / 'lxd' / 'disk' / 'shadow' group" --> F[Group → root path; see [[linux-privesc-vectors]]]
    B -- "Cap-listed binary with cap_setuid+ep or cap_dac_read+ep" --> G[Open capabilities-privesc]
    B -- "Mounted NFS no_root_squash share" --> H[Open nfs-no-root-squash]
    B -- "Writable cron / systemd / init script as root" --> I[Open cron-jobs]
    B -- "LD_PRELOAD env_keep in sudoers" --> J[Open ld-preload-abuse]
    B -- "World-writable directory on root's PATH" --> K[Open path-hijacking]
    B -- "None of the above" --> L[Step 3 — harder paths]
```

## Step 3 — harder paths

```mermaid
flowchart TD
    A[No easy win] --> B[Check kernel version vs known exploits]
    B --> C{Kernel exploit looks viable?}
    C -- yes --> D[Open kernel-exploits-linux; verify in lab first]
    C -- no --> E[Check /var/backups, /home, /opt for creds]
    E --> F{Credentials / SSH keys found?}
    F -- yes --> G[su / ssh to another user; restart from Step 1]
    F -- no --> H[Look at running processes — pspy]
    H --> I{Root process accepting input you control?}
    I -- yes --> J[Privesc via that process - input fuzz / file plant]
    I -- no --> K[Step 4 — container / namespace surface]
```

## Step 4 — container / namespace escape

```mermaid
flowchart TD
    A[In a container] --> B[Check capabilities: capsh --print]
    B --> C{CAP_SYS_ADMIN, CAP_DAC_READ_SEARCH, or CAP_SYS_PTRACE?}
    C -- yes --> D[Open container-escape-techniques — release_agent / proc-mount]
    C -- no --> E{Mounted host paths?}
    E -- "/var/run/docker.sock" --> F[Open container-escape-techniques — docker.sock branch]
    E -- "host /" --> G[chroot . sh — done]
    E -- "/proc or /sys exposed" --> H[Specific escape per mount]
    C -- "User namespace bug?" --> I[Open user-namespace-attacks]
```

## Step 5 — pivot, don't escalate

If you can't root the box, sometimes the foothold is enough.

```mermaid
flowchart TD
    A[Local escalation stuck] --> B{What does this user / box let you reach?}
    B -- "Other hosts via SSH key reuse" --> C[Try, restart enum on new host]
    B -- "Service the user owns" --> D[Compromise the service — config write, restart]
    B -- "Cloud metadata reachable" --> E[Open ssrf-to-cloud / aws-instance-metadata]
    B -- "Internal-only web service" --> F[Open web-triage]
    B -- "Database with sensitive data" --> G[Document — sometimes the bug is data access]
```

## Where to go next

- Got root → [[linux-enumeration]] for post-ex (creds, persistence).
- Got pivot creds → restart at Step 1 on the next host.
- Stuck and time-boxed → write up what you found; partial wins still
  count.

## Anti-patterns

- Reading 40 GTFOBins entries before running `sudo -l`.
- Compiling a kernel exploit without a matching lab kernel first.
- Running aggressive enumeration scripts when the host has EDR — see
  [[ad-recon-low-noise]] for the principle.
