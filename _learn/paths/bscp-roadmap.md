---
title: BSCP roadmap (Burp Suite Certified Practitioner)
slug: bscp-roadmap
aliases: [bscp-prep-roadmap, portswigger-cert-roadmap]
---

{% raw %}

> **TL;DR:** A six-week study path for PortSwigger's Burp Suite Certified Practitioner exam. The exam is a two-hour, three-stage practical against a live web app: foothold, privilege escalation, data exfiltration. Every technique tested comes from the Web Security Academy — this path maps each topic to KB notes and flags gaps. Pair with [[burp-suite]] and [[web-app-pentest-methodology]].

## Who this is for

- You can use Burp Suite beyond just proxying (Repeater, Intruder, Scanner, extensions).
- You have a working understanding of HTTP, cookies, and the DOM — OSCP-level web knowledge or equivalent.
- You want to certify practitioner-level black-box web exploitation skill specifically.

## What BSCP tests

The exam gives you two applications. For each, you must complete three stages within two hours:

- **Stage 1 — Foothold:** gain access to a low-privilege user account by exploiting a vulnerability.
- **Stage 2 — Privilege escalation:** escalate from the low-priv account to an administrator account.
- **Stage 3 — Data exfiltration:** use the admin access to read the contents of `/home/carlos/secret` (or similar) on the server.

Typical chain shape: **auth bypass or account takeover** (XSS stealing a cookie, SQLi extracting creds, OAuth flaw to impersonate) → **logic flaw or access-control bypass as the low-priv user** that yields admin → **SSRF, path traversal, SSTI, OS command injection, or XXE** to read a file from the server filesystem.

You must solve *both* applications to pass. Partial credit does not exist.

## Required mental model

- Treat each stage as a separate vulnerability class. Recognise the pattern: what gives you identity (stage 1), what gives you higher privilege (stage 2), what gives you server-side read or exec (stage 3).
- Reconnaissance drives everything — use Burp Scanner + manual crawl to map every endpoint before attacking.
- Time budget: ~50 minutes per application, ~10 minutes buffer. If stuck on one stage for 15 minutes, switch applications.
- Every tested technique has a corresponding PortSwigger Web Security Academy lab. If you can solve every "practitioner" and "expert" lab for a topic, you can handle it on the exam.

## The six weeks

### Week 1 — Burp fundamentals and reconnaissance

- Read: [[burp-suite]], [[http-and-web-primer]], [[http-enum]], [[information-disclosure]], [[banner-and-fingerprinting]], [[backup-and-config-leakage]].
- Labs: configure Burp with a browser, practice with Target → Site map, Scanner, Intruder (sniper/cluster bomb), and Repeater on any Web Security Academy lab. Install extensions: Param Miner, Hackvertor, Active Scan++.
- Deliverable: a Burp project template with scope rules, scan config, and extension set you will reuse on every target.

### Week 2 — Stage 1 techniques (foothold / account takeover)

These are the vulnerability classes that typically yield a low-privilege session.

**SQL injection**
- Read: [[sql-injection]], [[sql-injection-by-database]].
- Labs: all Web Security Academy SQLi labs (UNION, blind boolean, blind time, out-of-band).

**Cross-site scripting**
- Read: [[cross-site-scripting]], [[dom-xss]], [[content-security-policy-bypass]].
- Labs: reflected, stored, DOM-based XSS labs. Focus on cookie-stealing payloads and CSP bypass.

**Authentication attacks**
- Read: [[2fa-bypass]], [[remember-me-flaws]], [[session-fixation]], [[session-token-analysis]], [[password-spraying]].
- GAP: `[[authentication-lab-patterns]]` — a dedicated note on PortSwigger auth lab patterns (brute-force, 2FA bypass, stay-logged-in cookie, password reset poisoning) does not yet exist.
- Labs: all "Authentication" labs in Web Security Academy.

