#!/usr/bin/env bash
# 4090rtx variant of 09-docker.sh: Docker from the Ubuntu archive (docker.io)
# instead of get.docker.com | sudo sh -- runs entirely within the scoped sudoers.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
sudo -n apt-get install -y -qq docker.io docker-compose-v2
sudo -n usermod -aG docker "$USER"

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo -n gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo -n tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

sudo -n apt-get update -qq
sudo -n apt-get install -y -qq nvidia-container-toolkit
sudo -n nvidia-ctk runtime configure --runtime=docker
sudo -n systemctl restart docker
sudo -n systemctl enable docker >/dev/null
docker --version; nvidia-ctk --version
echo "Verify (new login shell for the docker group; note: sg is not available on 26.04):"
echo "  docker run --rm --gpus all nvidia/cuda:13.2.0-base-ubuntu24.04 nvidia-smi"
