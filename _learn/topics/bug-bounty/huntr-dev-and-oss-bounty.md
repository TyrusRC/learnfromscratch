---
title: huntr.dev and open-source bug bounty
slug: huntr-dev-and-oss-bounty
aliases: [huntr-platform, oss-bb]
---

> **TL;DR:** huntr.dev (now operated by Protect AI) is the dominant bounty platform for open-source packages on npm/PyPI/Maven/RubyGems/Go and increasingly AI/ML repos (PyTorch, MLflow, Gradio, Hugging Face). Bounties scale with package popularity (downloads, dependents) and severity; huntr automatically files CVEs through its CNA, coordinates with maintainers, and discloses publicly after fixes ship. Pair this with the Internet Bug Bounty (IBB) on HackerOne for foundational OSS (Linux, OpenSSL, Apache, curl, Django) and GitHub Security Lab's CodeQL bounty for source-driven research. This note is the open-source counterpart to [[hackerone-platform-deep]] and a companion to [[npm-postinstall-and-typosquat-audit]], [[python-pypi-supply-chain-audit]], and [[go-module-substitution-audit]].

## Why it matters

Traditional bug bounty rewards finding flaws in a single company's perimeter. OSS bounty rewards finding flaws in the building blocks every company uses. A single prototype-pollution gadget in a popular npm helper, an SSRF in a Python HTTP wrapper, or a deserialization sink in an MLOps library can translate into thousands of downstream advisories. Until huntr launched, this work paid in CVE clout only; now there is real money and a CNA workflow attached.

Three structural reasons OSS bounty is good practice for the hunter:

- **Cheap targets.** No NDA, no scope wrangling, no rate-limit anxiety. You clone the repo and run it on localhost.
- **Source available.** Every finding is a source-review finding, which sharpens the skill that pays best in private programs (see [[graphql-source-review]], [[android-source-review-methodology]], [[ios-source-review-methodology]]).
- **CVE portfolio.** Public CVEs with your name are durable career artifacts independent of any one platform.

The flip side: payouts are smaller than corporate VDP (often \$50-\$4,000), duplicate risk is high on popular packages, and bad behavior toward unpaid maintainers will end your reputation fast. See [[disclosure-and-comms]] and [[responsible-disclosure-across-jurisdictions]].

## Platform landscape

### huntr.dev (Protect AI)

- **Scope.** npm, PyPI, Maven Central, RubyGems, Go modules, Packagist, NuGet, plus a growing AI/ML repo list (PyTorch, TensorFlow, MLflow, BentoML, Gradio, LangChain, LlamaIndex, Hugging Face Transformers, vLLM, Triton, ComfyUI nodes).
- **Eligibility.** Package must meet a popularity threshold (typically tens of thousands of downloads/month for registries; specific repo allowlist for AI/ML). Check the bounty page before spending hours on a low-download library.
- **Payout model.** Severity (CVSS) multiplied by popularity tier. Critical RCE on a top-tier package commonly pays \$1,500-\$4,000; mediums pay \$50-\$500. AI/ML "Model Vulns" track has separate, often higher payouts (PyTorch RCEs have paid \$2k-\$5k).
- **CVE workflow.** huntr is a CNA. When a report is validated, huntr assigns a CVE, coordinates with the maintainer, and publishes the advisory after the fix lands (or after a timeout, typically 90 days).
- **Reporter rights.** You retain credit and can blog after public disclosure; coordinate timing with the huntr triager.

### Internet Bug Bounty (IBB) on HackerOne

- Sponsored by Meta, GitHub, Shopify, Microsoft, and others; covers foundational OSS the internet depends on: Linux kernel, OpenSSL, Apache httpd, nginx, curl, Django, Ruby, PHP, Perl, systemd, BIND, Bitcoin Core, Electron, Symfony, OpenSSH, and more.
- Payouts skew higher than huntr because the impact radius is the entire internet. Linux kernel local-priv-esc or OpenSSL memory bugs can pay \$5k-\$20k+.
- Same H1 mechanics as [[hackerone-platform-deep]] — reputation, signal, retests — but maintainers are the triagers and are unpaid volunteers. Behave accordingly.

