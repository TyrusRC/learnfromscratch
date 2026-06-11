---
title: OSWE roadmap (WEB-300)
slug: oswe-roadmap
aliases: [oswe-prep-roadmap, web-300-roadmap]
---

{% raw %}

> **TL;DR:** A 12-week zero-to-OSWE study path. OSWE rewards source-driven whitebox exploitation — given the application's source, find an auth bypass and chain to RCE. Different from OSCP (network/web pentest) and OSEP (assumed-breach). Pair with [[whitebox-source-review]] and [[oscp-vs-osep-mindset]].

## Who this is for

- You have OSCP-level web fundamentals (XSS, SQLi, file upload, LFI) reflex.
- You can read PHP, Java, Node.js, .NET, Python without a tutorial.
- You want to certify the *source review* skill specifically.

## What OSWE tests

The 48-hour exam gives you two-to-three applications. For each:
- Source code is provided.
- You must achieve unauthenticated remote code execution.
- You must write a single Python exploit that ties the chain together (no manual steps mid-exploit).
- You write a report afterwards.

Typical chain shape: **auth bypass** (something that gives you a session as an admin) → **second-order injection** or **deserialisation** that an admin can reach → **RCE primitive**.

## Required mental model

- Source-to-sink data-flow reading without static analysis tools.
- Comfort with one debugger per language (Xdebug for PHP, IDE-debugger for Java/.NET, pdb for Python, ndb for Node).
- Building a Python exploit that authenticates, performs the chain, and lands a shell — all in one run.

## The 12 weeks

### Week 1 — methodology and tooling
- Read: [[whitebox-source-review]], [[whitebox-to-exploit-methodology]], [[source-sink-flow-analysis]], [[debugger-driven-source-review]].
- Set up Burp, an IDE per language, a Python venv with `requests`, `bs4`, `pyjwt`, `lxml`.
- Deliverable: a Python exploit *template* you'll reuse — session handling, helpers for `request_get` / `request_post`, named state.

### Week 2 — auth bypass patterns
- Read: [[auth-bypass-from-source-review]], [[broken-access-control]], [[idor]], [[application-logic-flaws]].
- Labs: PortSwigger auth-bypass labs end-to-end; HackTheBox web boxes ranked by AuthBypass tag.
- Deliverable: a checklist of auth-bypass classes (type-juggling, missing checks, race conditions, token forgery, role param tampering).

### Week 3 — PHP source review
- Read: [[php-code-auditing]], [[dangerous-php-sinks]], [[laravel-audit-patterns]], [[php-magic-methods]], [[php-deserialization-gadgets]].
- Labs: audit `osCommerce`, `prestashop`, an old `WordPress` plugin known to have a CVE. For each, find the bug from source before reading the advisory.
- Deliverable: written write-up of one CVE you re-discovered from source.

### Week 4 — Node.js source review
- Read: [[nodejs-code-auditing]], [[dangerous-nodejs-sinks]], [[express-nestjs-audit-patterns]], [[nodejs-prototype-pollution-audit]], [[prototype-pollution]], [[prototype-pollution-server-side]].
- Labs: audit a vulnerable Node.js app (NodeGoat, DVNA), find prototype-pollution → RCE chains.
- Deliverable: working chain proto-pollution → RCE in a sandbox app.

### Week 5 — Java source review
- Read: [[java-code-auditing]], [[dangerous-java-sinks]], [[java-deserialization-audit]], [[spring-boot-audit-patterns]], [[expression-injection]].
- Labs: gadget chain identification with `gadget-inspector` and `ysoserial`. Audit Spring apps for SpEL injection, EL/Thymeleaf misuse.
- Deliverable: a Java deserialization RCE in a sandbox app with documented gadget choice.

### Week 6 — .NET source review
- Read: [[dotnet-code-auditing]], [[dangerous-aspnet-sinks]], [[dangerous-dotnet-sinks-extra]], [[viewstate-attacks]].
- Labs: audit `OrangeHRM` or a similar legacy ASP.NET app; ViewState tampering, BinaryFormatter chains, Razor injection.
- Deliverable: working ViewState-MAC-bypass-to-RCE.

