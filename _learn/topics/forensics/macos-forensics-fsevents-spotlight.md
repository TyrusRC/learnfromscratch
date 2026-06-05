---
title: macOS forensics — FSEvents, Spotlight, file metadata
slug: macos-forensics-fsevents-spotlight
aliases: [macos-fsevents-forensics, spotlight-forensics, mds-forensics]
---

> **TL;DR:** macOS records file activity through three overlapping mechanisms: **FSEvents** (filesystem-event journal per volume, used by Time Machine), **Spotlight** (`mds` indexes content + metadata), and **extended attributes** (xattrs, including `com.apple.quarantine`). For IR, these are the closest equivalents to Windows USN journal / MFT / prefetch. Knowing what each records and how to parse gives a Mac-side timeline. Companion to [[macos-tcc-forensics]] and [[disk-image-forensics]].

## FSEvents

### What it is

A volume-level journal of "something changed here" events. Stored at `/.fseventsd/` on each mounted volume.

Records per-event:
- Inode number.
- Event type (created, modified, renamed, removed).
- Event ID (monotonic).
- Path (sometimes).

Used by Time Machine to know what changed since last backup.

### What's useful for IR

- Reconstruct file activity timeline.
- Survive after file deletion — event recorded even if file gone.
- Persists during sleep and across reboots.

### What's limited

- **Path may be coarse** — events record the *changed directory*, not the file (in some versions).
- **Event coalescing** — multiple events on the same path may collapse.
- **Time stamp granularity** is per "batch", not per event.
- **Retention** depends on Time Machine activity; can be hours to weeks.

### Parsing

- **FSEventsParser** (mac4n6) — popular open-source tool.
- **mac_apt** — comprehensive macOS forensic toolkit.
- **`fls`** (sleuthkit) — generic.

## Spotlight (`mds` / `mdworker`)

### What it is

`mds` runs as a daemon indexing file contents and metadata for search. Indexes:
- File name, path.
- MIME / kMDItem* attributes.
- Content (text from PDFs / docs / source files).
- Date created, modified, last opened.

Index stored under `/.Spotlight-V100/` on each volume.

### What's useful for IR

- **`mdls <file>`** — show metadata for a specific file. Includes:
  - `kMDItemDateAdded` — when added to indexer's view.
  - `kMDItemDownloadedDate` — for downloaded files.
  - `kMDItemWhereFroms` — referring URL for downloaded files (also a xattr).
  - `kMDItemContentCreationDate`.
- **`mdfind`** — query the index.

### Anti-forensic shape

- Files in `/private/`, `~/Library/` may be excluded from indexer.
- Apps can mark themselves as "not indexed".

## Extended attributes (xattrs)

### What they are

File-level metadata stored separately from content. Accessed via `xattr`, `ls -l@`, `mdls`.

Critical xattrs for IR:
- **`com.apple.quarantine`** — Gatekeeper quarantine flag. Records "downloaded from where" — extremely useful for tracking origin of malicious files.
- **`com.apple.metadata:kMDItemWhereFroms`** — URLs of origin.
- **`com.apple.macl`** — TCC accesses (see [[macos-tcc-forensics]]).
- **`com.apple.diskimages.fsck`** — for mounted DMGs.

### Reading

- `xattr -l <file>` — list xattrs.
- `mdls <file>` — show metadata.
- `xattr -p com.apple.quarantine <file>` — read one.

The quarantine xattr structure: `flags;timestamp;app-name;UUID`. Parses give "downloaded by Safari at 2024-01-15 with UUID X".

## Unified Logs (briefly)

macOS Unified Logs are the modern syslog replacement. Logged via `log` command:
- `log show --predicate ...`.
- `log collect` — for offline analysis.
- Persistent traces in `/var/db/diagnostics/`.

See [[macos-unified-logs-forensics]] for fuller treatment.

## Other artefacts worth knowing

- **`/var/db/quicklook/`** — Quick Look thumbnail cache. Contains thumbnails of previewed files; persistence even after deletion.
- **`~/Library/Preferences/com.apple.recentitems.plist`** — recent files (per app).
- **`~/Library/Application Support/com.apple.sharedfilelist/`** — recent items per app (newer format).
- **`/var/db/uuidtext/`** — Unified Log catalog.
- **`/var/log/install.log`** — package installation history.
- **`/var/log/wifi.log`** — Wi-Fi association history.
- **`/private/var/folders/`** — per-app temporary data.

## Investigation flow

For a suspected macOS compromise:

1. **Image the volume** (use Target Disk Mode if possible).
2. **Catalog xattrs on suspicious files** — quarantine, WhereFroms.
3. **Parse FSEvents** for timeline.
4. **Query Spotlight metadata** for the suspected file paths.
5. **Cross-check Quick Look cache** for files seen but deleted.
6. **Pull Unified Logs** for process / network / TCC events.
7. **TCC.db** for sandbox-permission grants ([[macos-tcc-forensics]]).
8. **`Persistence`** — LaunchAgents, LaunchDaemons, login items.

## Common attacker artefacts

- **LaunchAgent** at `~/Library/LaunchAgents/<malicious>.plist`.
- **LaunchDaemon** at `/Library/LaunchDaemons/<malicious>.plist`.
- **Login Item** at `~/Library/Application Support/com.apple.backgroundtaskmanagementagent`.
- **`/usr/local/bin/`** — common binary drop location.
- **`/private/tmp/`** — short-lived staging.
- **Browser extension** in browser-specific support folders.

## Tooling

- **mac_apt** (Yogesh Khatri) — most comprehensive open-source mac forensics.
- **FSEventsParser**.
- **MacForensicsLab Triage**.
- **GoogleChromiumOSXMacForensics** scripts.
- **`Crowdstrike Falcon Forensics`**, **`SentinelOne`** — commercial agents with mac coverage.

## Workflow to study

1. Boot a macOS test VM.
2. Download a benign file from a browser → check `com.apple.quarantine` xattr.
3. Create / modify files; check FSEvents recorded the changes.
4. Use `log show` to watch sandbox-permission events.
5. Practice with `mac_apt` on a clean macOS image.

## Related

- [[macos-tcc-forensics]] — TCC permission auditing.
- [[macos-unified-logs-forensics]] — log subsystem.
- [[ios-mobile-device-forensics]] — iOS analogue.
- [[macos-architecture]] — context.
- [[disk-image-forensics]] — generic disk-forensics.

## References
- [Yogesh Khatri — mac_apt](https://github.com/ydkhatri/mac_apt)
- [mac4n6.com](https://www.mac4n6.com/) — Sarah Edwards research
- [Apple — File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/)
- [Howard Oakley — eclectic light blog](https://eclecticlight.co/)
- See also: [[macos-tcc-forensics]], [[macos-unified-logs-forensics]], [[ios-mobile-device-forensics]], [[disk-image-forensics]], [[macos-architecture]]
