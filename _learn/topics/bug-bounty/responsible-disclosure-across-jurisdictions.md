---
title: Responsible disclosure across jurisdictions
slug: responsible-disclosure-across-jurisdictions
aliases: [coordinated-disclosure, disclosure-law, vuln-disclosure-policy]
---

> **TL;DR:** "Responsible disclosure" looks the same in technical writeups but is legally inconsistent across jurisdictions. The US (CFAA), UK (Computer Misuse Act 1990), EU (NIS2 + national implementations), Germany (StGB §202c), Japan, Brazil, and others all treat unauthorised testing differently. Researchers operating internationally must understand: scope of authorisation, safe-harbour legalities, journalist-protection limits, export control on PoC code, and bounty-program contractual protections. Companion to [[report-writing-step-by-step]] and [[disclosure-and-comms]].

## Why it's complicated

Security research often:
- Tests against a system that may be in another country.
- Discloses to a vendor headquartered elsewhere.
- Publishes a writeup readable globally.
- May require sharing PoCs that have dual-use export controls.
- May involve government infrastructure or critical services.

Each jurisdiction has different defaults. A researcher in country A testing system in country B disclosing to vendor in country C, publishing in country D, may have to satisfy four legal regimes.

## Jurisdiction snapshot

### United States — CFAA + DMCA

- **CFAA (18 USC §1030)** — criminalises "unauthorised access". Authorisation interpretation has narrowed since Van Buren (2021).
- **DMCA §1201** — anti-circumvention; some research exceptions added in 2022.
- **State laws** vary; California, Illinois have additional consumer-data laws.
- **Safe-harbour** common in bug bounty contracts; only as strong as the contract terms.

### United Kingdom — Computer Misuse Act 1990

- **CMA §1** unauthorised access; **§2** with intent; **§3** modifying.
- Penalties up to 14 years.
- No statutory safe-harbour for security research.
- Industry pressure for CMA reform ongoing.

### European Union — NIS2 + national implementations

- **NIS2 Directive** requires coordinated vulnerability disclosure (CVD) policies at member-state level.
- **Cyber Resilience Act (CRA)** — manufacturers required to handle vulnerabilities.
- National laws vary in researcher protection: Belgium has explicit safe-harbour; Germany historically restrictive.

### Germany — §202a/202b/202c StGB

- **§202c** "Hacker Paragraph" — criminalises possession of "computer programs intended for committing a crime" (Sec. 202a). Interpreted broadly; has chilled tools.
- Research exceptions in case law but unclear in statute.
- Some researchers don't publish PoCs out of caution.

### Japan — Unauthorised Computer Access Law

- Pre-authorisation requirement is strict.
- Research must be pre-authorised by target.

### Australia — Criminal Code Act 1995

- §477.1 unauthorised access; §477.3 production / supply / obtain of data with intent.
- Research carve-outs limited.

### Brazil — Carolina Dieckmann Act / LGPD

- Computer-crime law (Lei 12.737) plus data-protection (LGPD).
- Researcher protection limited.

### Singapore — Computer Misuse Act + PDPA

- Strict; pre-authorisation expected.
- Government-coordinated VDP through CSA.

### South Korea, China, Russia, Iran

- Highly restrictive. Independent research highly risky without explicit government coordination.

## Bug bounty contractual safe-harbour

Programs publish a "safe-harbour" or "VDP" section. Common protections:
- Will not initiate civil or criminal action against good-faith researchers acting within scope.
- May indemnify researchers acting within scope.
- Specifies what's in/out of scope behaviourally (no DoS, no social engineering, no data exfil beyond proof).

