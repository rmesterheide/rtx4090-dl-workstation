#!/usr/bin/env bash
set -euo pipefail

# NVIDIA's Ubuntu 24.04 apt repo works fine as a CUDA-only source on 26.04
# too (only the driver .deb path is OS-version sensitive, not the toolkit).
# Swap REPO_TAG below if NVIDIA has published a ubuntu2604 repo by the time
# you run this: https://developer.nvidia.com/cuda-downloads
REPO_TAG="${CUDA_REPO_TAG:-ubuntu2404}"
KEYRING_DEB="cuda-keyring_1.1-1_all.deb"

cd /tmp
wget -q "https://developer.download.nvidia.com/compute/cuda/repos/${REPO_TAG}/x86_64/${KEYRING_DEB}"
sudo dpkg -i "$KEYRING_DEB"
sudo apt update
sudo apt install -y cuda-toolkit-13-0

BASHRC="$HOME/.bashrc"
grep -q '/usr/local/cuda/bin' "$BASHRC" 2>/dev/null || cat >> "$BASHRC" <<'EOF'

# CUDA
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
EOF

echo "CUDA toolkit installed. Open a new shell (or 'source ~/.bashrc') and run:"
echo "  nvcc --version"
