# Backup, restore & migration

## What lives where

| Thing | Where | How it's protected |
|---|---|---|
| Compose file, scripts, docs, model list | **This git repo** | GitHub |
| `.env` (secret key, settings) | App folder on the server | `backup.sh` (`env.backup`) |
| Users, chats, settings | `local-ai_open-webui` volume | `backup.sh` |
| Tailscale device identity | `local-ai_tailscale-state` volume | `backup.sh` |
| Models (~20 GB) | `local-ai_ollama` volume | Re-pull from `models.txt` (or `backup.sh --models`) |

Backups contain secrets. Store them somewhere private (an external drive or encrypted cloud storage), **never in git**.

## Back up

```bash
./scripts/backup.sh            # -> backups/<timestamp>/{env.backup, open-webui.tgz, tailscale-state.tgz}
./scripts/backup.sh --models   # also ollama.tgz (large)
```
The stack is briefly stopped during the backup for consistency.

## Restore / move to a new machine (e.g. the future Ubuntu server)

1. Follow [installation.md](installation.md) steps 0–2 (clone the repo, install Docker).
2. Copy the backup folder over, then:
   ```bash
   cd /opt/zan-tailscale-server/zan-tailscale-server
   ./scripts/restore.sh /path/to/backups/<timestamp>
   ./scripts/pull-models.sh
   ./scripts/verify.sh
   ```
3. **Tailscale:**
   - **Restored state**: the new machine takes over the same name and URL. **Shut down the old one first.** Two machines must never run the same Tailscale identity.
   - **Or start fresh**: `docker volume rm local-ai_tailscale-state`, run `./scripts/tailscale-login.sh`, delete the old machine in the admin console, and update `WEBUI_URL`/`CORS_ALLOW_ORIGIN` if the name changed.
4. On native Ubuntu there's no Windows boot task to set up. Docker plus `restart: unless-stopped` is enough.

Volume names come from the fixed compose project name `local-ai`, so they stay the same no matter which folder you run from.

## Current desktop deployment note

The desktop currently runs from `/opt/local-ai` inside WSL, a copy of `zan-tailscale-server/` made during setup. The Windows boot task and `ai.ps1` point there. To switch it to a git checkout without changing the boot task:

```bash
sudo git clone <repo-url> /opt/zan-tailscale-server && sudo chown -R "$USER" /opt/zan-tailscale-server
cp /opt/local-ai/.env /opt/zan-tailscale-server/zan-tailscale-server/.env
cd /opt/local-ai && docker compose down          # volumes are kept
sudo mv /opt/local-ai /opt/local-ai.old
sudo ln -s /opt/zan-tailscale-server/zan-tailscale-server /opt/local-ai
cd /opt/local-ai && docker compose up -d && ./scripts/verify.sh
```
