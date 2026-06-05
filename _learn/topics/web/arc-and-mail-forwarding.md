---
title: ARC and mail forwarding
slug: arc-and-mail-forwarding
aliases: [arc-protocol, mail-forwarding-auth]
---

> **TL;DR:** ARC (Authenticated Received Chain, RFC 8617) is a cryptographic chain of custody for email authentication results. It exists because SPF and DKIM almost always break when a message is forwarded (mailing lists, alumni redirectors, M365 transport rules), which in turn breaks [[dmarc-spf-dkim-deep]] alignment and gets legitimate mail rejected. Each ARC-aware hop adds three headers (`ARC-Authentication-Results`, `ARC-Message-Signature`, `ARC-Seal`) so a downstream receiver can decide "I trust hop N's verdict even though SPF/DKIM are broken now." Pairs with [[email-gateway-bypass-techniques]] for the offensive side and [[aitm-evilginx-modern-phishing]] for downstream phishing implications.

## Why it matters

DMARC enforces alignment between the RFC5322.From domain and an authenticated identifier (SPF return-path or DKIM `d=`). Forwarding breaks this in predictable ways:

- A mailing list rewrites the envelope sender, so SPF for the original domain no longer passes at the final hop.
- The list (or a security gateway) modifies the body (footer injection, link rewriting, subject tagging) so the original DKIM signature fails.
- Some forwarders re-sign with their own DKIM, but the `d=` no longer aligns with the original `From:`.

The result: a strict DMARC policy (`p=reject`) at the original sender causes downstream rejections for legitimate forwarded mail. Big senders (banks, SaaS) used to either avoid `p=reject` or beg list operators to use `From:` munging. ARC was designed to keep `p=reject` viable while preserving forwarding semantics, and it shows up in detection pipelines covered in [[siem-detection-use-case-catalog]] and inbound-mail forensics from [[ir-from-source-signals]].

For attackers, ARC is interesting because:

- Some receivers grant **local policy overrides** when a trusted ARC chain says SPF/DKIM passed upstream. Trick the chain, bypass DMARC.
- It introduces new headers that parsers, gateways, and DLP tools may handle inconsistently — fertile ground for [[email-gateway-bypass-techniques]] and [[http-request-smuggling]]-style desync but in MTA land.

## ARC chain structure

A single hop adds three headers, all stamped with the same instance number `i=N` (starting at 1 for the first ARC-aware hop):

### ARC-Authentication-Results (AAR)

A frozen snapshot of the `Authentication-Results` the current hop computed: SPF, DKIM, DMARC, sometimes BIMI/DKIM2 results. Format mirrors RFC 8601:

```
ARC-Authentication-Results: i=1; mx.example.org;
  spf=pass smtp.mailfrom=alice@sender.example;
  dkim=pass header.d=sender.example header.s=sel1;
  dmarc=pass header.from=sender.example
```

### ARC-Message-Signature (AMS)

A DKIM-style signature over the message headers and body **as the hop received them** (before any modification it is about to do). The `d=` and `s=` identify the signing hop. Without AMS, a downstream receiver cannot know that the AAR verdict applied to the message it is actually evaluating now.

### ARC-Seal (AS)

A signature over the ARC chain itself: the prior `AS`, prior `AMS`, and prior `AAR` for instances `1..N-1`, plus the new instance's AAR and AMS. It carries `cv=` (chain validation): `none` for `i=1`, `pass` for a valid chain at `i>1`, or `fail` if the previous hop already marked the chain broken.

The seal pattern means tampering with any prior header breaks every downstream seal — you can't quietly forge a hop 2 result without also re-signing hop 3, 4, ... with their private keys.

### Worked example

