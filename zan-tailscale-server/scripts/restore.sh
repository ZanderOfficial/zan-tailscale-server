#!/usr/bin/env bash
# Restore volumes from a backup directory created by backup.sh (e.g. on the future Ubuntu server).
# Usage: ./restore.sh backups/20260930-120000
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${1:?backup directory}"

[[ -f .env ]] || { cp "$SRC/env.backup" .env; chmod 600 .env; echo "restored .env"; }
docker compose down
for f in "$SRC"/*.tgz; do
  v="$(basename "$f" .tgz)"
  docker volume create "local-ai_${v}" >/dev/null
  docker run --rm -v "local-ai_${v}":/data -v "$PWD/$SRC":/in:ro alpine \
    sh -c "rm -rf /data/* /data/.[!.]* 2>/dev/null; tar xzf /in/${v}.tgz -C /data"
  echo "restored ${v}"
done
docker compose up -d
