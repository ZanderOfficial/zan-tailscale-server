# Troubleshooting

Start with `./scripts/verify.sh`. It pinpoints most problems.

## GPU not being used (slow replies, `ollama ps` shows CPU)

1. `docker exec ollama ollama ps`: look at the PROCESSOR column. `100% GPU` is good. A split like `40%/60% CPU/GPU` means the model **doesn't fit**; see the out-of-memory section below.
2. `docker exec ollama nvidia-smi`: if this errors, the container can't see the GPU at all.
   - Test Docker itself: `docker run --rm --gpus all ubuntu:24.04 nvidia-smi`.
   - If that fails: `sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker`.
   - WSL: run `nvidia-smi` inside WSL (it lives at `/usr/lib/wsl/lib/nvidia-smi`). If it fails, update the **Windows** NVIDIA driver, then run `wsl --shutdown` from Windows.
3. Check that nothing else is holding VRAM: run `nvidia-smi` on Windows. The old native Ollama install must stay quit (its autostart was removed). Games and other GPU apps reduce what's available.
4. `docker compose logs ollama | grep -i -E "cuda|gpu|vram"` shows what Ollama detected at startup.

## Out-of-memory / model won't load / very slow

- Lower `OLLAMA_CONTEXT_LENGTH` (e.g. `8192`) or set `OLLAMA_KV_CACHE_TYPE=q8_0` in `.env`, then run `docker compose up -d ollama`.
- Use a smaller model (`qwen2.5-coder:7b`).
- Make sure only one model is loaded (`OLLAMA_MAX_LOADED_MODELS=1` is set; check with `ollama ps`, unload with `ollama stop <tag>`).
- WSL RAM: WSL gets about half of Windows RAM (~8 GB) by default. If Open WebUI or a model load gets killed, check `dmesg | grep -i oom` inside WSL. You can raise the limit in `%UserProfile%\.wslconfig` (`[wsl2]` then `memory=10GB`), then `wsl --shutdown`.

## Remote URL doesn't load on the laptop

1. Is Tailscale **connected** on the laptop, with the same account? Is `ai-desktop` online in the [admin console](https://login.tailscale.com/admin/machines)?
2. Is the desktop up? From the desktop: `curl http://localhost:3000/health` should return `{"status":true}`.
3. `docker exec tailscale tailscale status` should show `ai-desktop` plus your other devices. If it says "Logged out" or "NeedsLogin", run `./scripts/tailscale-login.sh`.
4. `docker exec tailscale tailscale serve status` should show `https://ai-desktop....ts.net (tailnet only)`. If it says "No serve config", the usual cause is that **HTTPS certificates aren't enabled** for the tailnet ([admin → DNS](https://login.tailscale.com/admin/dns)). Enable them, then run `docker compose restart tailscale`.
5. The page loads but login or websockets fail: check that `WEBUI_URL` and `CORS_ALLOW_ORIGIN` in `.env` match the exact `https://...ts.net` address, then run `docker compose up -d open-webui`.
6. Certificate warning on first visit: wait a minute. The certificate is issued on the first HTTPS request.
7. Node key expired (after about 180 days): re-run `./scripts/tailscale-login.sh`, or disable key expiry for this machine in the admin console.

## Services don't start / stack is down

- **WSL stopped** (`wsl -l -v` shows Stopped): the boot/keepalive task isn't running.
  ```powershell
  Get-ScheduledTask -TaskName 'local-ai WSL keepalive' | Get-ScheduledTaskInfo
  Start-ScheduledTask -TaskName 'local-ai WSL keepalive'
  ```
  If it fails under S4U, re-register with `register-boot-task.ps1 -UsePassword`.
- **Docker not running** in WSL: `systemctl status docker`, `sudo systemctl start docker`. Check that `/etc/wsl.conf` has `systemd=true`.
- **A container keeps restarting**: `docker compose ps`, then `docker compose logs --tail=100 <service>`.
  - `open-webui`: the first start downloads embedding models and takes 1–2 minutes. `.env` missing `WEBUI_SECRET_KEY` makes compose refuse to start.
  - `tailscale`: "context deadline exceeded" in a loop means it's waiting for a browser login. The built-in startup only waits 60 seconds per URL, so use `./scripts/tailscale-login.sh`.
- **`localhost:3000` doesn't load on the Windows desktop** while the container is healthy: WSL localhost forwarding hiccup. Run `wsl --shutdown`, then `Start-ScheduledTask -TaskName 'local-ai WSL keepalive'`.
