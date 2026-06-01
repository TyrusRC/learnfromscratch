---
title: JS recon
slug: js-recon
---

> **TL;DR:** Modern apps ship most of their attack surface inside JavaScript bundles — endpoint paths, parameter names, feature flags, embedded keys, and (if devs slip up) source maps that reverse the whole codebase. Mine it.

## What it is
Every SPA exposes its own backend API contract in the browser. The bundle is a treasure map: which routes the app calls, what parameters it sends, what role-gated buttons exist, what cloud SDK keys got baked in. Reading bundles is a higher signal-to-noise activity than blind fuzzing, and feeds [[content-discovery]] and [[expanding-attack-surface]].

## Preconditions / where it applies
- A target is a SPA / heavy JS app (React, Vue, Angular, Svelte, etc.) — not a server-rendered legacy site
- You can fetch the JS files unauthenticated, or you have a low-priv account to capture them
- The bundle is at least somewhat readable (un-obfuscated, or source map present)

## Technique
1. Enumerate all JS assets the app loads. Burp's site map + a crawl gives you a list; or pull from the HTML:

```
# get all .js URLs referenced from a page
curl -s https://target.tld | grep -Eo 'src="[^"]+\.js[^"]*"' | sort -u
```

Tools: `subjs`, `getJS`, `gau`, `waybackurls` — many will surface old bundle URLs from archives.
2. Hunt for source maps. `app.js.map` next to `app.js` reverses the whole codebase to original source — variable names, comments, file paths. Even partial maps help:

```
curl -sI https://target.tld/static/js/main.abcd.js.map
```

3. Endpoint extraction from minified bundles. See [[js-endpoint-extraction]] for the dedicated workflow — `linkfinder`, `jsluice`, custom regex for `/api/`, `fetch(`, `axios.get(`.
4. Secret hunting in the bundle:

```
# obvious patterns
grep -EoR 'AKIA[0-9A-Z]{16}|ghp_[a-zA-Z0-9]{36}|sk_live_[a-zA-Z0-9]{24,}' bundle.js
```

Tools: `trufflehog`, `secretlint`, `Mantra`. Validate every hit before reporting — many are Stripe `pk_` publishable keys (intended public) or third-party SDK init keys (not always a bug).
5. Feature-flag and role mining. Search for strings like `isAdmin`, `hasFeature(`, `role ===`, `betaFlags`. Each is a candidate for forced enablement — flip the flag in devtools and see if the UI reveals hidden surface, then call the endpoint directly.
6. Build-tool fingerprints. `webpackChunk`, `__NEXT_DATA__`, Angular hashes, source-map `webpack:///./src/...` paths leak the internal repo structure — file names hint at routes that may exist server-side.

## Detection and defence
- Strip source maps from production bundles; serve them only to authenticated dev environments
- Treat browser-shipped code as public — never embed server credentials, even "low-privilege" ones; rotate any leaked secret immediately
- Use environment-aware feature flag systems where the server doesn't return UI for features the user can't use, instead of relying on client-side flag checks
- Heavy crawling of `.js`, `.js.map`, `/static/` paths is a signal — alert on 404 storms in those locations

## References
- [PortSwigger — JavaScript analysis](https://portswigger.net/web-security/cross-site-scripting/dom-based) — DOM and JS-driven attack surface
- [LinkFinder](https://github.com/GerbenJavado/LinkFinder) — endpoint regex extractor
- [jsluice](https://github.com/BishopFox/jsluice) — modern bundle analyser
- [HackTricks — JS files for recon](https://book.hacktricks.wiki/en/network-services-pentesting/pentesting-web/index.html) — workflow refs
