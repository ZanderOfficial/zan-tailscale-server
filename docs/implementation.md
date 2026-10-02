# Implementation log

How the current system was built (Sept 30 – Oct 1, 2026), the decisions made along the way, and what went wrong.

## Starting environment (desktop `EZ-PC-08`)

| | |
|---|---|
| OS | Windows 11 Pro 26200 |
| GPU | RTX 4060 Ti **16 GB**, driver 591.74 (CUDA 13.1) |
| CPU / RAM | Ryzen 5 5600X / 16 GB |
| WSL | WSL 2.6.1, Ubuntu 24.04 with systemd enabled, GPU visible in WSL |
| Pre-existing | Native Windows Ollama 0.35 with `qwen2.5-coder:7b` and `:14b`. No Docker, no Tailscale. |

## Stages

1. **Inventory.** Checked GPU, VRAM, RAM, disk and installed software. The card turned out to be the 16 GB 4060 Ti.
2. **Model choice.** Surveyed the current Ollama library; `qwen2.5-coder:14b` is the best coder that fits fully in VRAM. See [models.md](models.md).
3. **Runtime decision.** Chose Docker Engine inside WSL Ubuntu over Docker Desktop, because Docker Desktop only starts after a Windows sign-in. It also matches the planned Ubuntu server.
4. **Native Ollama retired.** Quit it from the tray and moved its Startup shortcut away (the program is still installed). Its models were copied into the Docker volume (`scripts/import-models.sh`) instead of being re-downloaded.
5. **Docker + NVIDIA toolkit** installed from the official apt repos (`scripts/install-docker-ubuntu.sh`). Verified `docker run --gpus all … nvidia-smi`.
6. **Stack up.** Started Ollama and Open WebUI. `qwen2.5-coder:14b` loaded **100% GPU**, 16K context, about 13 GB VRAM in use.
7. **Local security checks.** Health 200, unauthenticated API 401, `enable_signup=False`, only `127.0.0.1:3000` listening, LAN IP not reachable.
8. **Admin account** created locally, before Tailscale was connected.
9. **Boot persistence.** Registered the Windows scheduled task (S4U, at startup) that runs `scripts/wsl-boot.sh`. Confirmed it running and serving.
10. **Tailscale.** Container in userspace mode. Login via `scripts/tailscale-login.sh`. Enabled HTTPS certificates in the tailnet. Serve now publishes `https://ai-desktop.tailXXXXXX.ts.net (tailnet only)`.
11. **Open WebUI** given `WEBUI_URL` and `CORS_ALLOW_ORIGIN` for that address.
12. **Models** added: `qwen3.5:9b` (100% GPU, about 7.8 GB). `qwen3.6:27b` was dropped because it doesn't fit.
13. **Repo** created (`zan-tailscale-server`): docs at the root, app in `zan-tailscale-server/`.
14. **Agent harness (OpenHands 1.8)** added: `openhands` plus the `oh-gate` identity proxy, Serve ports 8443 and 8000–8012, Ollama on the Docker bridge, context raised to 32K/q8_0. Smoke-tested clone/edit/git in a sandbox: `qwen2.5-coder:14b` with prompt-based tool calling finished in 59 s. Details in [agent-harness.md](agent-harness.md).

## Problems hit and fixes

| Problem | Cause | Fix |
|---|---|---|
| Couldn't stop native Ollama from scripts | It was running elevated | Quit manually from the tray. Autostart removed. |
| Compose warned that the volume "was not created by Docker Compose" | `import-models.sh` created the volume with `docker volume create` | Script now runs `docker compose create ollama` first. Volume recreated. |
| `localhost:3000` stopped working overnight | WSL shuts down when idle; nothing held it open | Boot/keepalive scheduled task (`wsl-boot.sh` ends in `sleep infinity`). |
| Tailscale login link "didn't work" | The container's startup gives `tailscale up` a 60-second deadline, then restarts with a **new** URL | `scripts/tailscale-login.sh` runs a one-off login with no timeout on the same state volume. |
| Serve showed "No serve config" after login | HTTPS certificates weren't enabled in the tailnet | Enabled in admin → DNS, restarted the container. |
| PowerShell → `wsl bash -c` quoting broke repeatedly | Nested quoting and `$` expansion | Run Linux steps as script files instead. |
| OpenHands browser → sandbox needs direct ports | OpenHands' design (random host ports per sandbox) | Host-network sandboxes (fixed 8000/8001/8011/8012) plus Serve ports through oh-gate. One sandbox at a time. |
| OpenHands has no authentication | OSS build is single-user and unauthenticated | `oh-gate` (Caddy) checks the Tailscale identity header and the source IP. |
| Laptop got "Forbidden" from oh-gate | Serve proxied to the hostname `oh-gate`, which resolved to the gate's *default*-network IP, so requests came from an untrusted source address | Serve now proxies to the gate's fixed `edge` IP (`172.30.0.20`); access logging enabled. Verified: app (8443) and sandbox (8000, incl. websocket) return 200/101 with your identity. |
| "MCP Connection Failure" on every new conversation | OpenHands' **built-in** MCP server URL is derived from `OH_WEB_URL`; set to the ts.net address, sandboxes (not on the tailnet) couldn't resolve it. Webhooks also failed: host-network sandboxes had no `host.docker.internal` and wrong port | `OH_WEB_URL=http://localhost:3001` (internal), browser origin via `OH_PERMITTED_CORS_ORIGINS_0`, `SANDBOX_HOST_PORT=3001`, and `127.0.0.1 host.docker.internal` in WSL `/etc/hosts` (re-applied by `wsl-boot.sh`). Verified: 0 sandbox errors, webhooks delivered. |
| `qwen2.5-coder` "finished" without doing anything | It emits tool calls as JSON text instead of native tool calls | `native_tool_calling: false` (OpenHands parses prompt-based calls). |

## Verification status

| Requirement | Status |
|---|---|
| GPU inference, 100% on GPU | ✅ tested (14b and 9b) |
| Local access on desktop | ✅ tested |
| Auth enforced / sign-up disabled | ✅ tested (401, `enable_signup=False`) |
| Ollama API not exposed; WebUI loopback only; LAN blocked | ✅ tested |
| Tailscale Serve tailnet-only, Funnel off | ✅ tested (`serve status`) |
| Boot task registered and running | ✅ tested (`Running`) |
| Laptop access via `https://ai-desktop.tailXXXXXX.ts.net` (sign-in) | ✅ tested by user from the laptop |
| OpenHands sandbox: clone, edit, git with local model | ✅ tested locally (59 s) |
| OpenHands gate: unauthenticated and forged requests get 403 | ✅ tested (`verify.sh`) |
| OpenHands from the laptop (`:8443`), sandbox connection | ✅ tested (gate log: 200/101 with identity) |
| **GitHub repo selection + push/PR** | ⏳ user to test with a GitHub token |
| **Full reboot with no sign-in** | ⏳ not yet tested. Reboot, wait about 2 minutes **without signing in**, then open the URL from the laptop. |
