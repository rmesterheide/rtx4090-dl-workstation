#!/usr/bin/env bash
set -euo pipefail

curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update
sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

echo
echo "Log out and back in for the 'docker' group membership to take effect."
echo "Then verify with:"
echo "  docker run --rm --gpus all nvidia/cuda:13.0.0-base-ubuntu24.04 nvidia-smi"
