#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt full-upgrade -y
sudo apt autoremove -y
sudo apt autoclean -y

echo "System updated. A reboot is recommended before continuing:"
echo "  sudo reboot"
