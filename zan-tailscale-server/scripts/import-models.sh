#!/usr/bin/env bash
# One-time copy of models from an existing (native) Ollama store into the "ollama" Docker volume.
# Usage: ./import-models.sh /mnt/c/Users/<you>/.ollama/models
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="${1:?path to existing Ollama models dir (contains blobs/ and manifests/)}"
[[ -d "$SRC/blobs" && -d "$SRC/manifests" ]] || { echo "$SRC does not look like an Ollama models dir" >&2; exit 1; }

VOL=local-ai_ollama
docker compose stop ollama >/dev/null 2>&1 || true
docker compose create ollama >/dev/null 2>&1   # lets compose create (and label) the volume

docker run --rm -v "$VOL":/dest -v "$SRC":/src:ro alpine \
  sh -c 'mkdir -p /dest/models && cp -a /src/blobs /src/manifests /dest/models/ && du -sh /dest/models'

docker compose up -d ollama
echo "Imported. Models now visible to the container:"
sleep 3
docker exec ollama ollama list