### GitHub Security Lab

- Pays researchers for vulnerabilities found with CodeQL queries against the GitHub-maintained OSS list, plus bonus for a reusable CodeQL query that finds the bug class at scale.
- Excellent on-ramp to learn variant analysis: write a query, run it across GitHub's CodeQL database fleet, file each hit. See [[automation-and-rinse-repeat]] and [[continuous-recon-automation]] for the broader pattern.

### Google OSS VRP / Patch Rewards

- Rewards vulns and patches in Google-supported OSS projects (Go, Angular, Bazel, Fuchsia components) and the open-source projects Google depends on.
- Higher signal bar; reports must clearly demonstrate exploitability (see [[demonstrating-impact]]).

### Vendor-specific OSS bounties

Some companies pay separately for their own OSS: GitLab (HackerOne), Sonatype, Snyk's research program, JFrog's vuln catalog credits, MongoDB drivers, Elastic, HashiCorp. Worth keeping a list — these often have less competition.

## Bug classes that recur in OSS bounty

### npm and JavaScript

- **Prototype pollution** in merge/clone helpers and config loaders. Still finds RCE/auth-bypass gadgets in downstream apps. Pair with [[npm-postinstall-and-typosquat-audit]].
- **Command injection** in CLI tools and build helpers that shell out with template strings.
- **Path traversal / arbitrary file write** in archive extractors (tar/zip "Zip Slip" variants).
- **Regex DoS (ReDoS)** in input validators — pays low but is bulk-findable with a fuzzer.
- **SSRF** in URL fetchers that don't validate scheme/host.

### PyPI and Python

- **Pickle / YAML / Marshal deserialization** in ML libs, RPC libs, caching libs.
- **Jinja2 / template SSTI** in libraries that render user input.
- **Subprocess shell=True** with template strings — classic command injection.
- **Path traversal** in archive utilities and static-file servers.
- See [[python-pypi-supply-chain-audit]] for the install-time variant.

### Maven / Java

- **XML External Entity (XXE)** in parsers and SOAP libs with default factories.
- **Java deserialization** sinks via ObjectInputStream, fastjson, Jackson polymorphic typing.
- **SSRF** in URL/URLConnection wrappers.
- **Log4Shell-style lookups** in logging libraries that interpret format strings.

### Go modules

- **Path traversal** in archive/tar and archive/zip wrappers.
- **HTTP client SSRF** without scheme allowlists.
- **Race conditions** in cache and rate-limit middlewares.
- **Module substitution / typosquatting**, see [[go-module-substitution-audit]].

### AI/ML repos (huntr's growth area)

- **Pickle / safetensors-bypass** model loading RCE in PyTorch, Transformers, vLLM.
- **MLflow / BentoML** path traversal and auth bypass on tracking/serving endpoints.
- **Gradio / Streamlit** file-read and SSRF via component upload/preview features.
- **LangChain / LlamaIndex** tool-use sinks: SQL injection via natural-language SQL agents, SSRF via document loaders, RCE via PythonREPLTool. Cross with [[indirect-prompt-injection]] and [[agentic-credential-exfiltration-via-tool-use]].

## Workflow to study

A repeatable OSS-bounty pipeline:

