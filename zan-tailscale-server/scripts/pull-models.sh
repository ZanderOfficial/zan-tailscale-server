#!/usr/bin/env bash
# Pull every model listed in models.txt into the ollama container (skips ones already present).
# Usage: ./pull-models.sh [models-file]
set -euo pipefail
cd "$(dirname "$0")/.."
LIST="${1:-models.txt}"

have="$(docker exec ollama ollama list | awk 'NR>1 {print $1}')"
grep -vE '^\s*(#|$)' "$LIST" | awk '{print $1}' | while read -r tag; do
  if grep -qx "$tag" <<<"$have"; then
    echo "present: $tag"
  else
    echo "pulling: $tag"
    docker exec ollama ollama pull "$tag"
  fi
done
docker exec ollama ollama list
