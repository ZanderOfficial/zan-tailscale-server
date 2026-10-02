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

## Problems hit and fixes

| Problem | Cause | Fix |
|---|---|---|
| Couldn't stop native Ollama from scripts | It was running elevated | Quit manually from the tray. Autostart removed. |
| Compose warned that the volume "was not created by Docker Compose" | `import-models.sh` created the volume with `docker volume create` | Script now runs `docker compose create ollama` first. Volume recreated. |
| `localhost:3000` stopped working overnight | WSL shuts down when idle; nothing held it open | Boot/keepalive scheduled task (`wsl-boot.sh` ends in `sleep infinity`). |
| Tailscale login link "didn't work" | The container's startup gives `tailscale up` a 60-second deadline, then restarts with a **new** URL | `scripts/tailscale-login.sh` runs a one-off login with no timeout on the same state volume. |
| Serve showed "No serve config" after login | HTTPS certificates weren't enabled in the tailnet | Enabled in admin → DNS, restarted the container. |
| PowerShell → `wsl bash -c` quoting broke repeatedly | Nested quoting and `$` expansion | Run Linux steps as script files instead. |

## Verification status

| Requirement | Status |
|---|---|
| GPU inference, 100% on GPU | ✅ tested (14b and 9b) |
| Local access on desktop | ✅ tested |
| Auth enforced / sign-up disabled | ✅ tested (401, `enable_signup=False`) |
| Ollama API not exposed; WebUI loopback only; LAN blocked | ✅ tested |
| Tailscale Serve tailnet-only, Funnel off | ✅ tested (`serve status`) |
| Boot task registered and running | ✅ tested (`Running`) |
| **Laptop access via `https://ai-desktop.tailXXXXXX.ts.net`** | ⏳ to be confirmed from the laptop |
| **Full reboot with no sign-in** | ⏳ not yet tested. Reboot, wait about 2 minutes **without signing in**, then open the URL from the laptop. |
