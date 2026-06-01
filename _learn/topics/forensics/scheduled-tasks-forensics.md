---
title: Scheduled-task forensics
slug: scheduled-tasks-forensics
---

> **TL;DR:** Every Windows scheduled task leaves three artefacts — an XML in `C:\Windows\System32\Tasks\`, a registry entry under `HKLM\Software\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\`, and TaskScheduler EVTX events — and reading them together reliably catches "hidden" persistence that `schtasks.exe /Query` itself misses.

## What it is
The Windows Task Scheduler is one of the top three persistence mechanisms in real-world intrusions (alongside services and Run keys). The on-disk format is well-defined and resilient to common tampering — attackers who delete the XML often forget the registry mirror, and vice versa. Knowing all three storage locations and how to reconcile them is the core of scheduled-task triage.

## Preconditions / where it applies
- DFIR on a Windows host (live or imaged). Works the same way on Win7 onwards.
- Useful in red-team OPSEC ("did my task leave the expected artefacts?").

## Technique
**1. The three storage locations.**

| Artefact | Path | What it has |
|---|---|---|
| XML | `C:\Windows\System32\Tasks\<TaskFolder>\<TaskName>` | Full task definition: action, trigger, principal, hidden flag |
| Registry — Tasks | `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\{GUID}` | Maps GUID → task path; has `Id`, `Path`, `Hash`, `Index`, `Triggers` (binary blob), `DynamicInfo`, `Actions` (binary blob) |
| Registry — Tree | `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\<TaskFolder>\<TaskName>` | Hierarchy view; key default value = task GUID |
| Event log | `Microsoft-Windows-TaskScheduler/Operational` (IDs 100 / 106 / 140 / 141 / 200 / 201) | Run / register / update / delete / launched / completed |

A task is "valid" when all three (XML + Tasks GUID + Tree pointer) are consistent. Drop or tamper one and the task is still triggerable but easier to miss in basic enumeration.

**2. Read the XML.** XML is the easiest to parse offline.
```bash
ls -lR C:/Windows/System32/Tasks
# offline (imaged volume)
python -m defusedxml.lxml Tasks/Microsoft/Windows/Defrag/ScheduledDefrag
```

Interesting elements:
- `<Principals>/<Principal><UserId>` — `S-1-5-18` = SYSTEM (privesc persistence!).
- `<Settings><Hidden>true</Hidden>` — invisible to `schtasks /Query` and Task Scheduler MMC.
- `<Triggers>` — when it fires; `<LogonTrigger>`, `<BootTrigger>`, `<CalendarTrigger>`, `<EventTrigger><Subscription>...` for trigger-on-EVTX-event (clever persistence).
- `<Actions><Exec><Command>` and `<Arguments>` — payload.
- `<URI>` — task's logical path; should match its location on disk.
- `<Date>` — task creation timestamp (attacker can forge but most don't).

**3. Read the registry side.** When the XML is missing, the registry still holds enough.
```cmd
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree" /s
```
or offline with RegRipper `rip.pl -r SOFTWARE -p scheduledtasks`.

The `TaskCache\Tasks\{GUID}\Actions` binary value decodes to UTF-16 strings of the command + arguments; the `Triggers` blob decodes to the trigger schedule. Both are parsed by:
- **EvtxECmd**'s `TaskScheduler` maps,
- **RegistryExplorer** with the `Scheduled Tasks` map,
- **Velociraptor** artefact `Windows.Forensics.ScheduledTasks`,
- **`schtasks /Query /FO LIST /V`** on a live host (but this misses hidden / SD-stripped tasks).

**4. Event log correlation.** `Microsoft-Windows-TaskScheduler/Operational`:

| ID | Meaning |
|---|---|
| 106 | Task registered |
| 140 | Task updated |
| 141 | Task deleted |
| 200 | Action started (process launched) |
| 201 | Action completed |
| 102 | Task completed |
| 129 | Task launched as user instance |

```powershell
Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -FilterXPath "*[System[EventID=106 or EventID=140]]" |
  ForEach-Object { [pscustomobject]@{Time=$_.TimeCreated; Id=$_.Id; Task=$_.Properties[0].Value; User=$_.Properties[1].Value} }
```

Cross-check with Security 4698 / 4702 (`Task created` / `Task updated`) — these capture the *full XML* in the event message, so even if the on-disk XML is deleted you can recover it.

**5. Common abuse patterns to recognise.**
- **`On Logon` trigger as `SYSTEM`** — runs at every boot before users log in; classic persistence.
- **`Event` trigger** — `<EventTrigger><Subscription>` watching `Application` 1000 (crash) or a custom EVTX event creates a hard-to-spot trigger; the task body contains the subscription XPath.
- **Empty `<Author>` + `<Date>` matching install time of a foreign binary** — anomaly.
- **Task pointing at non-standard path** — `C:\Windows\Temp\`, `C:\ProgramData\`, `C:\Users\Public\` — high suspicion.
- **`SDDLDescriptor` stripped** — attacker removed the security descriptor to keep the task but block enumeration; the task still fires.
- **GhostTask / GhostPack-style** — direct registry creation of `TaskCache\Tasks\{GUID}` without dropping an XML; defeats `schtasks /Query` entirely. Pure registry hunt + 4698 reconstruction catches it.

**6. Timelining.** XML file MAC times + registry last-write of `TaskCache\Tasks\{GUID}` should match. Disagreement points at one side being tampered after the fact. Add Security 4698 / TaskScheduler 106 to anchor "when the task actually was registered".

**7. Offline triage one-liner.**
```bash
# Velociraptor — collect across a fleet
velociraptor -- artifacts collect Windows.Forensics.ScheduledTasks --output tasks.json

# Standalone offline
python -c "import xml.etree.ElementTree as ET, os; [print(p, ET.parse(p).find('.//{*}Actions/{*}Exec/{*}Command').text) for p,d,f in os.walk('Tasks') for x in f for p in [os.path.join(p,x)]]"
```

## Detection and defence
- Audit subcategory **Other Object Access Events** (4698 / 4699 / 4700 / 4702) — these capture full task XML, surviving on-disk tampering.
- Monitor `HKLM\...\TaskCache\Tree` and `Tasks` for any new key (Sysmon 12/13/14 or a baseline-and-diff cron).
- Baseline the set of legitimate tasks at provisioning; alert on any deviation.
- Restrict who can `schtasks /Create /RU SYSTEM` via SeManageVolumePrivilege / SeImpersonatePrivilege chain audits.

## References
- [Microsoft — Task Scheduler XML schema](https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-schema) — official format
- [SpecterOps — GhostTask](https://posts.specterops.io/) — registry-only task technique
- [Eric Zimmerman — RegistryExplorer maps](https://ericzimmerman.github.io/) — Scheduled Tasks decoder
- [13Cubed — Scheduled task forensics](https://www.youtube.com/@13cubed) — short, practical
