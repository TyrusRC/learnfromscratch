---
title: Browser history forensics
slug: browser-history-forensics
---

> **TL;DR:** Chrome/Edge/Brave/Opera all sit on the Chromium SQLite schema (`History`, `Cookies`, `Login Data`, `Web Data`, `Top Sites`), Firefox uses `places.sqlite` + `formhistory.sqlite`, and Safari uses `History.db` + `Downloads.plist` — between them you reconstruct every visited URL, downloaded file, search query, autofilled value, and (with the OS-bound decryption key) every saved password.

## What it is
Modern browsers maintain rich local databases of user activity. From a DFIR perspective each browser is a fixed set of well-documented SQLite (or plist) files. Knowing where they live and which table maps to which user behaviour turns "what did this user do online" into a series of `sqlite3` queries.

## Preconditions / where it applies
- DFIR triage of a Windows / macOS / Linux endpoint, live or imaged.
- User-attribution investigations, phishing-click reconstruction, exfil-staging triage, insider-threat work.

## Technique
**1. Chromium-family locations.**

| OS | Path |
|---|---|
| Windows | `C:\Users\<u>\AppData\Local\Google\Chrome\User Data\Default\` |
| macOS | `~/Library/Application Support/Google/Chrome/Default/` |
| Linux | `~/.config/google-chrome/Default/` |

Replace `Google\Chrome` with `Microsoft\Edge`, `BraveSoftware\Brave-Browser`, `Opera Software\Opera Stable` etc. for the cousins. Profiles other than `Default` are `Profile 1`, `Profile 2`...

Key files in each profile:

| File | Schema highlights |
|---|---|
| `History` | `urls` (id, url, title, visit_count, last_visit_time), `visits` (id, url, visit_time, transition, from_visit), `downloads` (target_path, referrer, start_time, total_bytes), `keyword_search_terms` |
| `Cookies` | `cookies` (host_key, name, value, path, expires_utc, encrypted_value) |
| `Login Data` | `logins` (origin_url, username_value, password_value (encrypted)) |
| `Web Data` | `autofill`, `credit_cards` (encrypted), `addresses` |
| `Top Sites` | thumbnails — useful for visual confirmation |
| `Network/Cookies` | newer Chrome moved cookies here |
| `Sessions/` | last-N tabs (TabRestore + Session files) |

**2. Decode timestamps.** Chromium uses **Webkit/Chrome time**: microseconds since 1601-01-01 UTC.
```sql
SELECT url, title, datetime((last_visit_time/1000000)-11644473600, 'unixepoch') AS visited
FROM urls ORDER BY last_visit_time DESC LIMIT 50;
```

**3. Decrypt cookies / passwords.**
- **Windows (Chrome ≤ 79):** values DPAPI-protected at user level. `CryptUnprotectData` from the user context decrypts directly.
- **Windows (Chrome ≥ 80):** AES-GCM. Key stored encrypted under DPAPI in `Local State` (`os_crypt.encrypted_key`, base64 + `DPAPI` prefix). Decrypt the key with DPAPI, then AES-GCM-decrypt each `v10`-prefixed `encrypted_value`.
- **Windows (Chrome ≥ 127, "App-Bound Encryption"):** Chrome added an extra wrapper that requires running as the Chrome process or using the COM `IElevator` interface — tooling like `xaitax/Chrome-App-Bound-Encryption-Decryption` automates the pivot.
- **macOS:** AES-128-CBC with key from Keychain entry `Chrome Safe Storage` / `Edge Safe Storage` (`security find-generic-password -wa "Chrome"`); 1003 iterations PBKDF2 with salt `saltysalt`.
- **Linux:** `kwallet` or `gnome-keyring`-stored key with the same `Chrome Safe Storage` label, or a static `peanuts` fallback for headless installs.

```python
# Chrome v10 on Windows, given DPAPI-decrypted key
from Crypto.Cipher import AES
nonce, ct = enc[3:15], enc[15:-16]; tag = enc[-16:]
plaintext = AES.new(key, AES.MODE_GCM, nonce=nonce).decrypt_and_verify(ct, tag)
```

Off-the-shelf: **HackBrowserData**, **DonPAPI**, **SharpChromium**, **NirSoft ChromePass / ChromeHistoryView**.

**4. Firefox.**
- Profile root: `%APPDATA%\Mozilla\Firefox\Profiles\<random>.default-release\` (Windows), `~/.mozilla/firefox/<>.default-release/` (Linux), `~/Library/Application Support/Firefox/Profiles/<>/` (macOS).
- `places.sqlite` — `moz_places` + `moz_historyvisits`. Timestamps are **microseconds since epoch** (different from Chrome).
```sql
SELECT url, title, datetime(last_visit_date/1000000, 'unixepoch') FROM moz_places ORDER BY last_visit_date DESC;
```
- `formhistory.sqlite` — every form field the user typed.
- `cookies.sqlite` — cookies (not encrypted at rest, just file-permission-protected).
- `logins.json` + `key4.db` — passwords. Decryption key is wrapped by the master password (default empty); use **firefox_decrypt** to extract.
- `downloads.sqlite` (older) / `places.sqlite` `moz_annos` (newer) for downloads.

**5. Safari (macOS).**
- `~/Library/Safari/History.db` — `history_items` + `history_visits`. Timestamps are **CFAbsoluteTime** (seconds since 2001-01-01 UTC).
```sql
SELECT i.url, datetime(v.visit_time + 978307200, 'unixepoch')
FROM history_items i JOIN history_visits v ON i.id = v.history_item ORDER BY v.visit_time DESC;
```
- `~/Library/Safari/Downloads.plist` — completed + in-progress downloads.
- `~/Library/Cookies/Cookies.binarycookies` — binary plist; parse with `BinaryCookieReader.py`.
- `~/Library/Containers/com.apple.Safari/Data/Library/Safari/...` (sandboxed Safari) since macOS 14 — same files, different root.

**6. Cache, downloads, and "session" artefacts.**
- Chromium `Cache/data_*` — disk cache; recover downloaded resources with `ChromeCacheView` or `chrome-cache-recovery`.
- `Downloads/` filesystem folder + browser DB cross-correlation (browser knows referrer + tab URL → links a saved file to the tab that downloaded it).
- `Session Storage`, `Local Storage`, `IndexedDB` directories under each profile — useful for SPA-state forensics (chat apps, banking sessions).

**7. Common investigation questions.**
- **Phishing-click reconstruction:** find the URL in `urls`, follow `from_visit` recursively to recover the click chain.
- **Exfil staging:** join `downloads` with `urls` to see "from where was each file downloaded"; cross-reference with `Cache` to recover the file body even after delete.
- **Credential reuse:** decrypt `Login Data`, hash passwords, compare to known-breach corpora.
- **Insider — what did they search for last week?** `keyword_search_terms` joined with `urls` gives raw search queries + the engine used.

**8. Anti-forensics signs.**
- `History` file present but empty (size > 0, rows = 0) → likely cleared via Settings UI. The `Session Storage` and `Cache` directories often still have residual state.
- `Login Data` missing entirely → user wiped saved passwords, or browser was opened in Incognito-only mode.
- File ATime/MTime suggests the file was open *after* the suspected activity window → recent edit, possibly via `sqlite3 ... DELETE`.

## Detection and defence
- Enterprise: deploy browser-extension-based logging (Chrome Browser Cloud Management, Edge Management) for tamper-proof history.
- DLP suites read these files in real time — a sudden burst of downloads or many distinct hosts in `urls` triggers exfil alerts.
- For the offensive side, browsers leak heavily — assume any browsing on a compromised host is recoverable post-incident.

## References
- [SANS — Browser Forensics Guide](https://www.sans.org/posters/browser-forensics-poster/)
- [Hindsight — Chrome history parser](https://github.com/obsidianforensics/hindsight) — multi-profile, multi-version
- [HackBrowserData](https://github.com/moonD4rk/HackBrowserData) — credential / history exfil
- [Foxton — BrowsingHistoryView](https://www.nirsoft.net/utils/browsing_history_view.html) — quick unified view
