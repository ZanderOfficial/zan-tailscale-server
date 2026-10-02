# Models

Hardware: **RTX 4060 Ti 16 GB VRAM**, 16 GB system RAM. A model is only fast when it fits **entirely** in VRAM, including its context (the KV cache).

## Installed

| Model | Use | Download | VRAM @16K ctx | Measured | Links |
|---|---|---|---|---|---|
| `qwen2.5-coder:14b` | **Default coder** | 9.0 GB | ~12.3 GB | 100% GPU, correct code | [Ollama](https://ollama.com/library/qwen2.5-coder) · [Hugging Face](https://huggingface.co/Qwen/Qwen2.5-Coder-14B-Instruct) |
| `qwen3.5:9b` | General / reasoning ("thinking") | 6.6 GB | ~7.8 GB | 100% GPU, slower first token because it reasons first | [Ollama](https://ollama.com/library/qwen3.5) |
| `qwen2.5-coder:7b` | Fast fallback coder | 4.7 GB | ~6 GB | 100% GPU | [Ollama](https://ollama.com/library/qwen2.5-coder) |

The list lives in [`zan-tailscale-server/models.txt`](../zan-tailscale-server/models.txt). Apply it with `./scripts/pull-models.sh`.

OpenHands results per model: see [agent-harness.md](agent-harness.md#model-settings-measured-2026-10-02).

## Considered and not used (Sept 2026)

| Model | Why not |
|---|---|
| `qwen3-coder:30b` (MoE) | About 19 GB at Q4, which doesn't fit in 16 GB and would spill into the limited system RAM. |
| `qwen3-coder-next` | About 80B total parameters, roughly 45 GB+ at 4-bit. Some articles claim it fits 16 GB; it doesn't. |
| `qwen3.6:27b` | About 17 GB at Q4. Partially CPU-offloaded, so slow. Dropped by request. |
| `devstral-small-2:24b` | About 14–15 GB at Q4, leaving almost no room for context. Worth revisiting for the agent harness (it's tuned for agentic coding). |

Sources: [Ollama library](https://ollama.com/search?c=tools&q=coder) · [localaimaster VRAM table](https://localaimaster.com/blog/ollama-model-ram-vram-table) · [insiderllm Qwen guide](https://insiderllm.com/guides/qwen-models-guide/)

## Context size and memory tuning

Set in `.env`, then apply with `docker compose up -d ollama`:

| Setting | Default | Meaning |
|---|---|---|
| `OLLAMA_CONTEXT_LENGTH` | `32768` | Tokens of context per request. Bigger means more VRAM. |
| `OLLAMA_KV_CACHE_TYPE` | `q8_0` | `q8_0` halves KV-cache memory with a small quality cost. |
| `OLLAMA_KEEP_ALIVE` | `30m` | How long a model stays loaded after the last request. |

For `qwen2.5-coder:14b`, the KV cache costs about 0.19 MB per token at f16:

| Context | KV type | Approx. total VRAM | Fits? |
|---|---|---|---|
| 16K | f16 | ~12–13 GB | Yes (chat-only alternative) |
| 32K | q8_0 | ~12 GB (measured) | **Yes (default; OpenHands needs ≥22K)** |
| 32K | f16 | ~15.5 GB+ | Too tight |

**Check the fit after any change:** `docker exec ollama ollama ps` must show `100% GPU`. If it shows a CPU/GPU split, reduce the context or switch the KV cache to `q8_0`.

Per-chat overrides are also possible in Open WebUI (Chat Controls → Advanced Params → Context Length).