```
ARC-Seal: i=2; a=rsa-sha256; t=1717612800; cv=pass;
  d=forwarder.example; s=arc; b=Base64SealSig...
ARC-Message-Signature: i=2; a=rsa-sha256; c=relaxed/relaxed;
  d=forwarder.example; s=arc; t=1717612800;
  h=From:To:Subject:Date:Message-ID; bh=BodyHash; b=Base64AmsSig...
ARC-Authentication-Results: i=2; forwarder.example;
  arc=pass smtp.remote-ip=203.0.113.10;
  spf=fail smtp.mailfrom=bob@list.example;
  dkim=fail header.d=sender.example;
  dmarc=fail header.from=sender.example
ARC-Seal: i=1; a=rsa-sha256; t=1717612700; cv=none;
  d=sender.example; s=arc; b=Base64SealSig...
ARC-Message-Signature: i=1; ...
ARC-Authentication-Results: i=1; sender.example;
  spf=pass; dkim=pass; dmarc=pass
```

Reading bottom-up: hop 1 (sender.example) attested SPF/DKIM/DMARC pass. Hop 2 (forwarder.example) saw SPF/DKIM fail in its own checks (forwarding broke them) but sealed the prior chain with `cv=pass`. A receiver that trusts forwarder.example can override the local DMARC `fail` based on the ARC chain.

## Trust evaluation

The protocol deliberately punts trust to the local receiver. A receiver typically:

1. Validate every AS and AMS in the chain in instance order.
2. If any seal does not validate, mark chain `cv=fail` locally and stop trusting it.
3. If chain validates, walk hops looking for an `i=k` whose `d=` is in the receiver's **ARC trusted-signer list**.
4. If hop `k` says SPF/DKIM/DMARC passed at the time, allow a local policy override of the current DMARC verdict.

The trusted-signer list is the entire ball game. Gmail famously trusts a curated set of high-volume forwarders; M365 maintains its own list. There is no public registry — operators decide. For defenders this is a [[detection-engineering-pyramid-of-pain]] knob: misuse of ARC is bounded by which `d=` domains a receiver trusts.

## Implementation status

- **Google / Gmail:** signs and verifies ARC at all inbound and outbound boundaries. ARC results feed into the spam classifier and DMARC override decisions. Documented as part of the 2024 sender-requirements push.
- **Microsoft 365 / Exchange Online:** ARC is supported; tenant admins can configure "trusted ARC sealers" (e.g., a security gateway like Mimecast or Proofpoint that sits in front of M365). Without that allowlist entry the chain is informational only.
- **Proofpoint, Mimecast, Barracuda, Cisco Secure Email:** all seal ARC on transit. This matters when these sit in front of M365 — without the trusted-sealer config, forwarded mail still fails DMARC.
- **Open-source:** OpenARC (libopendkim fork), Rspamd `arc` module, OpenDMARC has partial support.

In practice in 2025, a mail flow of `internet → security gateway → M365` only benefits from ARC if the tenant explicitly trusts the gateway's signing domain. This is the most common ARC misconfiguration in enterprise environments and a common finding in audits referenced from [[testing-methodology-checklists]].

## Attack surface

### ARC replay

ARC seals a chain but **not** the recipient. If an attacker obtains a legitimately ARC-sealed message (e.g., one delivered to a compromised mailbox covered in [[m365-admin-attacks]]), they can:

1. Resend it to a different recipient (or with modified envelope) over a fresh SMTP connection.
2. The new receiver validates the chain, sees an entry from a trusted sealer with `dmarc=pass`, and may override its own DMARC fail.
3. This is the email equivalent of cookie replay — covered also by [[aitm-evilginx-modern-phishing]] for session theft.

Mitigations: bind seal to recipient (proposed extensions), check timestamps strictly, watch for chain age, and treat ARC as advisory rather than authoritative.

### AMS forgery against weak hops

If any hop in the chain uses RSA-1024 or rotates DNS keys carelessly, an attacker who compromises that key can forge AMS at that hop. Downstream seals will still validate as long as the chain math holds. This compounds with [[dmarc-spf-dkim-deep]] hygiene problems.

