#!/usr/bin/env bash
# Back up the Docker volumes to ./backups/<timestamp>/ (for safety or migrating to a new host).
# Usage: ./backup.sh            -> open-webui + openhands-state + tailscale-state (chats, users, settings, GitHub token)
#        ./backup.sh --models   -> also the ollama volume (large; models can be re-pulled instead)
set -euo pipefail
cd "$(dirname "$0")/.."

VOLS=(open-webui openhands-state tailscale-state)
[[ "${1:-}" == "--models" ]] && VOLS+=(ollama)

OUT="backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
cp .env "$OUT/env.backup"; chmod 600 "$OUT/env.backup"

docker compose stop
for v in "${VOLS[@]}"; do
  docker run --rm -v "local-ai_${v}":/data:ro -v "$PWD/$OUT":/out alpine tar czf "/out/${v}.tgz" -C /data .
  echo "saved $OUT/${v}.tgz"
done
docker compose up -d
echo "Backup complete: $OUT  (contains secrets: keep it private)"
