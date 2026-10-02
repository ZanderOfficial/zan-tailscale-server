#!/usr/bin/env bash
# Health / security checks. Safe to run any time; creates no accounts and changes nothing.
# Usage: ./verify.sh [model]      (default model: qwen2.5-coder:14b)
set -uo pipefail
cd "$(dirname "$0")/.."
MODEL="${1:-qwen2.5-coder:14b}"
PORT="$(grep -E '^WEBUI_LOCAL_PORT=' .env 2>/dev/null | cut -d= -f2)"; PORT="${PORT:-3000}"
pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass+1)); }
bad() { echo "  FAIL  $*"; fail=$((fail+1)); }

echo "== Containers"
docker compose ps --format 'table {{.Service}}\t{{.State}}\t{{.Health}}\t{{.Ports}}'
for s in ollama open-webui tailscale; do
  [[ "$(docker inspect -f '{{.State.Running}}' "$s" 2>/dev/null)" == "true" ]] && ok "$s running" || bad "$s not running"
done

echo "== Exposure"
if ss -ltnH | awk '{print $4}' | grep -qE ':11434$'; then bad "something listens on host port 11434"; else ok "Ollama API has no host port"; fi
if ss -ltnH | awk '{print $4}' | grep -E ":${PORT}\$" | grep -vqE '^127\.0\.0\.1:'; then
  bad "WebUI port ${PORT} bound to a non-loopback address"
else ok "WebUI host port bound to 127.0.0.1 only"; fi

echo "== GPU"
docker exec ollama nvidia-smi --query-gpu=name,memory.total --format=csv,noheader >/dev/null 2>&1 \
  && ok "GPU visible in ollama container: $(docker exec ollama nvidia-smi --query-gpu=name --format=csv,noheader)" \
  || bad "GPU not visible in ollama container"

echo "== Open WebUI auth"
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/health"); [[ $code == 200 ]] && ok "/health 200" || bad "/health returned $code"
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/api/models"); [[ $code == 401 || $code == 403 ]] && ok "unauthenticated /api/models rejected ($code)" || bad "unauthenticated /api/models returned $code"
signup=$(curl -s "http://127.0.0.1:${PORT}/api/config" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("features",{}).get("enable_signup"))' 2>/dev/null)
[[ "$signup" == "False" ]] && ok "public sign-up disabled" || bad "enable_signup=$signup (disable it in Admin Panel > Settings > General)"

echo "== Tailscale"
if docker exec tailscale tailscale status --json >/tmp/ts.json 2>/dev/null; then
  state=$(python3 -c 'import json; print(json.load(open("/tmp/ts.json"))["BackendState"])')
  dns=$(python3 -c 'import json; print(json.load(open("/tmp/ts.json"))["Self"]["DNSName"].rstrip("."))')
  [[ $state == Running ]] && ok "tailscale logged in: https://${dns}/" || bad "tailscale state: $state (see: docker logs tailscale)"
  docker exec tailscale tailscale serve status 2>/dev/null | sed 's/^/        /'
  docker exec tailscale tailscale funnel status 2>/dev/null | grep -qi 'funnel on' && bad "Funnel is ON" || ok "Funnel off"
else bad "tailscale container not answering"; fi

echo "== Model inference (${MODEL})"
out=$(docker exec ollama ollama run "$MODEL" "Write a one-line Python function that returns the square of x. Code only." 2>&1)
[[ "$out" == *def* ]] && ok "model answered: $(echo "$out" | grep -m1 def)" || bad "no code in answer: ${out:0:200}"
docker exec ollama ollama ps | sed 's/^/        /'
docker exec ollama ollama ps | grep -q '100% GPU' && ok "model fully on GPU" || bad "model not 100% on GPU (see README troubleshooting)"

echo; echo "Result: $pass passed, $fail failed"; [[ $fail -eq 0 ]]
