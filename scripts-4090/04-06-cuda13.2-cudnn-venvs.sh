#!/usr/bin/env bash
# 4090rtx-Variante von 04-cuda-toolkit.sh + 05-cudnn.sh + 06-python-envs.sh, so gelaufen am 2026-09-12.
# Abweichung: CUDA 13.2 aus dem ubuntu2404-Repo (ubuntu2604 fuehrt nur 13.3+, Treiber 595 kann max. 13.2).
# Danach: scripts-4090/06b-tfgpu-py313.sh, dann scripts/07-frameworks.sh.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
echo "=== 04 CUDA toolkit 13.2 (repo ubuntu2404) $(date)"
sudo -n dpkg -r cuda-keyring; rm -f /tmp/cuda-keyring_1.1-1_all.deb; cd /tmp && wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo -n dpkg -i cuda-keyring_1.1-1_all.deb
sudo -n apt-get update -qq
apt-cache policy cuda-toolkit-13-2 | head -3
sudo -n apt-get install -y -qq cuda-toolkit-13-2
grep -q "/usr/local/cuda/bin" ~/.bashrc || printf "\n# CUDA\nexport PATH=/usr/local/cuda/bin\${PATH:+:\${PATH}}\nexport LD_LIBRARY_PATH=/usr/local/cuda/lib64\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}\n" >> ~/.bashrc
/usr/local/cuda/bin/nvcc --version | tail -2
echo "=== 05 cuDNN $(date)"
sudo -n apt-get install -y -qq cudnn9-cuda-13
dpkg -l | grep -E "^ii\s+(cudnn9-cuda-13|libcudnn9-cuda-13)\s" | awk "{print \$2, \$3}"
echo "=== 06 venvs $(date)"
cd ~/rtx3090-dl-workstation/scripts && ./06-python-envs.sh
echo "=== DONE $(date)"
