# Operations

All commands run in Linux from the app folder (currently `/opt/local-ai` on the desktop). From Windows, use `zan-tailscale-server\windows\ai.ps1 <status|start|stop|restart|logs|verify|update|shell>`.

## Start / stop

```bash
docker compose up -d             # start everything
docker compose stop              # stop (containers kept)
docker compose down              # remove containers (volumes and data kept)
docker compose restart open-webui
```
After a reboot everything starts on its own: the boot task starts WSL, then Docker, then the containers.

## Update

```bash
git pull                                              # repo changes
docker compose pull                                   # new images
docker compose up -d
docker image prune -f
./scripts/verify.sh
```
Back up first (`./scripts/backup.sh`). Open WebUI sometimes runs database migrations on update. For predictable updates, pin image tags in `.env` (for example `OPEN_WEBUI_TAG=v0.11.4`) and bump them deliberately.

## Models

```bash
docker exec ollama ollama list          # installed
docker exec ollama ollama ps            # loaded right now, plus GPU/CPU split
./scripts/pull-models.sh                # install everything in models.txt
docker exec ollama ollama rm <tag>      # remove one
```

## Users

Admin Panel → Users in Open WebUI. Sign-up is disabled, so add accounts there. New accounts are `pending` until approved.

## Maintenance schedule

| When | What |
|---|---|
| Weekly | `./scripts/verify.sh` |
| Monthly | Update images, back up, keep Windows and the NVIDIA driver updated |
| Monthly | Check [Tailscale machines](https://login.tailscale.com/admin/machines). Consider disabling key expiry for `ai-desktop` so it doesn't drop off after 180 days. |
| As needed | Re-check [models.md](models.md) for better models that fit 16 GB |

## Logs

```bash
docker compose logs --tail=200 -f ollama
docker compose logs --tail=200 -f open-webui
docker compose logs --tail=200 -f tailscale
journalctl -t local-ai                  # boot keepalive messages
```
