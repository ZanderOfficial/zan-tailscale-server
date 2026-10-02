#!/usr/bin/env bash
# Create .env from example.env with a freshly generated WEBUI_SECRET_KEY. Refuses to overwrite.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  echo ".env already exists; leaving it alone." >&2
  exit 0
fi

umask 077
secret="$(openssl rand -hex 32)"
sed "s/^WEBUI_SECRET_KEY=.*/WEBUI_SECRET_KEY=${secret}/" example.env > .env
chmod 600 .env
echo "Created .env (mode 600) with a new WEBUI_SECRET_KEY."