1. **Pick a registry track.** Don't fan out across all five at once. Start with npm or PyPI — largest huntr scope, most bugs.
2. **Build a popularity-sorted target list.** Use npms.io or libraries.io to pull top-N by downloads or by reverse dependencies. Cross-reference with the huntr scope page so you only audit eligible packages. See [[target-selection-heuristics]].
3. **Triage candidates fast.** Open the repo, look at last commit date (alive?), look at issue tracker (already-reported smells), grep for known sinks. Five-minute rule: if nothing interesting, move on. See [[getting-feel-for-target]].
4. **Pick a sink class per session.** Don't read the whole codebase — search for one pattern (e.g., `child_process.exec`, `pickle.loads`, `new URL(`) across many packages. Bulk-grep then bulk-triage.
5. **Reproduce locally.** Write the smallest possible PoC: a Node/Python script that imports the library and triggers the sink. Save it as `poc.js` / `poc.py` for the report.
6. **Check duplicates.** Search huntr (existing reports), GitHub Security Advisories, NVD, Snyk DB, OSV.dev. Look at the changelog for silently patched fixes. See [[dupe-mental-model]].
7. **File on huntr.** Use their template; include affected versions, fixed-version recommendation (often a one-liner patch), CVSS, PoC, and impact narrative. Be polite — maintainers read these.
8. **Coordinate disclosure.** Default 90 days. If maintainer is responsive, push a PR yourself. If unresponsive, huntr escalates. Do not 0-day for clout. See [[disclosure-and-comms]].
9. **Variant-hunt the fix.** When the patch lands, diff it and search every other package using the same idiom. This is [[one-day-from-patch-diff]] applied to OSS.
10. **Publish (after fix).** Personal blog or huntr's writeup section; reinforces your portfolio. See [[report-writing-step-by-step]].

## Tooling baseline

- **Semgrep** with custom rules per sink class — fastest way to bulk-grep modern syntax.
- **CodeQL** for variant analysis once you can write queries; pairs with GitHub Security Lab bounty.
- **OSV-Scanner** and **Snyk DB** for dedupe checks.
- **socket.dev / Phylum / Sonatype OSS Index** for popularity, dependents, and prior CVEs.
- **deps.dev** (Google) for cross-registry dependency graphs.
- **n0kovo's package-name lists**, **npms.io**, **libraries.io** APIs for target enumeration.
- A local sandbox VM/container so you can `npm install` / `pip install` untrusted code safely — never on your dev host. See [[building-a-research-home-lab]].

## Ethical baseline

- **Never demand payment from unpaid maintainers.** huntr is the payer; the maintainer is a volunteer.
- **Always give a fix suggestion or PR.** Maintainers remember helpful reporters.
- **Respect embargo.** Don't tweet the CVE before the advisory publishes.
- **Don't mass-file low-quality ReDoS / "this regex is slow" reports** on unmaintained libraries — it burns maintainer goodwill and gets you flagged on huntr.
- **No supply-chain "research" PoCs** that publish real malicious packages to live registries. Use private registries or local mirrors. See [[responsible-disclosure-across-jurisdictions]].

## Defensive baseline (for maintainers reading this)

- Enable **GitHub Security Advisories** and the **private vulnerability reporting** toggle so researchers have a clear channel.
- Add a `SECURITY.md` with the huntr link and your preferred disclosure method.
- Use **CodeQL default setup** plus **Dependabot security updates** to catch the easy 80%.
- Tag releases and maintain a changelog so reporters can identify affected versions cleanly.
- Pin transitive deps for build/CI, and run npm/pip audit in CI.

## Related

- [[hackerone-platform-deep]]
- [[npm-postinstall-and-typosquat-audit]]
- [[python-pypi-supply-chain-audit]]
- [[go-module-substitution-audit]]
- [[one-day-from-patch-diff]]
- [[known-vuln-workflow]]
- [[automation-and-rinse-repeat]]
- [[target-selection-heuristics]]
- [[dupe-mental-model]]
- [[disclosure-and-comms]]
- [[report-writing-step-by-step]]
- [[building-a-research-home-lab]]
- [[llm-application-source-review]]

## References

- huntr.dev bounty platform and scope: https://huntr.com/
- Internet Bug Bounty on HackerOne: https://hackerone.com/ibb
- GitHub Security Lab researcher program: https://securitylab.github.com/bounties/
- Google OSS VRP: https://bughunters.google.com/about/rules/open-source
- OSV.dev open-source vulnerability database: https://osv.dev/
- GitHub Security Advisories docs: https://docs.github.com/en/code-security/security-advisories