### Week 7 — Python source review
- Read: [[python-code-auditing]], [[python-dangerous-sinks]], [[django-audit-patterns]], [[python-deserialization]], [[python-ssti-jinja]].
- Labs: audit `Django` apps for SSTI, ORM injection, pickle deserialisation chains.
- Deliverable: a Django app SSTI → RCE chain.

### Week 8 — Ruby + Go
- Read: [[ruby-code-auditing]], [[ruby-deserialization-audit]], [[rails-audit-patterns]], [[go-code-auditing]], [[dangerous-go-sinks]].
- Labs: Rails Marshal deserialisation; one Go web app with template injection.
- Deliverable: cross-language source-review notes.

### Week 9 — second-order / blind injection
- Read: [[second-order-injection-chains]], [[blind-vuln-confirmation-from-source]], [[sql-injection-by-database]], [[nosql-injection]].
- Labs: chains where input stored at endpoint A is triggered at endpoint B; build exploits with out-of-band callbacks ([[oast-out-of-band-testing]]).
- Deliverable: a blind injection chain reaching RCE.

### Week 10 — modern stack
- Read: [[nextjs-server-actions-audit]], [[graphql-source-review]], [[htmx-server-side-injection]], [[websocket-state-sync-bugs]], [[apollo-server-audit-patterns]].
- Labs: audit a Next.js or NestJS app source-only; find the chain.
- Deliverable: source-only finding write-up.

### Week 11 — supply-chain and config
- Read: [[secrets-in-code-detection-patterns]], [[npm-postinstall-and-typosquat-audit]], [[python-pypi-supply-chain-audit]], [[ghost-commit-smuggling]].
- Labs: a target where the vulnerable code is in a dependency, not the main app.
- Deliverable: chain reaching RCE via a dep, not direct app code.

### Week 12 — mock + report
- Read: [[report-writing-for-pentesters]], [[oscp-exam-methodology]] (time-mgmt patterns translate).
- Labs: 48-hour mock against `vAPI`, `DVWA`, plus one self-built sandbox with deliberate bugs across three classes. Run your single-script exploit.
- Deliverable: OSWE-format report.

## Reusable Python exploit harness — start here, iterate weekly

A skeleton that handles session, retries, evidence dump, and a single-entry-point chain. Keep this in `~/oswe/exploit_template.py` and copy it per target.

```python
#!/usr/bin/env python3
"""OSWE single-script exploit template — auth bypass -> RCE chain."""
import sys, argparse, json, time, traceback
import requests, urllib3
urllib3.disable_warnings()

class Target:
    def __init__(self, base, proxy=None):
        self.base = base.rstrip('/')
        self.s = requests.Session()
        self.s.verify = False
        if proxy:
            self.s.proxies = {'http': proxy, 'https': proxy}
        self.s.headers.update({'User-Agent': 'oswe-exploit/0.1'})
        self.evidence = []

    def get(self, path, **kw):
        r = self.s.get(self.base + path, allow_redirects=False, timeout=30, **kw)
        self._log('GET', path, r)
        return r

    def post(self, path, **kw):
        r = self.s.post(self.base + path, allow_redirects=False, timeout=30, **kw)
        self._log('POST', path, r)
        return r

    def _log(self, m, p, r):
        self.evidence.append({'m': m, 'p': p, 'code': r.status_code, 'len': len(r.content)})

    def dump_evidence(self, path):
        with open(path, 'w') as f:
            json.dump(self.evidence, f, indent=2)

def step1_auth_bypass(t):
    # e.g. type juggling, SQLi auth bypass, JWT alg=none
    raise NotImplementedError

def step2_second_order_or_deser(t):
    # stage a payload that an admin path will trigger
    raise NotImplementedError

def step3_rce(t, cmd):
    # trigger the planted gadget, return command output
    raise NotImplementedError

def main():
    p = argparse.ArgumentParser()
    p.add_argument('-u', '--url', required=True, help='target base URL https://x.tld')
    p.add_argument('-c', '--cmd', default='id', help='command to run on RCE')
    p.add_argument('--proxy', default=None, help='http://127.0.0.1:8080 for Burp')
    p.add_argument('--evidence', default='evidence.json')
    args = p.parse_args()
    t = Target(args.url, proxy=args.proxy)
    try:
        step1_auth_bypass(t)
        step2_second_order_or_deser(t)
        out = step3_rce(t, args.cmd)
        print(out)
    except Exception as e:
        traceback.print_exc()
        sys.exit(1)
    finally:
        t.dump_evidence(args.evidence)

if __name__ == '__main__':
    main()
```

