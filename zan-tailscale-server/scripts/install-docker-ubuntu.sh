#!/usr/bin/env bash
# Install Docker Engine + Compose plugin + NVIDIA Container Toolkit on Ubuntu (WSL2 or bare metal).
# Usage: sudo ./install-docker-ubuntu.sh <linux-user-to-add-to-docker-group>
# Note: membership in the "docker" group is equivalent to root on this machine.
set -euo pipefail

TARGET_USER="${1:-${SUDO_USER:-}}"
[[ $EUID -eq 0 ]] || { echo "Run as root (sudo)." >&2; exit 1; }

apt-get update
apt-get install -y ca-certificates curl gnupg

# --- Docker Engine (official repo) ---
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

# --- NVIDIA Container Toolkit (official repo) ---
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  > /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
                   nvidia-container-toolkit

nvidia-ctk runtime configure --runtime=docker
systemctl enable --now docker containerd
systemctl restart docker

if [[ -n "$TARGET_USER" ]]; then
  usermod -aG docker "$TARGET_USER"
  echo "Added $TARGET_USER to the docker group (takes effect in new shells)."
fi

docker --version
docker compose version
nvidia-ctk --version
