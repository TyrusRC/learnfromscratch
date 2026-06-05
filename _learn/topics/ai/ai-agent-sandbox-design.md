---
title: AI agent sandbox design
slug: ai-agent-sandbox-design
aliases: [agent-sandbox-design, llm-agent-isolation]
---

> **TL;DR:** AI agents that can run shell, edit files, browse the web, or call cloud APIs need a sandbox model that limits blast radius. Three layered axes: capability sandboxing (which tools can do what), execution sandboxing (where the agent's effects land — VM, container, ephemeral process), and verification sandboxing (which actions require human confirmation). Most current agent products lean on one axis at a time; mature deployments combine all three. Companion to [[agentic-credential-exfiltration-via-tool-use]] and [[multi-agent-collusion-attacks]].

## Why this matters

- Agents with tool-use can do real damage (delete files, exfil credentials, push code).
- Default platform sandboxes are minimal; vendors add controls slowly.
- Single-axis sandboxing can be bypassed; multi-axis layered model is needed.
- Mature production deployments require explicit security design.

## Axis 1 — Capability sandboxing

Which tools are available, and what they can do.

### Static tool allowlist

- Per-task or per-environment configuration.
- Tools not in the allowlist not callable.

### Per-tool parameter constraints

- File-write tool only allows writes under specific directories.
- Network-fetch tool only allows specific domains.
- Shell-exec tool only allows specific commands (e.g., `npm`, `git`, no `curl`, no `wget`).

### Tool capabilities composition

Worry: tools that *compose* to broader capability:
- Read-file + write-URL = exfil channel.
- Read-secret + render-image = exfil-via-image.
- Shell + DNS = exfil-via-DNS.

Audit capability *combinations* not individual tools.

## Axis 2 — Execution sandboxing

Where the agent's effects land.

### Bare host (worst)

Agent runs as user; full access to user's files, credentials, network. Cursor / Claude Code default.

### Container

- Docker / Podman with restricted mounts.
- Network egress filter.
- Time-bounded.

Good for code-execution sandbox; doesn't help against agent's own filesystem-access tools.

### VM

- VMware, QEMU, Firecracker.
- Stronger isolation.
- Slower spin-up.

Used by e.g., Replit, some commercial agent products for code execution.

### Ephemeral container (best for many use cases)

- Container created per session.
- Discarded after.
- No persistent state.

E.g., Cloudflare Workers + Anthropic's tool-use sandbox patterns.

### gVisor / Kata Containers / Firecracker

- Hardened containers with VM-equivalent isolation.

## Axis 3 — Verification sandboxing

Which actions require human confirmation.

### All actions ask

- Maximum friction.
- Misuse-resistant.
- User-rejected without thinking after fatigue ([[mfa-fatigue-tradecraft]] adjacent).

### High-impact actions ask

- Defined "high impact": file delete, irreversible write, network egress, credential read, payment, deploy.
- Lower-impact (file read, in-sandbox compute) doesn't ask.

This requires a **classifier** for action impact. Crude classifiers (by tool name) work; smart classifiers (by tool arguments) work better.

### Diff-based confirmation

For file edits: show diff before write.
For commands: show parsed structure.
For URL fetches: show destination.

### Out-of-band confirmation

- For very-high-impact actions, require second factor (SMS, hardware token).
- Rare in current products; appropriate for high-stakes (payments, prod deploys).

## Combining the axes

Mature design:

| Tool | Capability sandboxed | Execution sandboxed | Verification required |
|------|---------------------|----------------------|----------------------|
| `read_file` | only under workspace | container | none |
| `write_file` | only under workspace | container | diff confirmation |
| `run_shell` | allowlist commands | container | review first run per session |
| `fetch_url` | domain allowlist | container | none |
| `git_commit` | within repo | container | diff + message |
| `git_push` | branches except main | container | OOB confirmation |
| `delete` | within workspace | container | OOB confirmation |
| `cloud_api` | specific service + region | container with limited creds | per-call confirmation |

Each row is a small policy; together they define the agent's behavior space.

## Specific attack surfaces

### Tool-output prompt injection

Agent reads tool output and follows injected instructions ([[indirect-prompt-injection]]). Defence:
- Mark tool output as untrusted in the agent's prompt.
- Strict output schema; reject malformed.
- Verification step before tool calls derived from tool output.

### Multi-agent collusion

See [[multi-agent-collusion-attacks]].

### Long-running agent state-corruption

Persistent agent state (memory, RAG) accumulates over time. Adversarial inputs poison ([[memory-poisoning]]). Defence:
- Time-bounded memory.
- Periodic reset.
- Provenance tracking on memory entries.

### Credentials in agent context

Even if tools are constrained, secrets in the prompt or in tool output leak. Defence:
- Don't put production credentials in agent context.
- Use scoped tokens at agent layer; tokens never visible to the model.

## Practical patterns

### Pattern: dual-LLM

One LLM with sensitive context generates outputs; second LLM acts on those outputs with constrained tools. First LLM never has tool access; second LLM never has secrets.

Simon Willison's "dual-LLM" pattern.

### Pattern: tool router

A small program inspects tool calls. Allows benign, rejects suspicious, asks user for ambiguous. The model never calls tools directly.

### Pattern: capability tokens

Tools return capability tokens, not direct results. Token represents "permission to do X." Subsequent tools require token. Audit token chain for abuse.

### Pattern: time-window budget

Agent has a budget (cost, calls, tokens) per session. Exhaustion = stop. Prevents runaway loops.

## Workflow to study

1. Read Anthropic's Claude Code system prompt and tool-config patterns.
2. Read Simon Willison's blog on prompt injection + dual-LLM.
3. Read OpenAI's agent SDK + sandbox model.
4. Implement a small agent with single-axis sandbox; demonstrate bypass.
5. Add second axis; observe defence improvement.

## Real-world deployments / patterns

- **Anthropic Claude Code**: capability + execution sandbox via permission system, no verification for read, confirmation for write/run.
- **Cursor**: configurable per-workspace allowlists.
- **GitHub Copilot Chat**: limited tool surface; sandbox-by-design at platform level.
- **Replit Agent**: VM-isolated execution.
- **OpenAI Operator**: browser-sandbox-isolated execution with user confirmation for critical actions.

Each makes trade-offs between safety and usability.

## Related

- [[indirect-prompt-injection]]
- [[agentic-credential-exfiltration-via-tool-use]]
- [[multi-agent-collusion-attacks]]
- [[mcp-tool-poisoning-rug-pull]]
- [[mcp-server-supply-chain-attacks]]
- [[cursor-windsurf-ide-prompt-injection]]
- [[memory-poisoning]]
- [[ai-agent-confusion-attacks]]

## References
- [Simon Willison — dual-LLM pattern](https://simonwillison.net/2023/Apr/25/dual-llm-pattern/)
- [Anthropic — Claude Code permission system](https://docs.anthropic.com/)
- [OpenAI — Agents SDK](https://platform.openai.com/docs/guides/agents)
- [Bruce Schneier + Arvind Narayanan — agentic AI risks](https://www.schneier.com/)
- See also: [[indirect-prompt-injection]], [[multi-agent-collusion-attacks]], [[mcp-server-supply-chain-attacks]], [[agentic-credential-exfiltration-via-tool-use]]
