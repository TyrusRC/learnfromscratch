---
title: Dangling DNS (NS / MX / A) takeover
slug: dangling-dns-takeover
---

> **TL;DR:** Beyond CNAME — orphaned NS delegations, expired domain MX records, decommissioned IP ranges reassigned to attacker.

## What it is
The classic [[subdomain-takeover]] story is a CNAME pointing at a deprovisioned SaaS hostname. The same primitive exists for every other record type. A DNS entry points at an external resource that the org no longer controls; whoever now controls that resource speaks for the subdomain. NS delegation takeover is the most dangerous variant — control of the NS lets you sign every record in the zone.

## Preconditions / where it applies
- NS record delegates to a third-party authoritative DNS account that was closed
- MX record points at a mail provider tenant or domain that was let expire
- A / AAAA record points at a cloud public IP that was released back to the pool (EIP, Azure public IP, GCP ephemeral)
- Org no longer renews the destination domain but the DNS record still exists

## Technique
Enumerate every record type, not just CNAME:

```bash
dnsx -l subs.txt -a -aaaa -cname -mx -ns -txt -resp -silent
```

**NS takeover.** Query NS for each subdomain. If it delegates to a managed DNS provider (e.g. cloud DNS, name.com, ns.example-saas.com), check whether the zone exists on that provider — `dig @ns1.provider sub.target.com SOA`. SERVFAIL or REFUSED suggests the zone was deleted; re-register the zone on the same provider account-side and you serve authoritative answers for the entire subdomain.

**MX takeover.** Resolve MX → check destination domain WHOIS. If expired, re-register; receive password resets, signup confirmations, internal mail. Bonus: many SPF/DKIM/DMARC checks now pass because you sign from the legitimate provider.

**Dangling A.** Resolve A → IP. Check if IP belongs to a cloud range (AWS, Azure, GCP, DO, Linode). If yes, request public IPs in that region until you get assigned that exact IP. AWS Elastic IP pools and Azure's regional pools have well-documented reuse risk.

```bash
# loop allocating EIPs and check
while true; do
  ip=$(aws ec2 allocate-address --query PublicIp --output text)
  echo "$ip"
  [ "$ip" = "$TARGET_IP" ] && break
  aws ec2 release-address --public-ip "$ip"
done
```

Related: [[ssrf-to-cloud]] for downstream credential theft once you control a subdomain that gets internal calls.

## Detection and defence
- Inventory all DNS records and assert the destination is still controlled (provider API check)
- For cloud A records, prefer aliases / hostnames (CNAME to provider-managed name) over raw IPs
- Use long DNS TTL only for stable resources; release-then-delete in CI
- Monitor NXDOMAIN responses from your authoritative NS — sign of orphan
- Run periodic external sweeps (e.g. nuclei dns/takeover templates)

## References
- [HackerOne — Guide to subdomain takeovers v2](https://www.hackerone.com/blog/Guide-Subdomain-Takeovers-v2) — covers NS/MX variants
- [Patrik Hudak — Dangling DNS](https://0xpatrik.com/subdomain-takeover-ns/) — NS takeover deep dive
- [HackTricks — Domain/subdomain takeover](https://book.hacktricks.wiki/en/pentesting-web/domain-subdomain-takeover.html) — provider-specific fingerprints