**OAuth and SSO**
- Read: [[oauth-flows]], [[oauth-token-theft]], [[oauth-token-leak-vectors]], [[oauth-authorization-code-injection]], [[oauth-modern-attacks]], [[sso-attacks]], [[pkce-downgrade-and-bypass]].
- Labs: all "OAuth authentication" labs.

**CSRF (as account takeover primitive)**
- Read: [[csrf]].
- Labs: CSRF labs — focus on the ones that chain to account takeover (email change → password reset).

**WebSocket hijacking**
- Read: [[websocket-attacks]].
- Labs: cross-site WebSocket hijacking lab.

- Deliverable: a cheat sheet per vuln class with payloads that yield session tokens or credentials.

### Week 3 — Stage 2 techniques (privilege escalation to admin)

These are the vulnerability classes that escalate a low-priv session to admin.

**Access control flaws**
- Read: [[broken-access-control]], [[idor]].
- Labs: all "Access control" labs (horizontal, vertical, IDOR, role-based).

**Business logic flaws**
- Read: [[application-logic-flaws]].
- GAP: `[[business-logic-lab-patterns]]` — a note mapping common business-logic flaw patterns (excessive trust in client-side controls, flawed state machines, domain-specific flaws) to PortSwigger labs does not yet exist.
- Labs: all "Business logic vulnerabilities" labs.

**HTTP Host header attacks**
- Read: [[host-header-injection]].
- Labs: password reset poisoning via Host header, web cache poisoning via Host header, routing-based SSRF.

**JWT attacks**
- Read: [[jwt]], [[jwt-jku-jwk-injection]], [[jwt-key-confusion]].
- Labs: all "JWT" labs — algorithm confusion, jku injection, kid path traversal, none algorithm.

**Prototype pollution**
- Read: [[prototype-pollution]], [[prototype-pollution-server-side]].
- Labs: client-side and server-side prototype pollution labs; DOM XSS via prototype pollution to escalate.

**Race conditions**
- Read: [[race-conditions]].
- Labs: single-endpoint and multi-endpoint race condition labs.

**GraphQL**
- Read: [[graphql-attacks]], [[graphql-batching-aliasing-abuse]].
- GAP: `[[graphql-lab-patterns]]` — a note covering PortSwigger GraphQL lab walkthroughs (introspection bypass, alias-based brute-force) does not yet exist.
- Labs: all "GraphQL API vulnerabilities" labs.

**NoSQL injection**
- Read: [[nosql-injection]].
- Labs: NoSQL injection labs (operator injection to bypass auth, extract data).

**Server-side parameter pollution**
- Read: [[server-side-parameter-pollution]], [[http-parameter-pollution]].
- Labs: parameter pollution labs — truncating, overriding, injecting via server-side parameter parsing.

- Deliverable: a methodology doc: "given a low-priv session, here are the 10 things I check for admin escalation."

### Week 4 — Stage 3 techniques (data exfiltration / server-side read)

These are the vulnerability classes that let you read files from the server.

**Server-side request forgery (SSRF)**
- Read: [[ssrf]], [[ssrf-to-cloud]], [[ssrf-to-cloud-advanced-chains]].
- Labs: basic SSRF, blind SSRF with out-of-band, SSRF via open redirect, SSRF with blacklist/whitelist bypass.

**XML external entities (XXE)**
- Read: [[xxe]].
- Labs: all XXE labs — file retrieval, blind XXE via out-of-band, XXE via file upload.

**Server-side template injection (SSTI)**
- Read: [[ssti]], [[python-ssti-jinja]].
- Labs: all SSTI labs — identification, exploitation for file read and RCE across Jinja2, Twig, Freemarker, ERB.

**OS command injection**
- Read: [[command-injection]].
- Labs: blind and inline command injection labs.

**Path traversal**
- Read: [[path-traversal]].
- Labs: all path traversal labs (dot-dot-slash bypass, encoding bypass, null-byte bypass, nested traversal sequences).

