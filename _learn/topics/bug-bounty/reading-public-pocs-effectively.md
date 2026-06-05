---
title: Reading public PoCs effectively
slug: reading-public-pocs-effectively
aliases: [reading-pocs, public-poc-method]
---

> **TL;DR:** A public PoC (GitHub gist, Nuclei template, Metasploit module, security-vendor blog) is a *finished* exploit. To learn from it you have to back-derive the *unfinished* exploit — the trigger, the primitive, the variant the author left out. Method: read the patch first, the advisory second, the PoC last; then write the PoC from memory; then mutate it. Companion to [[n-day-rapid-exploitation]] and [[one-day-from-patch-diff]].

## The four sources you'll mine

1. **GitHub PoC repos** — `nuclei-templates`, `cve-{year}` repos, individual hunter repos. Often one-shot scripts.
2. **Metasploit modules** — `metasploit-framework/modules/exploits/`. Production-quality with options, target list, check function.
3. **Vendor / researcher blogs** — Project Discovery, watchTowr, AssetNote, ZDI, Project Zero. Long-form root cause.
4. **Twitter/Bsky threads** — early signal, often just a screenshot of the bug. Follow the thread for the PoC.

Each is a different reading exercise.

## Read the patch first, not the PoC

If a CVE has a patch (most do), read the patch *before* the PoC. The patch is a 5-line diff that tells you the root cause; the PoC is 200 lines of HTTP requests obscuring it. Order:

1. Open the vendor's commit that fixes the CVE (often linked from NVD or GitHub Security Advisory).
2. Read the diff. Ask: *what condition was the patch enforcing?* The exploit is the inverse of that condition.
3. *Now* open the PoC. You should already know which request it has to send and which response field it has to parse.

If the patch is closed-source (Cisco, Fortinet, Ivanti), substitute with binary diffing — see [[patched-binary-diffing-for-vulnid]] and [[one-day-from-patch-diff]].

## Read the advisory second

The advisory tells you:
- Affected versions — which determines target selection.
- Pre-conditions — auth required? specific feature enabled? cluster mode?
- Pre-auth vs post-auth — gates the impact.
- CVSS vector — gives an indicator but trust the patch over the score.

These never appear in the PoC; the PoC assumes you already know.

## Read the PoC last, and *backwards*

Open the PoC. Find the final request that triggers the bug. Work backwards:

- What pre-conditions does that request need?
- Which earlier requests set up state for it?
- Why this exact endpoint and not another?
- Why this header / parameter / encoding?

Often the PoC contains *vestigial* steps the author kept from their own discovery. They aren't strictly required. Strip the PoC to its minimum trigger and re-test. That minimum is the real bug.

## Write it from memory

Close the PoC. Reproduce it in your terminal from memory using only the patch and advisory. Diff your version against the original. Where you guessed wrong is where your model of the bug is shallow — go back and fix the model, not just the script.

## Mutate it

Once you have a minimal working trigger:

- Vary the **transport** — change HTTP/1.1 to HTTP/2 or HTTP/3 ([[http3-quic-attack-surface]]). Some WAFs only inspect /1.1.
- Vary the **encoding** — URL-encode, double-encode, percent-Unicode, body-as-JSON-instead-of-form.
- Vary the **endpoint** — search the codebase for sibling endpoints calling the same vulnerable function.
- Vary the **auth state** — does it work pre-auth? as a low-priv user? cross-tenant?
- Vary the **target version** — many advisories under-claim the affected range.

Each mutation is a candidate *new* CVE or a variant the vendor's patch missed. Variant hunting is where bounty-hunters out-earn one-shot exploiters.

## Reading Nuclei templates

Nuclei templates are HTTP fingerprints, not exploits. The `matchers` block tells you the **signal of success**, often the most useful part:

```yaml
matchers:
  - type: word
    words:
      - "RCE successful"
      - "uid=0"
```

Reverse-engineer what the request did to produce that string. Often there's a single line in the `requests` block that's the payload — copy it, send it manually with `curl -v`, and confirm.

Templates are also a great corpus of **fingerprint patterns**: how to detect a specific product, version, or misconfig. Worth reading by class even when you don't have a target.

## Reading Metasploit modules

Three useful sections of any module:

- **`check`** — the version detection logic. This is the bug fingerprint distilled.
- **`exploit`** — the request sequence.
- **`evade`** options — how the author hides from common detections. Read these to understand defender visibility.

Modules in the `auxiliary/scanner/` tree are pure fingerprinters — gold for understanding "how do I tell at scale if a target is vulnerable" without actually exploiting.

## Reading vendor research blogs

watchTowr, AssetNote, ProjectDiscovery, Synacktiv, Horizon3, ZDI publish *root cause* posts. The structure is usually:

1. Why the product is interesting.
2. The bug class (auth bypass / path traversal / deserialisation / …).
3. The primitive obtained (read / write / RCE / DoS).
4. The chain to impact.
5. The patch and its quality.

Read these end-to-end. They show **how a researcher decided where to look** — which is the skill the PoC alone won't teach you.

## Where the PoC will mislead you

- **Hard-coded paths** ("`/api/v3/admin/users`") that work on one minor version — the real endpoint moved.
- **Sample shellcode / command** that's actually filtered on the target by an in-line WAF — swap for a different sink.
- **Missing pre-condition** — the PoC needs a session cookie the author forgot to mention. Read your raw request, not the script.
- **Single-target tunnel vision** — the author tested on default install; production deployments differ.

## Building your own PoC library

Keep your stripped-minimum versions in a private repo organised by year and class. After a year you have:

- A baseline for n-day weaponisation speed.
- A teaching corpus when you onboard juniors.
- A fingerprint library for recon ("does this org expose any product I've already weaponised?").

See also: [[github-recon]], [[continuous-recon-automation]].

## Tools
- **`gh search code`** — find PoCs by CVE quickly across GitHub.
- **`nuclei -t cves/`** — run the curated template set.
- **`metasploit-framework/lib/msf/core/check_code.rb`** — read this once; understanding check codes makes scanner output legible.
- **`vulndb`, `inthewild.io`, `cisa.gov/kev`** — find which CVEs are actually exploited.

## References
- [CISA Known Exploited Vulnerabilities catalog](https://www.cisa.gov/known-exploited-vulnerabilities-catalog)
- [Nuclei templates](https://github.com/projectdiscovery/nuclei-templates)
- [watchTowr Labs](https://labs.watchtowr.com/)
- [AssetNote Research](https://www.assetnote.io/resources/research)
- [ProjectDiscovery blog](https://blog.projectdiscovery.io/)
- See also: [[n-day-rapid-exploitation]], [[one-day-from-patch-diff]], [[porting-public-exploits]], [[known-vuln-workflow]]
