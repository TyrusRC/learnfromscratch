---
title: Reverse WHOIS
slug: reverse-whois
---

> **TL;DR:** Search historic WHOIS records by registrant email, organisation name, or phone number to enumerate every domain the target ever registered — a horizontal-expansion staple.

## What it is
Standard WHOIS resolves a domain to its registrant; reverse WHOIS inverts the lookup, returning every domain associated with a given registrant identifier across historic records. Since most organisations use a recognisable corporate email or org name on at least their first registrations, one query often returns hundreds of apex domains — many of them forgotten brand parks, old acquisitions, and pre-rebrand identities still hosting live content.

## Preconditions / where it applies
- A recognisable target identity to pivot on: registrant email, org name, phone, postal address
- Tolerance for messy data — historic WHOIS includes typos and shared admin contacts
- Wildcard / "any owned asset" scope ([[program-scope-reading]]) so newly-discovered apexes are in scope

## Technique
1. **Seed identifiers.** Start with what you know:
   - Public registrar contact email (look up the primary apex first: `whois target.tld`)
   - Org name as it appears in HTTPS cert subject ([[certificate-transparency]])
   - Historical contact emails — look in security.txt, copyright footers, leaked PDFs
2. **Query reverse-WHOIS sources.** Each has different coverage and pricing:
   - ViewDNS reverse-whois (free, capped)
   - WhoisXMLAPI / Whoxy (paid, deeper history)
   - DomainTools Iris (expensive, best coverage)
   - DNSlytics, SecurityTrails (mixed coverage)
3. Combine output, dedupe by apex, and validate ownership. Privacy-shielded registrations (Domains By Proxy, Whoisguard) hide modern registrations; older records often pre-date the shield and reveal the same registrant.
4. **Cross-validate** each newly-discovered apex with a second signal before adding to scope:
   - Same [[analytics-tag-correlation]] ID
   - Same ASN / IP block ([[asn-enumeration]])
   - Same cert org subject across CT logs
   - Linked from official corporate site, press releases, or LinkedIn page
5. Feed validated apexes back into the normal pipeline ([[subdomain-enumeration]], [[acquisitions-recon]], [[asset-graphing]]). One pivot can multiply attack surface 10x.
6. Useful CLI for batch queries:
   ```
   whois -h whois.viewdns.info "@target-corp.com" | sed -n 's/.*Domain: //p'
   ```

## Detection and defence
- Reverse WHOIS lookups are passive and invisible to the target — no defender signal
- Defence is privacy shields, per-domain dummy contacts, and consistent use of a single registrar's privacy service for all corporate domains
- For the hunter: false positives are common — shared registrar admin contacts, MSP-managed registrations. Always cross-validate before submitting reports against newly-discovered apexes

## References
- [ViewDNS Reverse WHOIS](https://viewdns.info/reversewhois/) — free, low-volume reverse-whois UI
- [Whoxy reverse WHOIS](https://www.whoxy.com/reverse-whois/) — large historic index
- [HackTricks external recon methodology](https://book.hacktricks.wiki/en/generic-methodologies-and-resources/external-recon-methodology/index.html) — where WHOIS pivots fit
