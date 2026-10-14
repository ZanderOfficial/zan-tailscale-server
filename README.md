# zan-tailscale-server

A private, self-hosted coding assistant. Local LLMs run on the desktop GPU. From any of your devices you can **chat** (Open WebUI) or **pick a GitHub repo and have an agent code in a fresh sandbox** (OpenHands). The only way in is your private Tailscale network.

```
Laptop / phone (Tailscale) ──HTTPS, tailnet only──► Tailscale Serve (container)
   https://ai-desktop.tailXXXXXX.ts.net        :443  ──► Open WebUI (sign-in required)        ─┐
   https://ai-desktop.tailXXXXXX.ts.net:8443   :8443 ──► oh-gate (your Tailscale identity)     │
                                                          └► OpenHands ──► sandbox per session  │
                                                                           (repo cloned, shell, │
                                                                            editor, browser)    │
                                                                                 ▼              ▼
                                                                    Ollama + RTX 4060 Ti (Docker bridge only)
```

- **Models**: `qwen2.5-coder:14b` (default), `qwen3.5:9b`, `qwen2.5-coder:7b`. See [docs/models.md](docs/models.md).
- **Runs on**: Docker Engine inside WSL2 Ubuntu on Windows 11 today; native Ubuntu later with no changes.
- **Bookmarks**: chat at `https://ai-desktop.tailXXXXXX.ts.net`, repo agent at `https://ai-desktop.tailXXXXXX.ts.net:8443`.
- **Not exposed**: no router port forwarding, no Tailscale Funnel, no public tunnel. The Ollama API is bound to the Docker bridge only.

## Repo layout

```
zan-tailscale-server/          repo root
├─ README.md                   this file
├─ docs/                       architecture, implementation notes, guides
├─ .claude/                    Claude Code project settings (optional)
└─ zan-tailscale-server/       the app (run everything from here)
   ├─ docker-compose.yml       ollama + open-webui + openhands + oh-gate + tailscale
   ├─ example.env              template for .env (secrets generated locally, never committed)
   ├─ models.txt               which models to pull
   ├─ tailscale/serve.json     Tailscale Serve config (tailnet-only HTTPS)
   ├─ caddy/Caddyfile          oh-gate: Tailscale-identity auth in front of OpenHands
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
# set TS_ALLOWED_LOGIN + WEBUI_URL + OPENHANDS_* in .env, then: docker compose up -d
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
- [Laptop setup](docs/laptop-setup.md): what to install and which addresses to bookmark
- [Agent harness (OpenHands)](docs/agent-harness.md): GitHub repo → sandbox → local model; setup, measurements, security
- [Models](docs/models.md): choices, VRAM fit, context tuning, links
- [Operations](docs/operations.md): start/stop/update, maintenance schedule
- [Backup & migration](docs/backup-and-migration.md): what's in git vs. backups, moving to Ubuntu
- [Troubleshooting](docs/troubleshooting.md)
- [Implementation log](docs/implementation.md): how it was built, decisions, problems hit
- [Future: Cloudflare Tunnel + Access](docs/future-cloudflare-access.md) (not implemented)

## Never commit

`.env`, `backups/`, Tailscale state, Open WebUI data, OpenHands data (incl. your GitHub token), and model weights. `.gitignore` covers these. Docker volumes live outside the repo anyway.

## License

Licensed under the [Mozilla Public License 2.0](LICENSE). You can use and adapt this stack freely; if you distribute a modified version of one of these files, that file must stay under MPL-2.0. The third-party software it runs (Ollama, Open WebUI, OpenHands, Caddy, Tailscale, and the models) keeps its own licenses.
