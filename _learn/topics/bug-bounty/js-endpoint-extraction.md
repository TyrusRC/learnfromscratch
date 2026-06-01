---
title: Endpoint extraction from JS
slug: js-endpoint-extraction
---

> **TL;DR:** Bundled frontend JS leaks API routes, role checks, debug flags, and sometimes raw secrets — pull every bundle, run extractors, diff between versions.

## What it is
Modern frontends ship minified-but-readable JS that contains every API endpoint the SPA can call, including ones the current user role is not allowed to see. Hidden admin routes, debug endpoints, feature-flagged URLs, even AWS keys and Slack webhooks slip into bundles. Extracting them — and diffing them as the bundle changes — is one of the highest-yield recon techniques on any JS-heavy target.

## Preconditions / where it applies
- The application is a SPA (React, Vue, Angular, Svelte, Next.js) — bundle URLs visible in the HTML
- An authenticated session at any role; admin bundles are sometimes only shipped to admin sessions, but most apps ship a single bundle to everyone
- Useful immediately after [[endpoint-spidering]] and before fuzzing

## Technique
1. Collect every JS URL the app loads. Combine the spider output ([[endpoint-spidering]]) with passive sources (`gau`, `waybackurls`) and the running app's network panel:
   ```
   katana -u https://app.target.tld -jc -silent | grep -E '\.js(\?|$)' | sort -u > js.txt
   ```
2. Mirror locally and beautify before grepping — minified one-liners hide patterns:
   ```
   while read u; do wget -q "$u" -O "$(echo $u | sha1sum | cut -c1-12).js"; done < js.txt
   js-beautify -r *.js
   ```
3. Run extractors. They overlap in coverage; using two is usually enough:
   - `linkfinder.py -i 'app.*.js' -o cli` — original regex-based URL extractor
   - `xnLinkFinder -i js/ -sf target.tld -o links.txt` — newer, smarter, scope-aware
   - `jsluice urls --include-source app.js` — Go-based, also extracts secrets
   - `trufflehog filesystem js/` — credentials, tokens
4. Sort, dedupe, scope-filter, then feed back into nuclei, ffuf, or manual triage. Pay special attention to:
   - `*/internal/*`, `*/admin/*`, `*/debug/*`, `*/v1beta/*` paths
   - Feature flag names — sometimes the flag itself is the bug (`isInternalUser`, `bypassMfa`)
   - Role strings (`"role":"ADMIN"`) hinting at mass-assignment opportunities
5. Hash each bundle and store. On every recon loop ([[continuous-recon-automation]]) diff against the previous hash; a changed bundle means re-extract — new routes ship in the diff.

## Detection and defence
- Defenders should split admin and tenant bundles, strip dead code in the build, and never embed credentials in frontend code
- Source-map suppression in production is a partial mitigation; aggressive minification slows extractors but does not stop them
- For the hunter: hitting newly-extracted admin endpoints triggers WAF 403/401 patterns the defender can correlate — pace yourself

## References
- [GerbenJavado/LinkFinder](https://github.com/GerbenJavado/LinkFinder) — original JS link extractor
- [xnl-h4ck3r/xnLinkFinder](https://github.com/xnl-h4ck3r/xnLinkFinder) — scope-aware modern successor
- [BishopFox/jsluice](https://github.com/BishopFox/jsluice) — Go-based URL + secret extractor with AST
