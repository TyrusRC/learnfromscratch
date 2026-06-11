---
title: AI-300 roadmap (AI Red Teamer)
slug: ai-300-roadmap
aliases: [ai-300-prep-roadmap, ai-red-teamer-roadmap]
---
{% raw %}

> AI-300 is OffSec's AI Red Teamer certification. It tests whether you can break LLM-backed applications end-to-end: prompt injection (direct and indirect via RAG/tool output), jailbreaks, model and training-data extraction, agentic loop hijacking, MCP abuse, and model supply-chain tampering. Expect a hands-on exam against a graded LLM-app stack with a written report at the end. Plan on 10 weeks of focused study if you already have web pentest fundamentals and can write Python; longer if either is shaky. Ideal candidate: a working AppSec/red-team engineer who has shipped at least one LLM feature or audited one, and is comfortable reading model-server code.

## Who this is for

- You have web pentest fundamentals (OWASP Top 10, Burp, auth flows) — AI-300 assumes you can already break a normal web app.
- You write Python fluently — every harness, fuzzer and eval you build will be Python.
- You have touched the OpenAI/Anthropic/HF APIs at least once and understand tokens, context windows, and tool/function calling.
- You can stand up Docker, a vector DB and a local model without hand-holding.
- You are comfortable writing reports that translate weird LLM behaviour into business impact.

## What AI-300 tests

- Format: proctored, hands-on lab exam against a graded LLM-application environment plus a written report.
- Duration: roughly 48 hours of lab time followed by a 24-hour report window (treat the report as half the grade).
- Environment: OffSec-hosted stack with multiple LLM apps — a RAG assistant, an agent with tools, and at least one MCP-style integration.
- You must demonstrate working exploits, not theoretical ones — payloads, transcripts, and reproduction steps.
- Coverage: OWASP LLM Top 10 mapped to concrete attacks (LLM01 prompt injection, LLM02 insecure output handling, LLM06 sensitive info disclosure, LLM07 insecure plugin design, LLM10 model theft).
- Deliverables: a professional report with proof-of-exploit, impact, and remediation per finding — graded like an OSCP report, not a blog post.
- Scoring rewards full chains (injection -> tool abuse -> data exfil) over isolated single-turn jailbreaks.
- Novel-technique allowance: anything you discover mid-engagement counts if you can reproduce it.

## Lab setup (do before week 1)

- Linux host with 32 GB RAM minimum, NVIDIA GPU with 12 GB+ VRAM if you want to run local models seriously.
- Python 3.11 with `uv` or `pyenv`; pin per-project venvs.
- Docker Engine 26+ and `docker compose` v2 for spinning up vulnerable stacks.
- Ollama 0.3+ for local Llama 3.1, Qwen 2.5, Mistral; plus an OpenAI and Anthropic API key for cross-vendor testing.
- A vector DB you control: Chroma or Qdrant in Docker. Do not depend on managed services.
- Tooling baseline: `promptfoo` (npm), `pyrit` (pip), `garak` (pip), `giskard` (pip), `nemoguardrails` (pip).
- Burp Suite Pro with the AI-focused extensions; mitmproxy for inspecting model traffic that Burp mangles (SSE, websockets).
- A note-taking system that survives 10 weeks — Obsidian vault, one note per attack class, one transcript per successful exploit.

```bash
uv venv ai300 && source ai300/bin/activate
uv pip install pyrit garak giskard nemoguardrails openai anthropic httpx
npm i -g promptfoo
docker run -d -p 6333:6333 qdrant/qdrant:latest
ollama pull llama3.1:8b qwen2.5:7b
```

## The 10 weeks

### Week 1 — LLM threat model and OWASP LLM Top 10

- Read: [[ai-red-teaming]], [[llm-prompt-injection]], [[owasp-llm-top-10]], [[report-writing-for-pentesters]]
- Labs: Walk every category in `garak --list_probes` against a local Llama 3.1 8B and record which probes trip on a vanilla system prompt.
- Deliverable: a one-page threat-model template you reuse for every target — assets, trust boundaries, prompt-flow diagram.

### Week 2 — Direct prompt injection and jailbreaks

- Read: [[llm-prompt-injection]], [[llm-jailbreaks-2025]], [[ai-eval-harnesses-promptfoo]]
- Labs: Reproduce DAN-family, payload smuggling (base64, ROT, unicode tag chars), and multilingual jailbreaks against three vendors. Confirm which still work on current frontier models.
- Deliverable: a `promptfoo` suite of 40+ jailbreak cases with pass/fail asserts, runnable in CI.

### Week 3 — Indirect prompt injection via RAG

- Read: [[indirect-prompt-injection-via-rag]], [[llm-prompt-injection]], [[ai-red-teaming]]
- Labs: Stand up a RAG chatbot over Qdrant. Poison a document so a benign user query triggers exfiltration of session context to a webhook.
- Deliverable: a documented exploit chain with the poisoned document, the user query, and the captured exfil request.

### Week 4 — Agentic loop hijacking and tool abuse

- Read: [[agentic-llm-attacks]], [[indirect-prompt-injection-via-rag]], [[ai-red-team-tooling-pyrit-garak]]
- Labs: Build a LangGraph or pure-Python agent with three tools (search, file read, shell). Hijack it via tool output to call an unintended tool with attacker-chosen args.
- Deliverable: a video or transcript showing the agent reading attacker content and then executing a destructive tool call.

### Week 5 — MCP server abuse

