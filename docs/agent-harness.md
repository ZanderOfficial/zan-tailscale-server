# Agent harness: OpenHands (repo-based coding with local models)

**URL (bookmark on the laptop):** https://ai-desktop.tailXXXXXX.ts.net:8443

You pick one of your GitHub repos and a branch. OpenHands starts a **fresh sandbox container** for that conversation, clones the repo, and the local model works in it with a shell, file editor, Python/Jupyter and a browser. You chat, watch the changes, and can have it commit, push a branch or open a PR.

## First-time setup (once)

1. **Create a fine-grained GitHub token:** GitHub → Settings → Developer settings → Personal access tokens → *Fine-grained tokens* → Generate.
   - Repository access: **Only select repositories** (pick the ones you want to code on).
   - Permissions: **Contents: Read and write**, **Pull requests: Read and write**. Metadata (read) is added automatically.
   - Set an expiry date.
2. Open https://ai-desktop.tailXXXXXX.ts.net:8443 → **Settings → Integrations** → paste the token in **GitHub Token** → Save.
   It's stored in the `openhands-state` volume on the desktop. Never put it in this repo or in `.env`.
3. Home screen → **Open Repository** → pick a repo and branch → **Launch**.

## Branches

- **Existing branch:** pick it in the branch dropdown under *Open Repository* before **Launch**.
- **New branch:** ask in chat, e.g. "Create branch `feature/x` from `main`, switch to it, and never push to main." Then "commit and push the branch" or "open a PR into main". This needs token permissions Contents and Pull requests: read/write.
- **Point and click:** use the VS Code tab inside the conversation (sandbox port 8001), Source Control panel.
- One sandbox at a time: **push before launching another repo or branch**, or unpushed work in the old sandbox is lost.

## How it's wired

```
Laptop ──https :8443──► tailscale (Serve) ──► oh-gate (Caddy) ──► openhands app (:3000)
       ──https :8000/8001/8011/8012──► tailscale ──► oh-gate ──► active sandbox (host network)
                                                                     │
                                       sandbox ──http──► 172.17.0.1:11434 (Ollama, GPU)
```

- **The browser talks to the sandbox directly**, which is how OpenHands is built. So the sandbox ports are published too, and sandboxes use host networking to keep those ports fixed. Consequence: **one sandbox at a time**. Starting a new repo session replaces the previous sandbox; conversations are kept.
- **oh-gate** is the authentication layer. OpenHands itself has no login. It only passes requests that (1) come from the `tailscale` container's fixed IP and (2) carry the `Tailscale-User-Login` header for **your** login, which Tailscale Serve sets and clients can't forge. `verify.sh` checks that unauthenticated and forged requests get a 403.
- Ollama is published on the Docker bridge address only, so sandboxes can reach the model. It isn't reachable from the LAN, the tailnet or Windows.

## Model settings (measured 2026-10-02)

Smoke test: "clone octocat/Hello-World, list files, show README, write NOTES.md, run git status".

| Model | Tool calling | Result | Total time | Model calls |
|---|---|---|---|---|
| `qwen2.5-coder:14b` | **prompt-based** (`native_tool_calling: false`) | ✅ done | **59 s** | 6 (first ~22 s, then 3–8 s) |
| `qwen2.5-coder:14b` | native | ❌ wrote the tool call as text and stopped | 20 s | 2 |
| `qwen3.5:9b` | native | ✅ done | 254 s | 8 (first ~3.5 min: model swap and "thinking", then 1–3 s) |

**Default:** `qwen2.5-coder:14b` with prompt-based tool calling, 32K context, `q8_0` KV cache, 100% GPU.

To change it: Settings → LLM (advanced) in the UI, or through the API from the desktop:
```bash
curl -s -X POST http://127.0.0.1:3001/api/v1/settings -H 'Content-Type: application/json' -d '{
  "agent_settings_diff": {"llm": {"model": "openai/qwen3.5:9b", "base_url": "http://172.17.0.1:11434/v1",
                                  "api_key": "ollama", "native_tool_calling": true}}}'
```
`api_key` is a dummy value; Ollama ignores it.

**Context usage:** OpenHands' system prompt and tool definitions take a large share of the 32K window. The **condenser** is on by default (LLM-summarizing). It compacts older history, so long sessions slow down rather than fail. Larger repos and long sessions will expose the 14B model's limits; see "Next iterations".

## Security notes

- OpenHands mounts the Docker socket, which is root-equivalent inside WSL. Acceptable for a single-user box reached only via your tailnet.
- Sandboxes run with host networking inside WSL. They can reach the internet (git clone, package installs), the desktop's loopback services (Open WebUI still requires login), and Ollama. They **can't** be reached from the LAN, because WSL's NAT isolates them.
  - **On a native Ubuntu server with a LAN interface, firewall ports 8000–8012** (e.g. `sudo ufw deny 8000:8012/tcp`; Docker-published ports also need rules in the `DOCKER-USER` chain).
- Treat repo contents and web pages as untrusted. They can contain prompt-injection text aimed at the agent. Keep the GitHub token scoped to selected repos.

## Next iterations (not done yet)

- **Claude Code / Codex / Gemini CLI** as opt-in agents via ACP ([docs](https://docs.openhands.dev/openhands/usage/agent-canvas/acp-agents)). Note that these run inside the Agent Server and send code to their providers.
- **opencode** as a lighter harness with a smaller prompt ([Ollama + OpenCode](https://docs.ollama.com/integrations/opencode)).
- Bigger or stronger local models if the hardware changes. OpenHands' top local recommendation, `qwen3.6:35b-a3b-coding` (23 GB), doesn't fit 16 GB VRAM plus 16 GB RAM.
- Multiple concurrent sandboxes. This needs random sandbox ports, which in turn needs a different remote-access approach than fixed Serve ports.

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Forbidden" on :8443 | Tailscale isn't connected on the laptop, or `TS_ALLOWED_LOGIN` in `.env` doesn't match your Tailscale login. Check `docker logs oh-gate`. |
| Conversation stuck "starting" / no terminal output | The sandbox ports aren't reachable. Check `docker exec tailscale tailscale serve status` lists 8000/8001/8011/8012, and that `OPENHANDS_SANDBOX_URL_PATTERN` matches your ts.net name. |
| Agent replies with JSON/code but does nothing | The model is emitting tool calls as text. Set `native_tool_calling: false` (or switch model). |
| "Port already in use" when starting | An old sandbox is still running: `docker ps --filter name=oh-agent-server`, then `docker rm -f <name>`. |
| Repo list empty | Token missing, expired, or not granted to that repo (Settings → Integrations). |

Sources: [OpenHands](https://github.com/OpenHands/OpenHands) · [local setup](https://docs.openhands.dev/openhands/usage/run-openhands/local-setup) · [local LLMs](https://docs.openhands.dev/openhands/usage/llms/local-llms) · [Docker sandbox](https://docs.openhands.dev/openhands/usage/runtimes/docker) · [integrations](https://docs.openhands.dev/openhands/usage/settings/integrations-settings)