### Trusted-sealer confusion

If a receiver trusts `gw.vendor.example` and the same vendor signs ARC for thousands of tenants, an attacker who can get **any** message through that vendor with a passing first-hop result can ride the trust. Pairs with [[domain-fronting-and-cdn-abuse]] logic — shared trust at a hop is shared trust everywhere.

### Header injection / smuggling

Some MTAs and gateways do not normalise multiple `ARC-Seal` instances correctly. Insert your own forged `i=1..N-1` headers before the real chain and confuse receivers that pick the "highest `i=`" naively. Bug class kin to [[smtp-injection]] and [[http-request-smuggling]].

### Chain truncation

Strip the chain entirely and let DMARC fall back. If the original sender uses `p=quarantine` instead of `p=reject` with low confidence at the receiver, the message may still land. Companion read: [[email-gateway-bypass-techniques]].

## Defensive baseline

- Publish DMARC at `p=reject` with `rua`/`ruf` reporting; review weekly. See [[siem-detection-use-case-catalog]].
- Seal ARC on every outbound and inbound boundary you control. Use ed25519 or RSA-2048 minimum.
- Maintain an explicit **trusted ARC sealers** list at the final receiver. Default-deny: empty list is safer than a wildcard.
- Alert on ARC chains where `cv=fail` appears, where instance numbers skip, or where a trusted sealer suddenly signs from a new IP range.
- For M365: configure `Set-ArcConfig` with vetted trusted signers; review quarterly.
- Log full ARC chains in your SIEM for at least 90 days for replay correlation. Couples with [[ir-from-source-signals]].
- Treat ARC as a **local override hint**, never as gospel. Combine with reputation, content scoring, and [[cti-collection-management]] feeds.

## Workflow to study

1. Read RFC 8617 end to end. Then re-read sections 5 (seal computation) and 7 (security considerations) — that is where the attack surface lives.
2. Stand up Postfix + OpenARC in a lab from [[building-a-research-home-lab]]. Send mail through it, dump headers, verify the seal math by hand against `openssl dgst`.
3. Add a second hop (another Postfix VM) and a list manager (mlmmj or sympa). Observe AMS failing at hop 2 while ARC chain validates.
4. Replay a sealed message to a third recipient. Confirm chain still validates — internalise the replay risk.
5. Tamper with `i=1` AAR (change `dmarc=pass` to `dmarc=fail` in a copy) and watch `cv=fail` propagate.
6. Diff your lab behaviour against Gmail and M365 by sending real messages and checking received headers.
7. Write findings up using [[report-writing-for-pentesters]] structure.

## Related

- [[dmarc-spf-dkim-deep]]
- [[email-gateway-bypass-techniques]]
- [[smtp-injection]]
- [[smtp-enum]]
- [[aitm-evilginx-modern-phishing]]
- [[oauth-device-code-phishing-m365]]
- [[m365-admin-attacks]]
- [[tycoon2fa-and-modern-phish-kits]]
- [[siem-detection-use-case-catalog]]
- [[ir-from-source-signals]]
- [[detection-engineering-pyramid-of-pain]]
- [[testing-methodology-checklists]]

## References

- IETF RFC 8617 — Authenticated Received Chain (ARC) protocol: https://datatracker.ietf.org/doc/html/rfc8617
- Google sender guidelines on ARC and DMARC: https://support.google.com/a/answer/13464326
- Microsoft Learn — Configure trusted ARC sealers in M365: https://learn.microsoft.com/en-us/defender-office-365/email-authentication-arc-configure
- M3AAWG ARC deployment guidance: https://www.m3aawg.org/sites/default/files/m3aawg-arc-deployment-2018-04.pdf
- OpenARC project (reference implementation): https://github.com/trusteddomainproject/OpenARC
- dmarcian — explainer on ARC and forwarding survival: https://dmarcian.com/what-is-arc/