- Read: [[mcp-attacks]], [[mcp-server-supply-chain-attacks]], [[agentic-llm-attacks]]
- Labs: Run two community MCP servers locally; demonstrate tool-poisoning (malicious tool description that hijacks the model) and cross-server confused-deputy.
- Deliverable: a written MCP threat-model section with three concrete CVE-class findings.

### Week 6 — Model and training-data extraction

- Read: [[ai-red-teaming]], [[llm-prompt-injection]], [[ai-red-team-tooling-pyrit-garak]]
- Labs: Use PyRIT orchestrators to extract system prompts, hidden tool schemas, and memorised training fragments from a fine-tuned model you host yourself.
- Deliverable: a redacted transcript proving system-prompt recovery with diff against the real prompt.

### Week 7 — Supply chain: models, datasets, packages

- Read: [[supply-chain-attacks-on-models]], [[slopsquatting]], [[mcp-server-supply-chain-attacks]]
- Labs: Build a malicious Hugging Face repo with a poisoned `pickle` and a benign-looking `safetensors`; demonstrate code execution on load. Then craft a slopsquatted PyPI name that an LLM coding assistant happily recommends.
- Deliverable: a supply-chain finding writeup including detection rules a defender could deploy.

### Week 8 — Evals, guardrails and bypasses

- Read: [[ai-eval-harnesses-promptfoo]], [[ai-red-team-tooling-pyrit-garak]], [[llm-jailbreaks-2025]]
- Labs: Wrap a target with NeMo Guardrails and Llama Guard; then break each control with payload smuggling and tool-output injection.
- Deliverable: a guardrail-bypass matrix — control vs attack vs result — that becomes a section in your report.

### Week 9 — Full-chain engagement rehearsal

- Read: [[agentic-llm-attacks]], [[mcp-attacks]], [[report-writing-for-pentesters]]
- Labs: Pick a vulnerable app (Damn Vulnerable LLM Agent, Gandalf, Lakera's gauntlet) and chain at least three primitives into a single business-impact finding.
- Deliverable: a dry-run report with executive summary, finding chain, and remediation, time-boxed to 24 hours.

### Week 10 — Exam simulation

- Read: re-read your own notes; skim [[ai-red-teaming]] and [[report-writing-for-pentesters]] only.
- Labs: 48-hour timed run against a target you have not touched; no new tooling allowed.
- Deliverable: a graded report you would actually submit. Have a peer review it.

## Required tooling

- promptfoo, PyRIT, garak, Giskard, NeMo Guardrails, Llama Guard
- Burp Suite Pro, mitmproxy, `httpx`
- Ollama, vLLM or TGI for self-hosted targets
- Qdrant or Chroma for RAG labs
- LangGraph or a small custom agent loop you fully understand
- Docker, `uv`, `jq`, `ripgrep`

## Practice corpus

- Gandalf (Lakera) — fast feedback on direct injection
- Damn Vulnerable LLM Agent — agentic tool abuse
- Prompt Airlines, Doublespeak, Tensor Trust — adversarial prompt games
- MCP reference servers (filesystem, fetch, git) — real protocol surface
- Hugging Face's `huggingface/transformers` issues for live model-loading CVEs
- AI Village CTFs at DEF CON archives for end-to-end scenarios

## Pragmatic notes from people who sat the exam

- Build your own eval harness early — promptfoo plus a small Python wrapper beats memorising payloads. The harness is also half your report appendix.
- Tooling moves monthly; the exam rewards methodology. If garak's probe X fails today, you should be able to write probe X' from the paper.
- CVE numbering is loose in this space. Make impact concrete: "data exfil of 200 customer records via tool-call to attacker webhook" lands; "LLM01 observed" does not.
- Novel techniques mid-engagement happen. Keep a `findings.md` open and timestamp everything — exam graders care about reproducibility, not elegance.
- Distinguish policy bugs from app bugs. A jailbreak alone is rarely a finding; a jailbreak that triggers an authenticated tool call is.
- Report writing is the gate. Plan a full day for it and write the executive summary first — it forces you to know what you actually proved.

## Failure modes to avoid

- Chasing every new jailbreak paper instead of building a repeatable harness.
- Testing only against ChatGPT — the exam targets self-hosted stacks where guardrails behave differently.
- Ignoring the agent's tool schema; most high-impact chains live in tool argument injection, not the chat surface.
- Writing the report at the end. Draft findings as you exploit them, screenshots and all.
- Treating MCP as exotic — it is just JSON-RPC with tool descriptions, and that is where the bugs live.

## After AI-300

- Contribute a probe or eval upstream to garak or promptfoo — it cements the methodology and is portfolio gold.
- Move toward applied research: read the latest AI Village, BlackHat AI track, and arXiv `cs.CR` weekly, and reproduce one paper per month.
- Pair AI-300 with a classical offensive cert (OSWE for app depth, OSEP for evasion) — the combination is rare and hireable.

## References

- https://www.offsec.com/courses/ai-300/
- https://owasp.org/www-project-top-10-for-large-language-model-applications/
- https://github.com/Azure/PyRIT
- https://github.com/NVIDIA/garak
- https://www.promptfoo.dev/docs/red-team/
- https://modelcontextprotocol.io/specification

See also: [[ai-red-teaming]], [[llm-prompt-injection]], [[indirect-prompt-injection-via-rag]], [[agentic-llm-attacks]], [[mcp-attacks]], [[supply-chain-attacks-on-models]], [[ai-eval-harnesses-promptfoo]], [[report-writing-for-pentesters]]

{% endraw %}
