# zan-tailscale-server

A private, self-hosted coding assistant. A local LLM runs on the desktop GPU, the chat UI runs in the browser, and the only way in is your private Tailscale network.

```
Laptop / phone (Tailscale)  ──HTTPS, tailnet only──►  https://ai-desktop.tailXXXXXX.ts.net
                                                          │  Tailscale Serve (container)
                                                          ▼
                                                    Open WebUI (sign-in required)
                                                          │  internal Docker network
                                                          ▼
                                                    Ollama + RTX 4060 Ti  (no exposed port)
```

- **Models**: `qwen2.5-coder:14b` (default), `qwen3.5:9b`, `qwen2.5-coder:7b`. See [docs/models.md](docs/models.md).
- **Runs on**: Docker Engine inside WSL2 Ubuntu on Windows 11 today; native Ubuntu later with no changes.
- **Not exposed**: no router port forwarding, no Tailscale Funnel, no public tunnel. The Ollama API has no host port at all.

## Repo layout

```
zan-tailscale-server/          repo root
├─ README.md                   this file
├─ docs/                       architecture, implementation notes, guides
├─ .claude/                    Claude Code project settings (optional)
└─ zan-tailscale-server/       the app (run everything from here)
   ├─ docker-compose.yml       ollama + open-webui + tailscale
   ├─ example.env              template for .env (secrets generated locally, never committed)
   ├─ models.txt               which models to pull
   ├─ tailscale/serve.json     Tailscale Serve config (tailnet-only HTTPS -> open-webui)
   ├─ scripts/                 Linux-side scripts (install, login, models, verify, backup, boot)
   └─ windows/                 Windows helpers (boot task, ai.ps1 wrapper)
```

## Install on a new machine

Full walkthrough: [docs/installation.md](docs/installation.md). The short version on Ubuntu, or in WSL Ubuntu:

```bash
git clone https://github.com/<owner>/zan-tailscale-server.git /opt/zan-tailscale-server
cd /opt/zan-tailscale-server/zan-tailscale-server
sudo ./scripts/install-docker-ubuntu.sh "$USER"   # Docker Engine + NVIDIA Container Toolkit (log out/in after)
./scripts/init-env.sh                             # creates .env with a random secret
docker compose up -d ollama open-webui
./scripts/pull-models.sh                          # pulls everything in models.txt
# open http://localhost:3000 ON THIS MACHINE and create the admin account
./scripts/tailscale-login.sh                      # approve the device in your browser
./scripts/verify.sh                               # checks health, auth, exposure, GPU, model
```

Restoring from a backup instead? See [docs/backup-and-migration.md](docs/backup-and-migration.md).

## Day-to-day

Run these from `zan-tailscale-server/` in Linux. On Windows, `windows\ai.ps1 <command>` wraps them.

| Task | Command |
|---|---|
| Status | `docker compose ps` and `docker exec ollama ollama ps` |
| Start | `docker compose up -d` |
| Stop | `docker compose stop` |
| Logs | `docker compose logs -f open-webui` (or `ollama`, `tailscale`) |
| Health/security check | `./scripts/verify.sh` |
| Update images | `docker compose pull && docker compose up -d && docker image prune -f` |
| Add a model | add it to `models.txt`, then `./scripts/pull-models.sh` |
| Backup | `./scripts/backup.sh` (add `--models` to include model weights) |

## Docs

- [Architecture & security](docs/architecture.md): what's reachable from where, and why
- [Installation](docs/installation.md): new machine, Windows/WSL specifics, getting the repo onto the server
- [Laptop setup](docs/laptop-setup.md): what to install and which address to bookmark
- [Models](docs/models.md): choices, VRAM fit, context tuning, links
- [Operations](docs/operations.md): start/stop/update, maintenance schedule
- [Backup & migration](docs/backup-and-migration.md): what's in git vs. backups, moving to Ubuntu
- [Troubleshooting](docs/troubleshooting.md)
- [Implementation log](docs/implementation.md): how it was built, decisions, problems hit
- [Future: Cloudflare Tunnel + Access](docs/future-cloudflare-access.md) (not implemented)
- [Future: agent harness (OpenHands, Claude Code, Codex, opencode)](docs/future-agent-harness.md) (not implemented)

## Never commit

`.env`, `backups/`, Tailscale state, Open WebUI data, and model weights. `.gitignore` covers these. Docker volumes live outside the repo anyway.
