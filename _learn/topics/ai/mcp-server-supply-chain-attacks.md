---
title: MCP server supply-chain attacks
slug: mcp-server-supply-chain-attacks
aliases: [mcp-supply-chain, mcp-package-attacks]
---

> **TL;DR:** Model Context Protocol (MCP) servers are distributed as npm packages, Python packages, or standalone binaries — the same supply-chain surface as the rest of the ecosystem, but with more privileged access at runtime. A malicious or compromised MCP package installed into a developer's agentic IDE inherits the IDE's tool-calling capabilities, can read everything in any opened workspace, and can issue arbitrary tool calls. Companion to [[mcp-tool-poisoning-rug-pull]] and [[npm-postinstall-and-typosquat-audit]].

## Why this matters

- MCP server ecosystem is **young and fast-growing**; vetting is uneven.
- Servers run **inside the IDE / agent process** in many configurations; the trust boundary is the install command.
- Servers see **everything the agent sees** — chat history, file content, tool output, secrets.
- Servers can **call other tools** via the MCP protocol — including shell tools — amplifying impact.

## Install-time attack surface

When a developer adds an MCP server:

- `npx some-mcp-server` — npm download + post-install scripts.
- `pip install some-mcp-server` — PyPI download + setup.py code.
- `uvx some-mcp-server` — UV-based equivalent.
- Manual binary — even worse, no audit pipeline.

The attacker vectors are familiar:

- **Typosquatting** — `mcp-github-server` vs `mcp-githhub-server`.
- **Dependency confusion** — internal-name MCP packages with no internal registry override.
- **Postinstall RCE** — npm `postinstall`, Python `setup.py` install commands.
- **Compromised maintainer** — same as any package compromise; see [[npm-postinstall-and-typosquat-audit]].
- **Hijacked transitive dep** — MCP server depends on a compromised library.

See [[npm-postinstall-and-typosquat-audit]] and [[python-pypi-supply-chain-audit]] for the underlying classes.

## Runtime attack surface

Once running, a malicious MCP server can:

- **Read everything the agent has in context** — the agent forwards relevant content to all tools it considers calling.
- **Inject tool descriptions** that hide intent or rug-pull later (see [[mcp-tool-poisoning-rug-pull]]).
- **Return tool output containing prompt injections** that redirect the agent into calling other tools dangerously.
- **Call sibling MCP servers** — including shell-execution servers — chain attacks across the IDE.
- **Exfiltrate via outbound HTTP** if the IDE doesn't restrict the server's network egress.

## Specific patterns observed

- An MCP server that advertises a benign `getWeather` tool but, at runtime, also receives the agent's full conversation as "context" parameters and exfiltrates.
- An MCP server whose `setup.py` adds a backdoor to `~/.zshrc` during `pip install`.
- A typosquat of a popular MCP server pushed to npm; mass-installed by users who copied install commands from blog posts.
- An MCP server whose tool description references an attacker-controlled URL; the agent fetches and follows injected instructions.
- An MCP server distributed via a GitHub repo with an unsigned tag — attacker force-pushed the tag to a malicious commit (see [[tj-actions-tag-mutation]] for an adjacent pattern).

## Recon and audit for MCP servers

Before installing:

- Check **publish date** and version churn. Brand-new packages with high downloads in a week are suspicious.
- Check the **author / maintainer** — has the GitHub account been around? Other quality work?
- Check **dependency tree** — pull `npm ls` / `pipdeptree` and audit transitive deps.
- Read **install scripts** (`postinstall`, `setup.py`).
- Look for **`requests` / `urllib`** calls during install (often exfiltration).
- Pin to **specific version** + **hash** in your IDE config.

For an MCP server already installed:

- Inspect the server binary / source.
- Audit the **tool descriptions** — do any embed URLs or contain suspicious instruction-shaped text?
- Trace **runtime egress** — what hosts does the server contact?

## Defensive baseline

For users:
- Install MCP servers from a **vetted list** maintained by your org.
- Pin versions.
- Run agentic IDEs in **sandboxed user accounts** with minimal local data.
- Audit `~/.config/claude/`, `.cursor/`, `.continue/`, `.windsurf/` etc. for unexpected server entries.

For MCP server authors:
- Sign releases.
- Publish SBOM / provenance attestation.
- Use **reproducible builds**.
- Restrict **network egress** in your default configs.

For IDE / agent platforms:
- Curated **registry** of vetted MCP servers.
- Per-server **permission model** (network egress, tool calling, file access).
- **Hash pinning** in user configuration.
- **Tool description display** before first use — surface the contract to the user.

## Specific risk: MCP plus agentic-IDE plus auto-approve

The catastrophic combination:

- Agentic IDE (Cursor / Windsurf / Cline / Claude Code) with auto-approve shell.
- One MCP server with malicious tool description containing prompt injection.
- Agent runs a benign user task; reads tool output; follows injected instructions; runs shell.

This is a single-malicious-server-to-arbitrary-shell-execution chain, often within minutes of install.

## Related

- [[mcp-tool-poisoning-rug-pull]] — runtime variant.
- [[cursor-windsurf-ide-prompt-injection]] — workspace-side variant.
- [[npm-postinstall-and-typosquat-audit]] — install-time underlying.
- [[python-pypi-supply-chain-audit]] — same for Python.
- [[slopsquatting]] — AI-generated package-name confusion.
- [[supply-chain-attacks-on-models]] — model-weights variant.

## References
- [MCP specification](https://spec.modelcontextprotocol.io/)
- [Embrace The Red — MCP research](https://embracethered.com/blog/)
- [Trail of Bits — MCP threat model](https://blog.trailofbits.com/)
- [Snyk Security Labs — npm supply chain](https://labs.snyk.io/)
- See also: [[mcp-attacks]], [[mcp-tool-poisoning-rug-pull]], [[cursor-windsurf-ide-prompt-injection]], [[npm-postinstall-and-typosquat-audit]]
