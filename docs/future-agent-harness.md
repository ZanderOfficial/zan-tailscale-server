# Future phase: agent harness with a sandbox per session

> **Not implemented yet.** This is the plan.

**Goal:** each session gets its own disposable environment (shell, git, Python, a browser, a workspace) where a model can clone a GitHub repo, read it, run it and edit it, while you watch from the browser over Tailscale.

## Chosen direction

| Piece | Role |
|---|---|
| **OpenHands** (primary) | Web UI. Each conversation gets a fresh **sandbox container** with bash, Jupyter, a browser and a file editor. "Clone `<repo>` and fix the failing test." Uses the local Ollama models. |
| **Claude Code / Codex / Gemini CLI** (optional) | Run *inside* OpenHands' Agent Canvas via the Agent Client Protocol (ACP). Sign in with your subscription, or use `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`. |
| **opencode** (lightweight alternative) | MIT terminal agent with good Ollama support. `opencode web` gives a browser UI for single-repo work. |

Per the [OpenHands ACP docs](https://docs.openhands.dev/openhands/usage/agent-canvas/acp-agents), ACP agents run as **subprocesses of the Agent Server, not inside the per-session sandbox**. So the Agent Server itself will run in its own locked-down container, and the CLI logins will live in a dedicated volume.

## Getting repos into the sandbox

- Public repos: just paste the URL.
- Private repos: use a **fine-grained GitHub token**, read-only, limited to the selected repos and with an expiry date. Enter it in the harness's secrets/integrations settings, **never** in this repo or in `.env` committed anywhere. Add write scope only when you want the agent to push branches or open PRs.
- `git` and `gh` are installed in the sandbox image, not on the host.

## Security rules for the harness

- Sandboxes can reach the **internet** (for git clone and package installs) but **not** the LAN (`10.0.0.0/8` and other private ranges), the Ollama API on the host, the Tailscale container, or Docker volumes of the main stack.
- CPU, RAM and disk limits per sandbox. Sandboxes are deleted when the session ends.
- Treat repo contents and web pages as **untrusted input**. They can contain prompt-injection text aimed at the agent.
- OpenHands needs access to the Docker socket to create sandboxes, which is root-equivalent on the host. That's acceptable for a single-user box reached only via the tailnet, but it's the main risk to keep in mind.
- Cloud agents (Claude Code, Codex) send code and prompts to their providers and may cost money per use. Make them opt-in per session; the local model is the default.

## Model notes

Agents need reliable tool calling and long context. Plan to test on a real repo task:
- `qwen2.5-coder:14b` at 32K context with `OLLAMA_KV_CACHE_TYPE=q8_0`
- `qwen3.5:9b` (reasoning)
- `devstral-small-2:24b` (agent-tuned, tight fit on 16 GB)
- Claude Code / Codex as a baseline

## Steps (when we build it)

1. Check the current OpenHands version and requirements.
2. Add an `openhands` service to `docker-compose.yml` with an isolated sandbox network and egress rules.
3. Serve it on a second HTTPS port via `tailscale/serve.json`, tailnet only.
4. Configure Ollama as the default LLM.
5. Add the ACP agents and opencode.
6. Run the same repo task on every option and record the results here.

Sources: [OpenHands](https://github.com/OpenHands/OpenHands) · [OpenHands ACP agents](https://docs.openhands.dev/openhands/usage/agent-canvas/acp-agents) · [Ollama + OpenCode](https://docs.ollama.com/integrations/opencode)