Strength varies:
- HackerOne / Bugcrowd standard templates are widely adopted.
- Disclose.io provides a model framework.
- Government VDPs (CISA's Federal VDP) extend coverage.

These contractual protections often supplement but don't override criminal statutes; in many countries the government can still prosecute regardless of contract.

## Independent research without a bug bounty

If you find a bug in software with no public VDP / bug bounty:

### Options

1. **Email security@<vendor>** — many vendors have an unpublished disclosure inbox. Use clear, factual language; don't threaten disclosure.
2. **CERT coordination** — US-CERT (now CISA), JPCERT, KrCERT, others coordinate vendor contact and timeline.
3. **Coordinated disclosure platforms** — Bugcrowd / HackerOne offer mediated disclosure for non-program-vendors.
4. **Public disclosure** — only after exhausting vendor contact, typically with timeline (90 days CERT, or Project Zero 90-day standard).
5. **Government channel** — for critical infrastructure, sometimes coordinated via national CERT.

### Risks

- **No contract → no safe-harbour** even if vendor doesn't sue.
- **Vendor may sue / report to law enforcement** — has happened (Coalfire / Iowa case 2019, Aaron Swartz 2013, others).
- **Cross-border** — vendor pursuing you across borders is more painful than civil suit at home.

## Best practices

### Before testing

- Verify scope in writing.
- For programs: read every word of the VDP.
- For non-program: pre-authorise via email if at all possible.
- Stay strictly in scope.

### During testing

- Minimum-impact validation; don't exfil beyond proof.
- Document timestamps, IP addresses you used.
- Don't share PoCs prematurely.

### During disclosure

- Use vendor's published channel.
- Provide actionable details for remediation.
- Agree on timeline (90 days standard, negotiable for criticality).
- Coordinate publication.

### After patch

- Publish writeup at the agreed time.
- Credit vendor for cooperation.
- Don't include weaponisable PoCs if doing so amplifies risk to unpatched systems.

## Specific situations

### Public-sector / critical infrastructure

- ICS / SCADA / medical-device / utility vulnerabilities have additional reporting obligations (CISA, ICS-CERT, FDA for medical, NCSC for UK CNI).
- Government may impose embargoes for national-security reasons.
- Always coordinate; don't disclose unilaterally.

### National security research

- US ITAR / EAR may restrict sharing certain crypto / exploitation PoCs.
- Wassenaar Arrangement → national export controls on "intrusion software" — varies by country.
- Researchers traveling internationally with offensive tools may face customs issues.

### AI / LLM red teaming

- Newer; jurisdiction-specific guidance is sparse.
- Anthropic, OpenAI, Google have published bug bounty terms; treat as binding contract.
- For prompt injection in deployed products: same VDP rules as web apps.

### Vulnerability brokering

- Selling vulnerabilities to third-party brokers (ZDI, Zerodium, Crowdfense) is legal in some jurisdictions, restricted in others.
- Government end-customer restrictions may apply.

## Jurisdiction-mismatch playbook

For a multi-jurisdiction situation:

1. Identify all relevant jurisdictions: your residence, target system location, vendor HQ, publication audience.
2. Find the **most restrictive** that applies; assume that standard.
3. Get authorisation in writing from vendor in **the most restrictive jurisdiction**.
4. Avoid publication in jurisdictions where your activity is criminal.
5. Consult counsel for high-stakes situations.

## Practical resources

- **Disclose.io** — VDP framework adoption.
- **CERT/CC Vulnerability Disclosure Guide**.
- **Hacker One Hacker Code of Conduct**.
- **Bugcrowd VRT** + standardised disclosure agreements.
- **EFF security research guides**.
- **Lawyers** specialising in security research (Tor Ekeland, Marcia Hofmann, others).

For pre-action consultation, EFF and Mozilla maintain attorney contact lists.

## Where to start

If you're new to disclosure:

1. **Stay inside published bug bounty programs** for your first year.
2. **Read every VDP** before testing.
3. **Build relationships** with triagers at programs you target frequently.
4. **Document everything**.
5. **Have a lawyer's phone number** even if you never call it.

## Related

- [[report-writing]]
- [[report-writing-step-by-step]]
- [[disclosure-and-comms]]
- [[program-scope-reading]]
- [[ctf-to-bug-bounty-transition]]

## References
- [Disclose.io](https://disclose.io/)
- [CERT/CC Vulnerability Disclosure Guide](https://vuls.cert.org/confluence/display/CVD/)
- [EFF — Coders' Rights Project](https://www.eff.org/issues/coders)
- [Project Zero — disclosure policy](https://googleprojectzero.blogspot.com/p/vulnerability-disclosure-faq.html)
- [Center for Democracy & Technology — VDP comparison](https://cdt.org/)
- See also: [[report-writing]], [[disclosure-and-comms]], [[ctf-to-bug-bounty-transition]]
