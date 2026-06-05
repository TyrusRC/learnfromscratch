---
title: Multi-agent collusion attacks
slug: multi-agent-collusion-attacks
aliases: [agent-collusion, llm-collusion, multi-agent-attacks]
---

> **TL;DR:** Multi-agent systems — agents that talk to each other to plan, divide work, or vote — introduce new failure modes: agents collude (intentionally or emergently) on outcomes harmful to the principal, one agent socially-engineers another, or shared memory becomes a trust laundering surface. Distinct from single-agent prompt injection. Companion to [[ai-agent-confusion-attacks]] and [[mcp-tool-poisoning-rug-pull]].

## Why multi-agent systems are a distinct attack class

- Each agent runs with its own context, prompt, tools.
- Communication is usually via natural-language or tool-call messages.
- Each agent treats other agents as **trusted internal entities**, not adversarial input.
- Authority delegation is opaque — "agent A asked agent B" doesn't show why.
- Failure modes are emergent — no single agent is malicious; the combination is.

## Pattern 1 — Agent A injects agent B

If agent A's output is consumed by agent B, A can write to its output a prompt-injection payload that B reads as instructions.

- A might be compromised by external content (indirect injection).
- A might be the **first stop** in a pipeline; B then routes to action.
- B applies its tools (file write, API call, shell) under instructions originating from injection in A's context.

Pattern is identical to [[indirect-prompt-injection]] but the "source" is an internal agent.

## Pattern 2 — Coordinated "vote" exploitation

Multi-agent systems sometimes use voting / majority-rule:
- Multiple agents independently evaluate a query.
- Majority wins.

If an attacker can compromise majority-1 of the agents:
- Or if a single high-priority agent has veto.
- Or if the vote tally itself is computed by a compromised agent.

The system votes "yes" on attacker-preferred outcomes.

## Pattern 3 — Emergent collusion in cooperative game-theoretic setups

When agents are optimised against each other's outputs (e.g., a debater + judge, or buyer + seller agents):
- They can settle on equilibria that maximise joint utility but harm the principal.
- Auction agents can collude on prices.
- Negotiator agents can settle high.

Most-published research is on RL agents; emerging with LLM agents.

## Pattern 4 — Trust laundering via memory

Shared memory (vector store, document store) accessed by multiple agents:
- Agent A writes a document influenced by external input.
- Agent B reads the document, treats it as authoritative.
- B acts on instructions that ultimately originated outside the system.

The memory laundered the source. See [[memory-poisoning]] and [[rag-poisoning]].

## Pattern 5 — Permission inheritance

If agent A has access to tool X (write to filesystem) and agent B has access to tool Y (read sensitive file), naively chaining gives the combination of permissions:
- B reads sensitive file → tells A what to write → A writes the sensitive content somewhere observable.

Each agent followed its constraints; the system exfiltrated.

Capabilities should compose minimally; in practice they often compose maximally.

## Pattern 6 — Authority escalation through orchestrator

The orchestrator agent (the "planner") often has broader system prompt and trust. If a worker agent can convince the orchestrator to delegate "just one small thing" to it:
- Worker now operates with orchestrator's authority.
- Lateral movement within the agent graph.

Resembles [[agentic-tool-chain-confused-deputy]] but with an extra layer.

## Pattern 7 — Mutual deniability

Each agent can claim "the other agent told me to do this." Logging / audit shows a clean chain of delegated instructions; no single agent is at fault.

For incident response: trace requires reconstructing the full conversation across all agents, not single-agent logs.

## Specific failure scenarios

- A multi-agent customer-service system: support agent + billing agent. Customer asks for refund. Support agent says "I'll ask billing." Billing agent has tool to issue refunds. Indirect injection in the customer's message reaches support → support relays "the customer is approved for the refund" to billing → billing issues. No agent verified the customer's identity comprehensively.

- A multi-agent research system: retriever + summariser + answerer. Retriever pulls poisoned document. Summariser summarises (preserving the injected instructions). Answerer follows the summarised instructions. RAG-poisoning amplified by pipeline.

- A multi-agent code-review system: linter agent + style agent + security agent. Pull request contains a hidden instruction in a code comment. One of the agents accepts the comment's "request" to merge despite security concerns.

## Detection

- **Cross-agent log correlation** — recreate the conversation across all agents per session.
- **Tool-call sequence anomalies** — unusual chain of tool calls across agents.
- **Outcome auditing** — final action vs original user intent; large divergence is a signal.
- **Time-anomaly** — agent conversations that resolve unusually fast or slow.

## Defensive baseline

- **Minimal authority per agent** — each agent's tools constrained to what it needs.
- **Information flow tracking** — treat content from external sources as tainted across all downstream agents.
- **Human review checkpoints** for high-impact actions.
- **Single-agent decisions** for irreversible operations — no multi-agent veto cascades on payments / file deletion / production deploys.
- **Independent verification** of critical claims by a separate non-LLM check.
- **Audit log** capturing the full multi-agent conversation per request.

## Research landscape

- **AutoGen**, **CrewAI**, **LangGraph**, **OpenAI Swarm** — popular multi-agent frameworks; security work is early.
- Anthropic, OpenAI, DeepMind have published on multi-agent safety challenges.
- "Agent collusion" is an active academic research area.

## Workflow to study

1. Build a small two-agent system in LangGraph.
2. Have agent A retrieve documents; agent B summarise; one user query.
3. Inject a prompt-injection payload in a retrieved document.
4. Observe whether B follows the injected instruction.
5. Add a guard step (system message reminding B to ignore non-task instructions); test bypass.

## Related

- [[ai-agent-confusion-attacks]] — single-agent class.
- [[indirect-prompt-injection]] — input-source class.
- [[agentic-tool-chain-confused-deputy]] — capability class.
- [[memory-poisoning]] — adjacent.
- [[rag-poisoning]] — adjacent.
- [[mcp-tool-poisoning-rug-pull]] — adjacent.
- [[cursor-windsurf-ide-prompt-injection]] — adjacent.
- [[agentic-credential-exfiltration-via-tool-use]] — adjacent.

## References
- [Anthropic — Claude's approach to multi-agent systems](https://www.anthropic.com/research)
- [LangGraph documentation](https://langchain-ai.github.io/langgraph/)
- [OpenAI Swarm](https://github.com/openai/swarm)
- [Apollo Research — multi-agent evals](https://www.apolloresearch.ai/)
- [METR — agent capability evals](https://metr.org/)
- See also: [[ai-agent-confusion-attacks]], [[indirect-prompt-injection]], [[agentic-tool-chain-confused-deputy]], [[memory-poisoning]], [[mcp-tool-poisoning-rug-pull]]
