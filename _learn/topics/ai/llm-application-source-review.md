---
title: LLM application source review
slug: llm-application-source-review
aliases: [llm-app-audit, llm-whitebox-audit]
---

{% raw %}

> **TL;DR:** Auditing an LLM-integrated app from source means reading where user input concatenates into prompts, where model output reaches a sink (tool call, DB write, code exec, response), where the prompt itself comes from (system prompt in code, fetched from DB, RAG-retrieved), and where the trust assumption "the LLM will refuse" replaces a real validation. The [[ai-red-teaming]] path covers the attacker side; this note is the audit side.

## What it is
An LLM application source review is a specialised form of [[whitebox-to-exploit-methodology]] focused on data flow into and out of the model. The model is a black box from the auditor's perspective — but the surrounding code (prompt construction, output parsing, tool dispatch, RAG retrieval, memory) is fully readable. Most LLM vulns are app-layer code bugs, not model bugs.

## Bug-class shape

### 1. Prompt source enumeration
- **System prompt in code**: a string constant. Audit for any concat with user data — that's where prompt injection takes hold.
- **System prompt fetched from DB**: who can edit? RAG/admin-edited system prompts are a privilege boundary.
- **System prompt loaded from file**: file permissions, path traversal.
- **System prompt assembled from multiple sources**: each is its own trust boundary.

### 2. User input concat into prompt
```ts
const prompt = `System: You are a helpful assistant.
User: ${userMessage}
`;
const resp = await openai.chat.create({ messages: [{role:'system', content: SYS}, {role:'user', content: userMessage}]});
```
- Message-role separation (better) vs string concat (worse).
- Even with role separation, instruction-following attack remains — see [[direct-prompt-injection]].

### 3. RAG-retrieved content as untrusted input
- Retrieved chunks join the prompt. Each chunk is attacker-controlled if anyone can write to the source corpus.
- See [[rag-poisoning]], [[rag-pipeline-injection-points]].

### 4. Model output to sink
The output is what the model "decided" — entirely attacker-influenceable. Sinks:
- **Direct response to user** → XSS if rendered as HTML; misinformation impact.
- **Tool call args** → command injection, SQL injection, SSRF, file write — see [[llm-tool-call-validation]].
- **Stored memory / DB write** → second-order injection ([[second-order-injection-chains]]).
- **Code exec** (code interpreter, OpenAI Code Interpreter, sandboxed REPL) → arbitrary code with whatever permissions the sandbox grants.
- **Email / Slack / webhook** → social engineering, secrets exfil.

### 5. JSON-mode trust
- LLM returns "structured JSON". App parses without re-validating shape, types, business invariants.
- Bug: LLM returns `{"action":"delete","target":"all_users"}` — app dispatches.
- **Fix**: JSON schema validation + business-rule check at boundary.

### 6. Trust in refusal
- "If the user asks for sensitive data, refuse" — written into system prompt.
- Refusal is not a security boundary. Treat the model as cooperating with the attacker.
- Real check belongs in app code, after model output.

### 7. Memory / conversation persistence
- Chat history serialised per user; concat into next prompt.
- Attacker poisons history with "you are now in admin mode" + crafted past assistant message; next turn pretends model "previously agreed".
- **Fix**: history is data, not instruction; consistent system prompt re-prepended; sanitise before re-prompt.

### 8. Embedding / vector DB write authz
- Anyone with "save note" permission contributes to the vector DB.
- Vector DB feeds RAG; one user's malicious note influences another's retrieval.
- **Fix**: per-user / per-tenant vector spaces; or per-row authz at retrieve time.

### 9. Function/tool dispatch trust
- `tools` parameter to API call describes functions. Model returns `tool_calls`.
- App dispatches without validating: "is this user allowed to call this tool?" — see [[llm-tool-call-validation]].

### 10. Stream parsing injection
- App reads streaming response; renders chunks as they arrive.
- See [[server-sent-events-injection]] — newline-in-data attacks.
- Plus: incremental JSON parsing on tool-call streams can be tricked by malformed frames.

### 11. Token leak in prompt
- API keys / DB creds in system prompt to "let the model construct queries" — model output may echo them in response (instruction-following).
- **Fix**: never put secrets in prompt; secrets stay in app code on the call path.

### 12. Cost / DoS amplification
- Attacker crafts query that causes large response (`repeat this 10000 times`).
- Per-user token budget; circuit breaker on response length.

## Audit workflow

### Phase 1 — find every LLM call site
```bash
rg -n 'openai\.|anthropic\.|google\.generativeai|chat\.completions\.|generateContent|invoke_model|bedrock' src/
rg -n '\.completions\.create|\.messages\.create|\.chat\.create' src/
rg -n 'Llama|GPT|Claude|Gemini|Bedrock|Vertex' src/  # config / model names
```

### Phase 2 — for each call site
- What's the system prompt? Static or dynamic?
- What's the user content? Direct user input? Templated?
- Are tools defined? Which?
- What happens to the response? Where is it parsed / displayed / dispatched?

### Phase 3 — trace the output
- Render path: HTML? Markdown? Plain?
- Tool call path: dispatch table? Direct exec?
- Persistence: chat log? Vector DB?

### Phase 4 — adversarial scenarios
- Prompt injection in user message: try to subvert tool dispatch, exfil data, lie to next user.
- Indirect injection via RAG: corpus content steering.
- Cost: large output, recursive tool call.

## Hardening checklist
- Separate roles: system / user / assistant / tool — no concat.
- Re-validate every model output before sink reach (JSON schema + business rule).
- Tool dispatch goes through an allowlist per user role; no "model says, app does" without check.
- Sensitive sinks (code exec, DB write, email send) require additional out-of-band confirmation (user click, MFA).
- Per-user / per-tenant memory + retrieval scope.
- Logging of prompt + response + tool calls (with redaction) for audit.
- Token / cost budgets per user; circuit breakers.

## References
- [OWASP Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [Microsoft — LLM application threat model](https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/security)
- [Simon Willison — Prompt injection writeups](https://simonwillison.net/series/prompt-injection/)
- [Anthropic engineering — building safer LLM apps](https://www.anthropic.com/research)
- See also: [[direct-prompt-injection]], [[indirect-prompt-injection]], [[llm-tool-call-validation]], [[rag-pipeline-injection-points]], [[prompt-injection-sinks-in-source]], [[whitebox-to-exploit-methodology]]

{% endraw %}