Why this shape:
- `--proxy` flag lets you pipe through Burp during dev, then ship clean.
- `evidence.json` becomes the appendix in the report — never lose the requests.
- `step1/2/3` enforce the "auth bypass -> staged write -> trigger" mental model.
- Single `main()` entry point matches the exam requirement of one Python script per target.

## Required artefacts before exam

- A reusable Python exploit harness with session handling, retry, exception capture, evidence dump.
- A note-template per finding with: file:line, sink, source, chain, screenshot.
- A pre-flight checklist for each lang.

## Practice corpus

Apps with known CVE chains that mirror the exam shape:
- **AtMail** — auth bypass into RCE (OSCP-PWK lab-adjacent).
- **OpenNetAdmin** — Java EL injection chains.
- **CodiMD/HedgeDoc** — Node SSRF + auth.
- **Mautic** — PHP chain with deserialisation.
- **Bolt CMS** — PHP type-juggling + file upload.
- **Jenkins** — Groovy + Stapler reflection chains.

OffSec's PG Practice has OSWE-tagged boxes.

## OSWE vs OSCP vs OSEP — one paragraph each

- **OSCP**: network/web pentest. Black-box. Sprint between targets. 24h.
- **OSWE**: source-driven web exploitation. Whitebox. One Python script per target. 48h.
- **OSEP**: assumed-breach red-team. Custom tooling, EDR evasion. 48h.

See [[oscp-vs-osep-mindset]] and [[oscp-osep-oswe-track-comparison]].

## Pragmatic notes from people who sat the exam
- **Blackbox-first inside a whitebox exam:** even though the course teaches source-first, most candidates open with a short blackbox session (login flow, parameter shape, route discovery) before opening the IDE. It anchors the source review around real requests.
- **Burp is a prerequisite, not a learnable skill mid-prep:** if you are not already fast in Burp Suite, fix that before week 1 — the exam time budget assumes muscle memory.
- **Prep length:** two months of focused module work plus the Extra Mile exercises plus three unguided practice labs is the most common path. Booking the exam the moment the practice labs land is fine.
- **Time shape, exam day:** plan ~15 hours for exploitation and ~10 hours for the report, with the rest as buffer. Pre-write the report skeleton; the writing phase is the unpleasant part and a template removes most of the pain.
- **Rabbit-hole tax:** the first chain often takes 3-4 hours to *find* and a fraction of that to *write*. Budget patience, not panic.

## References
- [OffSec — WEB-300 course](https://www.offsec.com/courses/web-300/)
- [TJ Null OSWE-like list](https://docs.google.com/spreadsheets/d/1dwSMIAPIam0PuRBkCiDI88pU3yzrqqHkDtBngUHNCw8/)
- [PortSwigger — Web Security Academy advanced labs](https://portswigger.net/web-security)
- [HackTricks](https://book.hacktricks.xyz/)
- Candidate experience report (Vietnamese): [OSWE — joy and disappointment](https://viblo.asia/p/oswe-niem-vui-va-su-that-vong-aAY4qw1wLPw)
- See also: [[whitebox-source-review]], [[oscp-roadmap]], [[osep-roadmap]], [[oscp-osep-oswe-track-comparison]], [[report-writing-for-pentesters]]

{% endraw %}
