---
title: Cross-site leaks
slug: xs-leaks
---

> **TL;DR:** Observe coarse side-channel signals (timing, error events, framecount, scrollbar size, COEP/COOP errors) about a victim's cross-origin response to infer one authenticated bit at a time — login state, search hits, message counts, role.

## What it is
The same-origin policy stops attackers from reading cross-origin response bodies, but the browser still emits side-effects an attacker page can observe: load/error events on `<img>` / `<script>`, timing of `iframe.onload`, the number of frames in a window, layout-driven scrollbar appearance, `postMessage` echoes, COOP/COEP error pages, cache-timing, and storage quota. XS-Leaks weaponise these differences into ≥1 bit per request: "does the victim see this search result?" "is the victim logged in as admin?" "is this email in the inbox?".

## Preconditions / where it applies
- Attacker can lure the victim's authenticated browser to an attacker-controlled page (drive-by, malvertising, link in IM).
- The cross-origin response differs in some observable way depending on the victim's state (status code, size, frame count, redirect target, error class).
- Browser permits the differential signal — many classic leaks are mitigated by `Cross-Origin-Opener-Policy`, `Cross-Origin-Resource-Policy`, `SameSite=Lax/Strict` cookies, and Fetch Metadata headers.

## Technique

**Error-event leak.** A cross-origin resource returns 200 vs 4xx; `<script src>` and `<img src>` fire `onload` vs `onerror`. Useful when an endpoint returns 200 only if a search hit:

```html
<img src="https://target.com/inbox?q=secret" onload="hit()" onerror="miss()">
```

If the response is HTML (not an image), `onerror` fires for both — but timing differs, and `<object>` / `<embed>` can distinguish.

**Framecount.** `window.length` of an opened cross-origin window equals the number of `<iframe>` children. If the search-results page renders one `<iframe>` per hit, count = answer.

**Timing.** Use `performance.now()` between `window.open` and a `postMessage` echo, or measure long-tasks. The `connection-info` / `resourceTiming` API exposes precise sub-resource timing for same-origin requests; combine with cache attacks.

**Cache probing.** Pre-fill or check the HTTP cache: request a URL that only loads when state=true, measure round-trip — cache hit = ~5ms, miss = network.

**postMessage leaks.** Many sites broadcast inner state to `*` on load — embed and listen.

**ID-attribute leak via Cross-Origin redirects.** `<iframe src="https://target.com/profile/123">` — read `iframe.contentWindow.location.href` is blocked, but COOP / `window.length` and redirect-count via `history.length` differential leak whether the user owns the profile.

**COOP / COEP error pages.** Opening a window that triggers COOP isolation gives a different `window` reference / origin, observable.

**`:visited` style leak.** Mostly mitigated; subtle paint-timing variants exist (CSS3 `:visited` + `getComputedStyle` blocked, but mix-blend-mode + SVG filters have produced new leaks).

**Cross-origin pixel-stealing via CSS filters / SVG mesh** — historical (CVE-2013-2925) but periodically resurfaces.

**`storage.estimate()`** — origin quota difference between visited vs not.

**Web-bundle / prefetch differential** — recent (2023-2024) primitives via speculation rules.

## Detection and defence
- Set `Cross-Origin-Opener-Policy: same-origin` to deny `window.length` / opener access to cross-origin attackers.
- `Cross-Origin-Resource-Policy: same-origin` (or `same-site`) blocks `<img>`/`<script>` embedding of sensitive endpoints.
- `Cross-Origin-Embedder-Policy: require-corp` + COOP enables `crossOriginIsolated` and disables many timing primitives.
- `SameSite=Lax` (default) / `Strict` cookies strip credentials from most cross-site loads — most XS-Leaks rely on the victim's cookies riding along.
- `Sec-Fetch-Site`, `Sec-Fetch-Mode`, `Sec-Fetch-Dest` request headers — server rejects cross-site requests to sensitive endpoints (`Sec-Fetch-Site != same-origin`).
- Cache-Control: `no-store` on user-specific responses to defeat cache probes.

See also [[cors-misconfig]], [[clickjacking]], [[postmessage-bugs]].

## References
- [XS-Leaks Wiki](https://xsleaks.dev/) — canonical catalogue
- [Google – Fetch Metadata Request Headers](https://web.dev/articles/fetch-metadata) — Sec-Fetch-* defence
- [OWASP – Cross-Origin Resource Policy](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html) — adjacent isolation headers
