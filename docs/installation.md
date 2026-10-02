# Installation

Covers getting this repo onto a server, then bringing the stack up. Works on native Ubuntu 24.04 and on Ubuntu inside WSL2.

## 0. Prerequisites

- An NVIDIA GPU with a current driver.
  - **Windows/WSL**: install the normal Windows NVIDIA driver only. Do **not** install a Linux driver inside WSL. Check with `nvidia-smi` inside WSL.
  - **Native Ubuntu**: `sudo ubuntu-drivers install`, reboot, check with `nvidia-smi`.
- `git`, which ships with Ubuntu. Otherwise `sudo apt install git`.
- A Tailscale account with **MagicDNS** and **HTTPS Certificates** enabled ([admin → DNS](https://login.tailscale.com/admin/dns)).
- Disk: about 10 GB for images plus about 20 GB for models.

## 1. Get the repo onto the server

The repo is meant to be cloned **on the machine that runs the stack**, inside Linux (WSL or Ubuntu), not just on Windows.

**Public repo:**
```bash
sudo mkdir -p /opt/zan-tailscale-server && sudo chown "$USER" /opt/zan-tailscale-server
git clone https://github.com/<owner>/zan-tailscale-server.git /opt/zan-tailscale-server
```

**Private repo.** Pick one:
- **GitHub CLI** (simplest): `sudo apt install gh`, then `gh auth login` (choose GitHub.com → HTTPS → "Login with a web browser"), then `gh repo clone <owner>/zan-tailscale-server /opt/zan-tailscale-server`.
- **SSH deploy key** (read-only, scoped to this one repo; good for a headless server):
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/zan_deploy -N ""
  cat ~/.ssh/zan_deploy.pub    # add at GitHub → repo → Settings → Deploy keys (read-only)
  GIT_SSH_COMMAND="ssh -i ~/.ssh/zan_deploy" git clone git@github.com:<owner>/zan-tailscale-server.git /opt/zan-tailscale-server
  ```
Never put a token or key inside the repo.

Updating later: `cd /opt/zan-tailscale-server && git pull`.

## 2. Install Docker + NVIDIA Container Toolkit

```bash
cd /opt/zan-tailscale-server/zan-tailscale-server
sudo ./scripts/install-docker-ubuntu.sh "$USER"
# open a new shell (docker group membership), then:
docker run --rm --gpus all ubuntu:24.04 nvidia-smi   # must list the GPU
```
Note that `docker` group membership is root-equivalent on that machine.

**WSL only:** systemd must be enabled. `/etc/wsl.conf` needs `[boot]` followed by `systemd=true`; after changing it, run `wsl --shutdown` from Windows.

## 3. Configure and start

```bash
./scripts/init-env.sh                     # .env with random WEBUI_SECRET_KEY (never printed)
nano .env                                 # optional: TS_HOSTNAME, context size
docker compose up -d ollama open-webui
./scripts/pull-models.sh                  # or: ./scripts/import-models.sh <existing ollama models dir>
```

## 4. Create the admin account (before going remote)

On **the server itself**, open `http://localhost:3000` and create the first account. It becomes admin, and sign-up is closed from then on. Doing this before Tailscale is connected means nobody else can claim the admin account.

On a headless Ubuntu server, tunnel the port from another machine with `ssh -L 3000:127.0.0.1:3000 user@server`, then open `http://localhost:3000` there.

## 5. Connect Tailscale

```bash
./scripts/tailscale-login.sh      # prints a login URL with no time limit; approve it in your browser
docker exec tailscale tailscale serve status    # should show https://<TS_HOSTNAME>.<tailnet>.ts.net (tailnet only)
```
Then set the addresses in `.env` and run `docker compose up -d`:
```
WEBUI_URL=https://<TS_HOSTNAME>.<tailnet>.ts.net
CORS_ALLOW_ORIGIN=https://<TS_HOSTNAME>.<tailnet>.ts.net;http://localhost:3000
TS_ALLOWED_LOGIN=<your Tailscale login email>
OPENHANDS_PUBLIC_URL=https://<TS_HOSTNAME>.<tailnet>.ts.net:8443
OPENHANDS_SANDBOX_URL_PATTERN=https://<TS_HOSTNAME>.<tailnet>.ts.net:{port}
```
**Native Ubuntu only:** add `127.0.0.1 host.docker.internal` to `/etc/hosts` once (WSL does this through `wsl-boot.sh`). OpenHands sandboxes need it.

## 6. Start at boot

- **Native Ubuntu**: nothing to do. Docker is enabled under systemd, and the containers use `restart: unless-stopped`.
- **Windows + WSL**: register the boot task from an **elevated** PowerShell:
  ```powershell
  powershell -ExecutionPolicy Bypass -File \\wsl.localhost\Ubuntu\opt\local-ai\windows\register-boot-task.ps1
  Start-ScheduledTask -TaskName 'local-ai WSL keepalive'
  ```
  The task runs `wsl.exe -d Ubuntu -u root -- /opt/local-ai/scripts/wsl-boot.sh` at startup using an S4U logon (no stored password). That script starts Docker and then keeps WSL alive. Without it, WSL shuts down when idle and takes the stack with it.
  > The task points at `/opt/local-ai`. On the current desktop, that's the deployed copy of the `zan-tailscale-server/` app folder; see [backup-and-migration.md](backup-and-migration.md).

## 7. Verify

```bash
./scripts/verify.sh
```
Checks: containers running, no Ollama host port, WebUI bound to loopback, GPU visible, unauthenticated API returns 401, sign-up disabled, Tailscale running with Funnel off, and a model answers with code while running 100% on GPU.
