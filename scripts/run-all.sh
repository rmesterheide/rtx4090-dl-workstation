#!/usr/bin/env bash
# Runs the full setup end-to-end. Meant for a fresh Ubuntu 26.04 install.
# Reboots are required after steps 00 and 03 — this script pauses there
# rather than rebooting for you.
set -euo pipefail
cd "$(dirname "$0")"

./00-system.sh
echo ">>> Reboot now, then re-run this script from step 01 onward."
read -rp "Press Enter once rebooted to continue, or Ctrl+C to stop here: "

./01-dev-tools.sh
./02-git-github.sh
./03-nvidia-driver.sh
echo ">>> Reboot now for the NVIDIA driver to load."
read -rp "Press Enter once rebooted to continue, or Ctrl+C to stop here: "

./04-cuda-toolkit.sh
./05-cudnn.sh
./06-python-envs.sh
./07-frameworks.sh
./08-jupyterlab.sh
./09-docker.sh

echo "Setup complete. See docs/SETUP.md for details and troubleshooting."