**File upload**
- Read: [[file-upload]].
- Labs: web shell upload, polyglot upload, race-condition upload.

**Insecure deserialization**
- Read: [[deserialisation]], [[php-deserialization-gadgets]], [[java-deserialization-audit]].
- Labs: all deserialization labs — PHP/Java gadget chains, modifying serialized objects.

**LFI/RFI (as file read primitive)**
- Read: [[lfi-rfi]].
- Labs: any remaining file-inclusion labs.

- Deliverable: a "Stage 3 exfil" cheat sheet: given admin access, the ordered list of techniques to try for reading `/home/carlos/secret`.

### Week 5 — Advanced and cross-cutting topics

These topics appear across all three stages and round out the BSCP syllabus.

**HTTP request smuggling**
- Read: [[http-request-smuggling]], [[http-smuggling-modern-variants]], [[request-tunnelling-desync]].
- Labs: CL.TE, TE.CL, TE.TE obfuscation, H2-exclusive desync, request tunnelling.

**Web cache poisoning**
- Read: [[cache-poisoning]], [[cache-poisoning-modern-chains]].
- Labs: all cache poisoning labs — unkeyed header/cookie, cache key manipulation.

**Web cache deception**
- Read: [[cache-deception]].
- Labs: all cache deception labs.

**Clickjacking**
- Read: [[clickjacking]].
- Labs: basic clickjacking, multi-step, with form prefill.

**DOM-based vulnerabilities**
- Read: [[dom-xss]], [[dom-clobbering]], [[postmessage-bugs]].
- Labs: DOM-based open redirect, DOM-based cookie manipulation, DOM clobbering.

**CORS misconfiguration**
- Read: [[cors-misconfig]], [[cors-acam-credential-bypass-patterns]].
- Labs: all CORS labs — reflected origin, null origin, trusted subdomains.

**Information disclosure**
- Read: [[information-disclosure]], [[backup-and-config-leakage]], [[git-source-leakage]].
- Labs: debug pages, source-code disclosure, information disclosure in error messages.

**API testing**
- Read: [[api-endpoint-analysis]], [[api-content-discovery]], [[swagger-discovery]], [[mass-assignment]].
- Labs: all "API testing" labs.

- Deliverable: a combined payload reference covering smuggling, cache poisoning, and DOM bugs.

### Week 6 — Mock exams and exam strategy

- Read: [[web-app-pentest-methodology]], [[report-writing-for-pentesters]], [[oast-out-of-band-testing]].
- Labs: complete at least three "mystery lab" sessions — pick a random practitioner/expert lab from each of six different categories, solve them back-to-back under a 2-hour timer. This simulates the exam's time pressure and topic breadth.
- Practice the three-stage flow: enumerate → foothold → enumerate as low-priv → escalate → enumerate as admin → exfil.
- Deliverable: a personal playbook for exam day — a decision tree for each stage with fallback techniques if the first approach fails.

## Gap summary — notes that need writing

These notes are referenced above but do not currently exist in the KB:

| Slug | Topic | Why it matters for BSCP |
|------|-------|------------------------|
| `authentication-lab-patterns` | PortSwigger auth lab patterns (brute-force, 2FA bypass, stay-logged-in, password-reset poisoning) | Stage 1 core — auth attacks are the most common foothold path |
| `business-logic-lab-patterns` | Business logic flaw taxonomy mapped to PortSwigger labs | Stage 2 — logic flaws are harder to enumerate than injection vulns |
| `graphql-lab-patterns` | PortSwigger GraphQL lab walkthroughs and exam-relevant patterns | Stage 2 — GraphQL is a newer exam topic with specific bypass patterns |

Existing notes that partially cover the gap and can be extended:
- [[2fa-bypass]] covers bypass patterns but not PortSwigger-specific lab methodology.
- [[application-logic-flaws]] covers the class but not the PortSwigger lab taxonomy.
- [[graphql-attacks]] covers the vuln class but not the specific BSCP exam patterns.

