---
title: Clickjacking
slug: clickjacking
---

> **TL;DR:** Target framed transparently under an attacker UI so clicks register on the target.

## What it is
UI-redress attack: the target page is loaded inside an iframe on attacker.tld with `opacity:0` or covered by misleading attacker UI. The victim sees attacker content and clicks what looks like "Play video", but the click lands on a target-page button — "Delete account", "Authorise OAuth scope", "Transfer funds". Same-origin policy does not block the framing, only cross-origin reads.

## Preconditions / where it applies
- Target page does not send `X-Frame-Options: DENY` / `SAMEORIGIN`, and CSP has no `frame-ancestors`
- Target action requires only a single click / drag (no captcha, no re-auth)
- Victim authenticated to target while visiting attacker page

## Technique
1. Choose a one-click state-changing action on the target — typical examples: account delete, OAuth `Authorize`, "add admin", "approve payment".
2. Build attacker page that frames the target and overlays bait UI:
   ```html
   <style>
     iframe { width:1000px; height:600px; opacity:0.0001; position:absolute; top:0; left:0; }
     #bait  { position:absolute; top:240px; left:380px; }
   </style>
   <iframe src="https://target.tld/account/delete"></iframe>
   <button id="bait">Click to claim prize</button>
   ```
3. Position the iframe so the target's button aligns with the bait.
4. Variants:
   - **Cursorjacking** — fake cursor drawn via `cursor:none` + JS-tracked image; real cursor offset.
   - **Drag-and-drop jacking** — bait says "drag this code into the box"; victim drags attacker text into a target `contenteditable` to inject content.
   - **Likejacking / sharejacking** — classic Facebook-era variant.
   - **Double-clickjacking** (2024-2025) — first click closes a permission/auth prompt focus, second click lands on the now-focused OAuth approve button; bypasses many `X-Frame-Options` setups because the second window is a popup, not an iframe.
5. Chain with [[csrf]] / [[oauth-flows]] to upgrade a click into a token grant.

## Detection and defence
- Set `Content-Security-Policy: frame-ancestors 'none'` (or `'self'`) — modern, granular, supersedes `X-Frame-Options`.
- Also set `X-Frame-Options: DENY` for legacy browsers.
- Server-side require explicit confirmation (re-type password, captcha) before destructive actions — defeats one-click clickjack.
- Frame-busting JS is not sufficient (sandbox attribute defeats it); use headers.
- For double-clickjacking, require a user gesture inside the target window itself, or invalidate auth prompts on focus loss.
- Detect: hunt for pages with no `frame-ancestors`/`X-Frame-Options` that perform state changes; observe Referer-coming-from-attacker on sensitive endpoints.
- Related: [[content-security-policy-bypass]], [[csrf]], [[postmessage-bugs]].

## References
- [PortSwigger — clickjacking](https://portswigger.net/web-security/clickjacking) — labs and variants
- [OWASP — clickjacking defence cheat sheet](https://cheatsheetseries.owasp.org/cheatsheets/Clickjacking_Defense_Cheat_Sheet.html) — header guidance
- [Paulos Yibelo — double-clickjacking](https://www.paulosyibelo.com/2024/12/doubleclickjacking-what.html) — 2024 variant
