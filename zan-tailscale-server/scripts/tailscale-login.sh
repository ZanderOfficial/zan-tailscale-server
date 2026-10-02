#!/usr/bin/env bash
# One-time (or re-) login of the tailscale container's node, with no time limit.
# The container's own startup only waits ~60s for a browser login, then restarts with a new URL.
# This runs a temporary login container on the same state volume, waits for you to approve,
# then starts the normal service, which reuses the saved login.
# Usage: ./tailscale-login.sh
set -euo pipefail
cd "$(dirname "$0")/.."
HOST="$(grep -E '^TS_HOSTNAME=' .env | cut -d= -f2)"; HOST="${HOST:-ai-desktop}"

docker compose stop tailscale >/dev/null 2>&1 || true
docker rm -f ts-login >/dev/null 2>&1 || true

docker compose run -d --rm --no-deps --name ts-login --entrypoint sh tailscale -c "
  tailscaled --statedir=/var/lib/tailscale --tun=userspace-networking --socket=/tmp/ts.sock &
  sleep 3
  tailscale --socket=/tmp/ts.sock up --hostname=$HOST --accept-dns=false --timeout=0
  echo LOGIN_OK
  sleep 2" >/dev/null

echo "Waiting for login URL..."
for _ in $(seq 1 30); do
  url=$(docker logs ts-login 2>&1 | grep -oE 'https://login\.tailscale\.com/a/[A-Za-z0-9]+' | tail -1 || true)
  [[ -n "$url" ]] && break
  docker logs ts-login 2>&1 | grep -q LOGIN_OK && break
  sleep 1
done
[[ -n "${url:-}" ]] && echo -e "\nOpen this link and approve the device (no time limit):\n\n  $url\n"

until docker logs ts-login 2>&1 | grep -q LOGIN_OK; do
  docker inspect ts-login >/dev/null 2>&1 || { echo "login container exited unexpectedly" >&2; exit 1; }
  sleep 3
done
echo "Approved. Starting the normal tailscale service..."
while docker inspect ts-login >/dev/null 2>&1; do sleep 1; done
docker compose up -d tailscale