## Exam day strategy

### Time allocation (per application, 50 minutes)
1. **0–5 min:** Burp Scanner + manual crawl. Map all endpoints, note any non-standard behaviour.
2. **5–20 min:** Stage 1 — identify the foothold vuln. Check for SQLi, XSS, auth flaws, OAuth misconfig. Get a low-priv session.
3. **20–35 min:** Stage 2 — escalate. Check access-control, logic flaws, JWT, Host header, prototype pollution. Get an admin session.
4. **35–50 min:** Stage 3 — exfil. Try SSTI, SSRF, OS command injection, path traversal, XXE, file upload (web shell), deserialization.

### If stuck
- Switch to the other application. Fresh context often unblocks.
- Use Burp Scanner results — the exam apps are designed so Scanner findings point toward the vulnerability class.
- Check Burp's HTTP history for any unusual response patterns (headers, error messages, technology fingerprints).

### Common chain patterns seen in practice exams
- XSS (steal cookie) → IDOR (access admin panel) → SSTI (read file)
- SQLi (extract password) → Access control bypass (admin API) → Path traversal (read file)
- OAuth flaw (impersonate user) → JWT alg confusion (forge admin token) → SSRF (read file)
- Password reset poisoning → Logic flaw (role escalation) → OS command injection
- DOM XSS (steal token) → Prototype pollution (escalate) → Deserialization (RCE/file read)

## Practice resources

- **PortSwigger Web Security Academy** — the primary study material; every BSCP topic has free labs.
- **PortSwigger practice exam** — PortSwigger provides a practice exam environment; take it at least twice before the real exam.
- **Burp Suite Professional** — required for the exam; free Community edition is not sufficient.
- **HackTheBox** — web-focused machines for extra reps (not PortSwigger-specific, but builds breadth).

## BSCP vs OSCP vs OSWE — one paragraph each

- **BSCP**: Burp-centric blackbox web exploitation. Two-hour sprint. Stage-based chain: foothold → privesc → exfil. Pure web.
- **OSCP**: network + web pentest. Black-box. AD + standalone machines. 24h. Broader scope, shallower web depth.
- **OSWE**: source-driven whitebox web exploitation. Given source code, find auth bypass + chain to RCE. 48h. Python exploit script per target.

See [[oscp-roadmap]], [[oswe-roadmap]], [[oswa-roadmap]], [[oscp-osep-oswe-track-comparison]].

## Pragmatic notes from people who sat the exam
- **Burp Scanner is your friend:** the exam is designed around Burp. Run an active scan early — it will often identify the vulnerability class for Stage 1 or Stage 3, saving manual probing time.
- **Complete all Academy labs first:** candidates who solved every practitioner-level lab in the relevant categories report feeling over-prepared. That is the right feeling.
- **Param Miner is critical:** cache poisoning and Host header attacks often depend on discovering unkeyed parameters. Param Miner automates this.
- **The second application is not harder:** both applications have the same difficulty; one is not a bonus or an escalation. Budget time equally.
- **Practice exams are representative:** PortSwigger's practice exam closely mirrors the real thing in format and difficulty. If you can reliably pass the practice exam, you are ready.

## References
- [PortSwigger — BSCP exam page](https://portswigger.net/web-security/certification)
- [PortSwigger — Web Security Academy](https://portswigger.net/web-security)
- [PortSwigger — all labs](https://portswigger.net/web-security/all-labs)
- [Burp Suite documentation](https://portswigger.net/burp/documentation)
- [HackTricks — web pentesting](https://book.hacktricks.xyz/pentesting-web/web-vulnerabilities-methodology)
- See also: [[burp-suite]], [[web-app-pentest-methodology]], [[oscp-roadmap]], [[oswe-roadmap]], [[oswa-roadmap]], [[report-writing-for-pentesters]]

{% endraw %}
